import SwiftData
import XCTest
@testable import Dadari

/// 설정 화면이 다루는 값들을 검증한다.
/// PRD 5.4(평균 주기 수동 조정, 알림, HealthKit 토글)와 UX-설계 7번의 설정값 목록이 기준이다.
@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var notifications: NotificationAuthorizerSpy!
    private var model: SettingsViewModel!

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
        model = SettingsViewModel(calendar: TestSupport.calendar, notifications: notifications)
    }

    override func tearDown() {
        model = nil
        notifications = nil
        DadariEnvironment.resetStoreOverride()
        container = nil
        super.tearDown()
    }

    // MARK: - 주기

    func test_평균_주기를_수동으로_조정할_수_있다() async throws {
        await model.reload()

        model.updateCycleLength(31)

        XCTAssertEqual(model.settings.estimatedCycleLength, 31)
        XCTAssertEqual(try store.settings().estimatedCycleLength, 31)
    }

    func test_생리_기간을_조정할_수_있다() async throws {
        await model.reload()

        model.updatePeriodLength(7)

        XCTAssertEqual(try store.settings().estimatedPeriodLength, 7)
    }

    func test_마지막_생리_시작일을_바꿀_수_있다() async throws {
        await model.reload()

        model.updateLastPeriodStartDate(TestSupport.date(2026, 8, 25), now: now)

        XCTAssertEqual(try store.settings().lastPeriodStartDate, TestSupport.day(2026, 8, 25))
    }

    func test_미래_날짜는_마지막_생리_시작일로_저장되지_않는다() async throws {
        await model.reload()

        model.updateLastPeriodStartDate(TestSupport.date(2026, 9, 20), now: now)

        XCTAssertNil(try store.settings().lastPeriodStartDate)
        XCTAssertNotNil(model.message)
    }

    // MARK: - 알림

    func test_알림을_처음_켜면_권한을_요청한다() async throws {
        await model.reload()
        notifications.status = .notDetermined

        await model.setNotificationEnabled(true)

        XCTAssertEqual(notifications.requestCount, 1)
        XCTAssertTrue(try store.settings().notificationEnabled)
    }

    func test_이미_결정된_상태면_권한을_다시_요청하지_않는다() async throws {
        await model.reload()
        notifications.status = .denied

        await model.setNotificationEnabled(true)

        XCTAssertEqual(notifications.requestCount, 0, "거부된 뒤에는 시트가 뜨지 않으므로 헛호출이다")
    }

    func test_알림_시점을_켜고_끌_수_있다() async throws {
        await model.reload()
        XCTAssertTrue(model.isDayBeforeSelected(3))
        XCTAssertTrue(model.isDayBeforeSelected(1))

        model.toggleDayBefore(3)

        XCTAssertFalse(model.isDayBeforeSelected(3))
        XCTAssertEqual(try store.settings().notificationDaysBefore, [1])
    }

    func test_알림_시점은_먼_것부터_정렬된다() async throws {
        await model.reload()
        model.toggleDayBefore(3)   // [1]
        model.toggleDayBefore(3)   // 다시 추가

        XCTAssertEqual(try store.settings().notificationDaysBefore, [3, 1])
    }

    func test_선택_가능한_알림_시점은_PRD가_정한_D3_D1이다() {
        XCTAssertEqual(model.selectableDaysBefore, [3, 1])
    }

    // MARK: - HealthKit

    func test_HealthKit_연동을_끌_수_있다() async throws {
        try store.updateSettings { $0.healthKitSyncEnabled = true }
        await model.reload()

        await model.setHealthKitEnabled(false)

        XCTAssertFalse(try store.settings().healthKitSyncEnabled)
    }
}
