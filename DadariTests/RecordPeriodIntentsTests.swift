import AppIntents
import SwiftData
import XCTest
@testable import Dadari

/// 잠금화면 버튼이 실행하는 인텐트가 실제로 공유 저장소에 기록을 남기는지 검증한다.
/// 잠금화면에서의 탭 자체는 실기기 확인 사항이고(SPIKE.md), 여기서는 그 뒤의 로직을 고정한다.
final class RecordPeriodIntentsTests: XCTestCase {
    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try DadariModelContainer.inMemory()
        DadariEnvironment.recordStore = PeriodRecordStore(
            container: container,
            calendar: TestSupport.calendar
        )
    }

    override func tearDown() {
        DadariEnvironment.resetStoreOverride()
        container = nil
        super.tearDown()
    }

    private var store: PeriodRecordStore { DadariEnvironment.recordStore }

    func test_앱을_열지_않고_실행되도록_설정돼_있다() {
        // 이 조건이 깨지면 잠금화면에서 앱이 열려버린다.
        XCTAssertFalse(RecordPeriodStartIntent.openAppWhenRun)
        XCTAssertFalse(RecordPeriodEndIntent.openAppWhenRun)
    }

    func test_잠금_상태에서도_실행되도록_설정돼_있다() {
        // 기본값 .requiresAuthentication이면 잠긴 기기에서 탭이 조용히 무시된다.
        XCTAssertEqual(RecordPeriodStartIntent.authenticationPolicy, .alwaysAllowed)
        XCTAssertEqual(RecordPeriodEndIntent.authenticationPolicy, .alwaysAllowed)
    }

    func test_시작_인텐트는_잠금화면_출처로_기록한다() throws {
        let now = TestSupport.date(2026, 9, 1)
        RecordPeriodIntentRunner.run(.start, on: now, now: now)

        let records = try store.records()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.source, .lockScreen)
        XCTAssertEqual(records.first?.startDate, TestSupport.day(2026, 9, 1))
    }

    func test_종료_인텐트는_진행_중인_기록을_닫는다() throws {
        RecordPeriodIntentRunner.run(
            .start, on: TestSupport.date(2026, 9, 1), now: TestSupport.date(2026, 9, 1)
        )
        RecordPeriodIntentRunner.run(
            .end, on: TestSupport.date(2026, 9, 5), now: TestSupport.date(2026, 9, 5)
        )

        let records = try store.records()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.endDate, TestSupport.day(2026, 9, 5))
    }

    func test_인텐트를_연속으로_실행해도_같은_날_기록은_하나다() throws {
        let now = TestSupport.date(2026, 9, 1)
        for _ in 0..<5 {
            RecordPeriodIntentRunner.run(.start, on: now, now: now)
        }

        XCTAssertEqual(try store.records().count, 1)
    }

    func test_저장에_실패해도_인텐트가_터지지_않는다() throws {
        // 진행 중인 기록이 없는데 종료를 누른 경우. 잠금화면에는 오류를 띄울 자리가 없으므로
        // 예외를 밖으로 던지지 않고 삼켜야 한다.
        let now = TestSupport.date(2026, 9, 1)
        RecordPeriodIntentRunner.run(.end, on: now, now: now)

        XCTAssertTrue(try store.records().isEmpty)
    }

    func test_인텐트_perform이_결과를_돌려준다() async throws {
        _ = try await RecordPeriodStartIntent().perform()

        XCTAssertEqual(try store.records().count, 1)
        XCTAssertEqual(try store.records().first?.source, .lockScreen)
    }
}
