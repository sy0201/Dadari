import SwiftData
import XCTest
@testable import Dadari

/// 저장소의 도메인 규칙을 고정한다. UX-설계 9번의 예외 처리 항목과 대응한다.
/// 잠금화면이 주 입력 경로라 오탭·연타·잘못된 날짜가 실제로 들어오는 것을 전제한다.
final class PeriodRecordStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: PeriodRecordStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try DadariModelContainer.inMemory()
        store = PeriodRecordStore(container: container, calendar: TestSupport.calendar)
    }

    override func tearDown() {
        store = nil
        container = nil
        super.tearDown()
    }

    // MARK: - 시작일 기록

    func test_시작일을_기록하면_자정으로_정규화돼_저장된다() throws {
        let outcome = try store.recordPeriodStart(
            on: TestSupport.date(2026, 9, 1, hour: 23),
            now: TestSupport.date(2026, 9, 1, hour: 23),
            source: .lockScreen
        )

        XCTAssertTrue(outcome.isNewRecord)
        XCTAssertEqual(outcome.snapshot.startDate, TestSupport.day(2026, 9, 1))
        XCTAssertEqual(outcome.snapshot.source, .lockScreen)
        XCTAssertNil(outcome.snapshot.endDate)
        XCTAssertEqual(try store.records().count, 1)
    }

    func test_같은_날_시작일을_연타해도_기록은_하나다() throws {
        let now = TestSupport.date(2026, 9, 1)
        let first = try store.recordPeriodStart(on: now, now: now, source: .lockScreen)

        for _ in 0..<10 {
            let repeated = try store.recordPeriodStart(on: now, now: now, source: .lockScreen)
            XCTAssertFalse(repeated.isNewRecord)
            XCTAssertEqual(repeated.snapshot.id, first.snapshot.id)
        }

        XCTAssertEqual(try store.records().count, 1)
    }

    func test_미래_날짜는_기록할_수_없다() {
        XCTAssertThrowsError(
            try store.recordPeriodStart(
                on: TestSupport.date(2026, 9, 5),
                now: TestSupport.date(2026, 9, 1),
                source: .app
            )
        ) { error in
            XCTAssertEqual(error as? PeriodRecordError, .futureDate)
        }
    }

    // MARK: - 종료일 기록

    func test_종료일은_진행_중인_주기에_붙는다() throws {
        try store.recordPeriodStart(
            on: TestSupport.date(2026, 9, 1),
            now: TestSupport.date(2026, 9, 1),
            source: .lockScreen
        )

        let outcome = try store.recordPeriodEnd(
            on: TestSupport.date(2026, 9, 5),
            now: TestSupport.date(2026, 9, 5),
            source: .lockScreen
        )

        XCTAssertTrue(outcome.isNewRecord)
        XCTAssertEqual(outcome.snapshot.endDate, TestSupport.day(2026, 9, 5))
        XCTAssertEqual(try store.records().count, 1, "종료는 새 기록을 만들지 않는다")
        XCTAssertFalse(try XCTUnwrap(store.records().first).isOngoing)
    }

    func test_진행_중인_주기가_없으면_종료일을_기록할_수_없다() {
        XCTAssertThrowsError(
            try store.recordPeriodEnd(
                on: TestSupport.date(2026, 9, 5),
                now: TestSupport.date(2026, 9, 5),
                source: .lockScreen
            )
        ) { error in
            XCTAssertEqual(error as? PeriodRecordError, .noOngoingRecord)
        }
    }

    func test_시작일보다_이른_종료일은_거부한다() throws {
        try store.recordPeriodStart(
            on: TestSupport.date(2026, 9, 10),
            now: TestSupport.date(2026, 9, 10),
            source: .app
        )

        XCTAssertThrowsError(
            try store.recordPeriodEnd(
                on: TestSupport.date(2026, 9, 5),
                now: TestSupport.date(2026, 9, 10),
                source: .app
            )
        ) { error in
            XCTAssertEqual(error as? PeriodRecordError, .endDateBeforeStartDate)
        }
    }

    func test_종료일을_연타해도_기록이_망가지지_않는다() throws {
        let start = TestSupport.date(2026, 9, 1)
        let end = TestSupport.date(2026, 9, 5)
        try store.recordPeriodStart(on: start, now: start, source: .lockScreen)

        let first = try store.recordPeriodEnd(on: end, now: end, source: .lockScreen)
        XCTAssertTrue(first.isNewRecord)

        for _ in 0..<5 {
            let repeated = try store.recordPeriodEnd(on: end, now: end, source: .lockScreen)
            XCTAssertFalse(repeated.isNewRecord)
            XCTAssertEqual(repeated.snapshot.id, first.snapshot.id)
        }

        XCTAssertEqual(try store.records().count, 1)
    }

    func test_다음_주기의_시작일은_새_기록으로_쌓인다() throws {
        try store.recordPeriodStart(
            on: TestSupport.date(2026, 8, 1), now: TestSupport.date(2026, 8, 1), source: .lockScreen
        )
        try store.recordPeriodEnd(
            on: TestSupport.date(2026, 8, 5), now: TestSupport.date(2026, 8, 5), source: .lockScreen
        )
        try store.recordPeriodStart(
            on: TestSupport.date(2026, 8, 29), now: TestSupport.date(2026, 8, 29), source: .lockScreen
        )

        XCTAssertEqual(try store.records().count, 2)
    }

    // MARK: - 정렬

    func test_기록은_최신_시작일이_앞에_온다() throws {
        for day in [1, 29] {
            let date = TestSupport.date(2026, 8, day)
            try store.recordPeriodStart(on: date, now: date, source: .app)
            try store.recordPeriodEnd(
                on: date, now: date, source: .app
            )
        }

        let latest = try store.records()
        XCTAssertEqual(latest.first?.startDate, TestSupport.day(2026, 8, 29))

        let oldest = try store.recordsOldestFirst()
        XCTAssertEqual(oldest.first?.startDate, TestSupport.day(2026, 8, 1))
    }

    // MARK: - 수정 / 삭제

    func test_기록을_수정할_수_있다() throws {
        let date = TestSupport.date(2026, 9, 1)
        let created = try store.recordPeriodStart(on: date, now: date, source: .lockScreen)

        let updated = try store.update(
            id: created.snapshot.id,
            startDate: TestSupport.date(2026, 9, 2),
            endDate: TestSupport.date(2026, 9, 6),
            flow: .heavy,
            now: TestSupport.date(2026, 9, 10)
        )

        XCTAssertEqual(updated.startDate, TestSupport.day(2026, 9, 2))
        XCTAssertEqual(updated.endDate, TestSupport.day(2026, 9, 6))
        XCTAssertEqual(updated.flow, .heavy)
    }

    func test_수정에서도_종료일이_시작일보다_이르면_거부한다() throws {
        let date = TestSupport.date(2026, 9, 1)
        let created = try store.recordPeriodStart(on: date, now: date, source: .app)

        XCTAssertThrowsError(
            try store.update(
                id: created.snapshot.id,
                startDate: TestSupport.date(2026, 9, 5),
                endDate: TestSupport.date(2026, 9, 1),
                flow: nil,
                now: TestSupport.date(2026, 9, 10)
            )
        ) { error in
            XCTAssertEqual(error as? PeriodRecordError, .endDateBeforeStartDate)
        }
    }

    func test_오탭한_기록을_삭제할_수_있다() throws {
        let date = TestSupport.date(2026, 9, 1)
        let created = try store.recordPeriodStart(on: date, now: date, source: .lockScreen)

        try store.delete(id: created.snapshot.id)

        XCTAssertTrue(try store.records().isEmpty)
    }

    func test_없는_기록을_수정하거나_삭제하면_오류다() {
        XCTAssertThrowsError(try store.delete(id: UUID())) { error in
            XCTAssertEqual(error as? PeriodRecordError, .recordNotFound)
        }
    }

    // MARK: - 설정

    func test_설정은_없으면_기본값으로_생성된다() throws {
        let settings = try store.settings()

        XCTAssertEqual(settings.estimatedCycleLength, CycleDefaults.cycleLength)
        XCTAssertEqual(settings.estimatedPeriodLength, CycleDefaults.periodLength)
        XCTAssertEqual(settings.notificationDaysBefore, CycleDefaults.notificationDaysBefore)
        XCTAssertFalse(settings.healthKitSyncEnabled)
        XCTAssertNil(settings.lastPeriodStartDate)
    }

    func test_설정을_수정해도_항상_한_건만_유지된다() throws {
        _ = try store.settings()

        let updated = try store.updateSettings { settings in
            settings.lastPeriodStartDate = TestSupport.day(2026, 8, 1)
            settings.estimatedCycleLength = 30
            settings.healthKitSyncEnabled = true
        }

        XCTAssertEqual(updated.estimatedCycleLength, 30)
        XCTAssertTrue(updated.healthKitSyncEnabled)

        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<CycleSettings>())
        XCTAssertEqual(all.count, 1)
    }

    // MARK: - 예측과의 연결

    func test_저장된_기록을_예측_서비스에_그대로_넘길_수_있다() throws {
        for date in [TestSupport.date(2026, 7, 1), TestSupport.date(2026, 7, 29)] {
            try store.recordPeriodStart(on: date, now: date, source: .lockScreen)
            try store.recordPeriodEnd(on: date, now: date, source: .lockScreen)
        }

        let service = CyclePredictionService(calendar: TestSupport.calendar)
        let prediction = try XCTUnwrap(service.predict(
            records: try store.recordsOldestFirst(),
            settings: try store.settings(),
            now: TestSupport.date(2026, 8, 1)
        ))

        XCTAssertEqual(prediction.cycleLengthUsed, 28)
        XCTAssertEqual(prediction.nextPeriodStartDate, TestSupport.day(2026, 8, 26))
    }
}
