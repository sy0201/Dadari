import SwiftData
import XCTest
@testable import Dadari

/// 컨디션 기록의 저장 규칙을 고정한다.
/// 생리 기간 밖의 날에도 남길 수 있어야 하는 것이 이 모델을 따로 둔 이유다.
final class DailyConditionStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: DailyConditionStore!

    private let today = TestSupport.date(2026, 9, 7)

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try DadariModelContainer.inMemory()
        store = DailyConditionStore(container: container, calendar: TestSupport.calendar)
    }

    override func tearDown() {
        store = nil
        container = nil
        super.tearDown()
    }

    func test_증상을_저장하고_다시_읽을_수_있다() throws {
        try store.save(symptoms: [.cramps, .fatigue], on: today, now: today)

        let saved = try XCTUnwrap(store.condition(on: today))
        XCTAssertEqual(saved.symptoms, [.cramps, .fatigue])
        XCTAssertEqual(saved.day, TestSupport.day(2026, 9, 7))
    }

    func test_시각이_달라도_같은_날이면_한_건이다() throws {
        try store.save(symptoms: [.cramps], on: TestSupport.date(2026, 9, 7, hour: 1), now: today)
        try store.save(symptoms: [.headache], on: TestSupport.date(2026, 9, 7, hour: 23), now: today)

        let saved = try XCTUnwrap(store.condition(on: today))
        XCTAssertEqual(saved.symptoms, [.headache], "덮어쓴다")
        XCTAssertEqual(try store.recentConditions().count, 1)
    }

    func test_생리_기간_밖의_날에도_남길_수_있다() throws {
        // 이 모델을 PeriodRecord와 따로 둔 이유. 기록이 하나도 없어도 저장돼야 한다.
        try store.save(symptoms: [.moodSwing], on: TestSupport.date(2026, 8, 20), now: today)

        XCTAssertNotNil(try store.condition(on: TestSupport.date(2026, 8, 20)))
    }

    func test_증상을_모두_해제하면_기록이_지워진다() throws {
        try store.save(symptoms: [.cramps], on: today, now: today)

        let result = try store.save(symptoms: [], on: today, now: today)

        XCTAssertNil(result)
        XCTAssertNil(try store.condition(on: today))
        XCTAssertTrue(try store.recentConditions().isEmpty, "빈 행을 남기지 않는다")
    }

    func test_미래_날짜는_기록할_수_없다() {
        XCTAssertThrowsError(
            try store.save(symptoms: [.cramps], on: TestSupport.date(2026, 9, 20), now: today)
        ) { error in
            XCTAssertEqual(error as? PeriodRecordError, .futureDate)
        }
    }

    func test_기록을_지울_수_있다() throws {
        try store.save(symptoms: [.acne], on: today, now: today)

        try store.delete(on: today)

        XCTAssertNil(try store.condition(on: today))
    }

    func test_없는_날을_지워도_오류가_아니다() {
        XCTAssertNoThrow(try store.delete(on: today))
    }

    func test_최근_기록은_최신순으로_정렬된다() throws {
        for day in [1, 5, 3] {
            try store.save(
                symptoms: [.fatigue],
                on: TestSupport.date(2026, 9, day),
                now: today
            )
        }

        let recent = try store.recentConditions()

        XCTAssertEqual(
            recent.map(\.day),
            [TestSupport.day(2026, 9, 5), TestSupport.day(2026, 9, 3), TestSupport.day(2026, 9, 1)]
        )
    }

    func test_증상_순서는_저장_순서와_무관하게_고정된다() throws {
        try store.save(symptoms: [.nausea, .cramps, .fatigue], on: today, now: today)

        let saved = try XCTUnwrap(store.condition(on: today))

        XCTAssertEqual(saved.orderedSymptoms, [.cramps, .fatigue, .nausea], "Symptom.allCases 순서")
    }

    func test_알_수_없는_태그는_버린다() throws {
        // CloudKit으로 신버전이 쓴 태그를 구버전이 읽는 상황.
        let context = ModelContext(container)
        let condition = DailyCondition(day: TestSupport.day(2026, 9, 7))
        condition.symptomRawValues = ["cramps", "미래에_생긴_태그"]
        context.insert(condition)
        try context.save()

        let saved = try XCTUnwrap(store.condition(on: today))

        XCTAssertEqual(saved.symptoms, [.cramps])
    }
}
