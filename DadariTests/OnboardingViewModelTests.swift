import SwiftData
import XCTest
@testable import Dadari

/// 온보딩 흐름과 입력값 저장을 검증한다.
/// UX-설계 5번의 "온보딩 → 권한 프리퍼미션 → 홈" 순서와 PRD 6.1의 수집 항목이 기준이다.
@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var notifications: NotificationAuthorizerSpy!
    private var model: OnboardingViewModel!

    private var store: PeriodRecordStore { DadariEnvironment.recordStore }
    private let now = TestSupport.date(2026, 9, 7)

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try DadariModelContainer.inMemory()
        DadariEnvironment.recordStore = PeriodRecordStore(
            container: container,
            calendar: TestSupport.calendar
        )
        notifications = NotificationAuthorizerSpy()
        model = OnboardingViewModel(calendar: TestSupport.calendar, notifications: notifications)
    }

    override func tearDown() {
        model = nil
        notifications = nil
        DadariEnvironment.resetStoreOverride()
        container = nil
        super.tearDown()
    }

    // MARK: - 단계

    func test_단계는_소개부터_시작한다() {
        XCTAssertEqual(model.step, .intro)
        XCTAssertFalse(model.isLastStep)
    }

    func test_단계는_문서에_적힌_순서로_넘어간다() {
        // 온보딩 → 권한 프리퍼미션(알림, HealthKit) → 홈
        XCTAssertEqual(model.step, .intro)
        model.advance()
        XCTAssertEqual(model.step, .cycleInput)
        model.advance()
        XCTAssertEqual(model.step, .notificationPermission)
        model.advance()
        XCTAssertEqual(model.step, .healthKitPermission)
        XCTAssertTrue(model.isLastStep)
    }

    func test_마지막_단계에서는_더_넘어가지_않는다() {
        for _ in 0..<10 { model.advance() }

        XCTAssertEqual(model.step, .healthKitPermission)
    }

    // MARK: - 입력값

    func test_기본값은_PRD_6_1의_값이다() {
        XCTAssertEqual(model.cycleLength, CycleDefaults.cycleLength)
        XCTAssertEqual(model.periodLength, CycleDefaults.periodLength)
        XCTAssertEqual(model.cycleLength, 28)
        XCTAssertEqual(model.periodLength, 5)
    }

    func test_주기_길이_범위는_예측이_이상치로_거르는_구간과_같다() {
        // PRD 6.2가 21일 미만, 45일 초과를 이상치로 본다.
        XCTAssertEqual(model.cycleLengthRange, 21...45)
    }

    func test_완료하면_입력값이_저장된다() throws {
        model.lastPeriodStartDate = TestSupport.date(2026, 8, 20)
        model.cycleLength = 30
        model.periodLength = 6

        XCTAssertTrue(model.complete(now: now))

        let settings = try store.settings()
        XCTAssertEqual(settings.lastPeriodStartDate, TestSupport.day(2026, 8, 20))
        XCTAssertEqual(settings.estimatedCycleLength, 30)
        XCTAssertEqual(settings.estimatedPeriodLength, 6)
    }

    func test_완료하면_온보딩을_마친_것으로_표시된다() throws {
        XCTAssertFalse(try store.settings().hasCompletedOnboarding)

        model.complete(now: now)

        XCTAssertTrue(try store.settings().hasCompletedOnboarding)
    }

    func test_저장한_입력값으로_바로_예측이_된다() throws {
        // 기록이 없어도 온보딩 값만으로 첫 예측이 나와야 한다(PRD 6.1의 목적).
        model.lastPeriodStartDate = TestSupport.date(2026, 8, 20)
        model.cycleLength = 30
        model.complete(now: now)

        let service = CyclePredictionService(calendar: TestSupport.calendar)
        let prediction = try XCTUnwrap(service.predict(
            records: [],
            settings: try store.settings(),
            now: now
        ))

        XCTAssertEqual(prediction.nextPeriodStartDate, TestSupport.day(2026, 9, 19))
        XCTAssertEqual(prediction.basis, .estimate)
    }

    func test_미래_날짜는_마지막_생리_시작일로_받지_않는다() {
        model.lastPeriodStartDate = TestSupport.date(2026, 9, 20)

        XCTAssertFalse(model.isLastPeriodStartDateValid(now: now))
    }

    // MARK: - 권한

    func test_알림_권한을_허용하면_상태가_바뀐다() async {
        notifications.grantsAuthorization = true

        await model.requestNotificationPermission()

        XCTAssertEqual(notifications.requestCount, 1)
        XCTAssertTrue(model.notificationStatus.isAuthorized)
    }

    func test_알림_권한을_거부해도_온보딩은_막히지_않는다() async {
        notifications.grantsAuthorization = false

        await model.requestNotificationPermission()

        XCTAssertEqual(model.notificationStatus, .denied)
        // 거부는 오류가 아니라 선택이므로 다음 단계로 넘어갈 수 있어야 한다.
        model.advance()
        XCTAssertNotEqual(model.step, .intro)
    }

    func test_알림_권한_요청이_실패해도_터지지_않는다() async {
        struct Boom: Error {}
        notifications.requestError = Boom()

        await model.requestNotificationPermission()

        XCTAssertEqual(notifications.requestCount, 1)
        XCTAssertEqual(model.notificationStatus, .notDetermined)
    }
}
