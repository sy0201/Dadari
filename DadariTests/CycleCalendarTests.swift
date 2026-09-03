import XCTest
@testable import Dadari

/// 목업(ui-mockup.html)의 날짜 분류와 문페이즈 규칙을 고정한다.
/// 목업이 쓴 2026년 8월 예시 데이터를 그대로 재현해 값을 대조한다.
final class CycleCalendarTests: XCTestCase {
    private var sut: CycleCalendar!
    private var settings: CycleSettingsSnapshot!

    /// 목업 기준 데이터: 8/3 시작, 5일간. 28일 주기라 다음 예정일은 8/31.
    private var records: [PeriodRecordSnapshot] {
        [PeriodRecordSnapshot(
            startDate: TestSupport.day(2026, 8, 3),
            endDate: TestSupport.day(2026, 8, 7)
        )]
    }

    override func setUp() {
        super.setUp()
        sut = CycleCalendar(calendar: TestSupport.calendar)
        settings = CycleSettingsSnapshot(estimatedCycleLength: 28, estimatedPeriodLength: 5)
    }

    override func tearDown() {
        sut = nil
        settings = nil
        super.tearDown()
    }

    private func makePrediction() -> CyclePrediction {
        let service = CyclePredictionService(calendar: TestSupport.calendar)
        return service.predict(
            records: records,
            settings: settings,
            now: TestSupport.date(2026, 8, 16)
        )!
    }

    private func kind(_ month: Int, _ day: Int) -> CycleDayKind {
        sut.kind(
            for: TestSupport.day(2026, month, day),
            records: records,
            prediction: makePrediction(),
            settings: settings
        )
    }

    // MARK: - 날짜 분류

    func test_실제_기록된_기간은_생리로_표시된다() {
        XCTAssertEqual(kind(8, 3), .loggedPeriod)
        XCTAssertEqual(kind(8, 7), .loggedPeriod)
        XCTAssertEqual(kind(8, 8), .ordinary, "기록 종료일 다음 날")
    }

    func test_가임기는_배란일_5일_전부터_1일_후까지다() {
        // 다음 예정일 8/31 → 배란 8/17 → 가임기 8/12 ~ 8/18
        XCTAssertEqual(kind(8, 12), .fertile)
        XCTAssertEqual(kind(8, 17), .fertile)
        XCTAssertEqual(kind(8, 18), .fertile)
        XCTAssertEqual(kind(8, 11), .ordinary)
    }

    func test_PMS는_예측_생리_시작_3일_전부터다() {
        // 다음 예정일 8/31 → PMS 8/28 ~ 8/30
        XCTAssertEqual(kind(8, 28), .pms)
        XCTAssertEqual(kind(8, 30), .pms)
        XCTAssertEqual(kind(8, 27), .ordinary)
    }

    func test_예측_생리_기간이_표시된다() {
        XCTAssertEqual(kind(8, 31), .predictedPeriod)
        XCTAssertEqual(kind(9, 4), .predictedPeriod, "8/31부터 5일간")
        XCTAssertEqual(kind(9, 5), .ordinary)
    }

    func test_실제_기록이_예측보다_우선한다() {
        // 예측 생리 기간과 겹치는 날에 실제 기록이 있으면 실제 기록으로 표시한다.
        let overlapping = [PeriodRecordSnapshot(
            startDate: TestSupport.day(2026, 8, 31),
            endDate: TestSupport.day(2026, 9, 2)
        )]
        let result = sut.kind(
            for: TestSupport.day(2026, 8, 31),
            records: records + overlapping,
            prediction: makePrediction(),
            settings: settings
        )

        XCTAssertEqual(result, .loggedPeriod)
    }

    func test_종료일이_없는_기록은_예상_생리_기간만큼_이어진다() {
        let ongoing = [PeriodRecordSnapshot(startDate: TestSupport.day(2026, 8, 3), endDate: nil)]
        let prediction = makePrediction()

        XCTAssertEqual(
            sut.kind(for: TestSupport.day(2026, 8, 7), records: ongoing, prediction: prediction, settings: settings),
            .loggedPeriod,
            "5일 기준이면 8/3~8/7"
        )
        XCTAssertNotEqual(
            sut.kind(for: TestSupport.day(2026, 8, 8), records: ongoing, prediction: prediction, settings: settings),
            .loggedPeriod
        )
    }

    func test_예측이_없으면_기록된_날만_구분한다() {
        XCTAssertEqual(
            sut.kind(for: TestSupport.day(2026, 8, 3), records: records, prediction: nil, settings: settings),
            .loggedPeriod
        )
        XCTAssertEqual(
            sut.kind(for: TestSupport.day(2026, 8, 20), records: records, prediction: nil, settings: settings),
            .ordinary
        )
    }

    // MARK: - 주기 일차

    func test_주기_일차는_기준_시작일부터_1일차로_센다() {
        let prediction = makePrediction()

        XCTAssertEqual(sut.cycleDay(for: TestSupport.day(2026, 8, 3), prediction: prediction), 1)
        XCTAssertEqual(sut.cycleDay(for: TestSupport.day(2026, 8, 16), prediction: prediction), 14)
    }

    func test_기준일보다_앞선_날짜는_이전_주기로_되돌린다() {
        let prediction = makePrediction()

        // 8/2는 기준일(8/3) 하루 전 → 이전 주기의 28일차
        XCTAssertEqual(sut.cycleDay(for: TestSupport.day(2026, 8, 2), prediction: prediction), 28)
    }

    // MARK: - 문페이즈

    func test_생리_시작일은_그믐에_가깝다() {
        let prediction = makePrediction()

        let fullness = sut.moonFullness(for: TestSupport.day(2026, 8, 3), prediction: prediction)

        XCTAssertLessThan(fullness, 0.1, "0에 가까울수록 그믐")
    }

    func test_주기_중앙은_보름이다() {
        let prediction = makePrediction()

        // 28일 주기의 14일차 = 8/16
        let fullness = sut.moonFullness(for: TestSupport.day(2026, 8, 16), prediction: prediction)

        XCTAssertEqual(fullness, 1.0, accuracy: 0.001, "1이면 보름")
    }

    func test_주기_끝은_다시_그믐이_된다() {
        let prediction = makePrediction()

        let fullness = sut.moonFullness(for: TestSupport.day(2026, 8, 30), prediction: prediction)

        XCTAssertLessThan(fullness, 0.1)
    }

    func test_문페이즈는_항상_0과_1_사이다() {
        let prediction = makePrediction()

        for offset in -40...40 {
            let date = TestSupport.calendar.date(
                byAdding: .day, value: offset, to: TestSupport.day(2026, 8, 3)
            )!
            let fullness = sut.moonFullness(for: date, prediction: prediction)
            XCTAssertGreaterThanOrEqual(fullness, 0)
            XCTAssertLessThanOrEqual(fullness, 1)
        }
    }
}
