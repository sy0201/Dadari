import XCTest
@testable import Dadari

/// PRD 6.2의 예측 규칙을 항목별로 고정한다.
/// 이 앱의 예측은 날짜 기록만으로 계산하므로, 규칙이 바뀌면 여기가 먼저 깨져야 한다.
final class CyclePredictionServiceTests: XCTestCase {
    private var service: CyclePredictionService!

    override func setUp() {
        super.setUp()
        service = CyclePredictionService(calendar: TestSupport.calendar)
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - 기준점이 없을 때

    func test_기록도_온보딩_입력도_없으면_예측하지_않는다() {
        let prediction = service.predict(
            records: [],
            settings: CycleSettingsSnapshot(),
            now: TestSupport.date(2026, 9, 3)
        )

        XCTAssertNil(prediction, "빈 상태 화면은 이 nil을 보고 그린다")
    }

    func test_기록이_없어도_온보딩_시작일이_있으면_추정값으로_예측한다() throws {
        let settings = CycleSettingsSnapshot(
            lastPeriodStartDate: TestSupport.day(2026, 9, 1),
            estimatedCycleLength: 30
        )

        let prediction = try XCTUnwrap(service.predict(
            records: [],
            settings: settings,
            now: TestSupport.date(2026, 9, 3)
        ))

        XCTAssertEqual(prediction.basis, .estimate)
        XCTAssertEqual(prediction.cycleLengthUsed, 30)
        XCTAssertEqual(prediction.nextPeriodStartDate, TestSupport.day(2026, 10, 1))
    }

    // MARK: - 주기 길이 산출 (PRD 6.2)

    func test_기록이_1건이면_온보딩_추정값을_쓴다() throws {
        let settings = CycleSettingsSnapshot(estimatedCycleLength: 28)
        let records = TestSupport.records(startDates: [TestSupport.day(2026, 8, 1)])

        let prediction = try XCTUnwrap(service.predict(
            records: records,
            settings: settings,
            now: TestSupport.date(2026, 8, 5)
        ))

        XCTAssertEqual(prediction.basis, .estimate)
        XCTAssertEqual(prediction.cycleLengthUsed, 28)
    }

    func test_기록이_2건이면_실제_간격으로_전환한다() throws {
        // 추정값은 28이지만 실제 간격은 31일이다.
        let settings = CycleSettingsSnapshot(estimatedCycleLength: 28)
        let records = TestSupport.records(startDates: [
            TestSupport.day(2026, 7, 1),
            TestSupport.day(2026, 8, 1),
        ])

        let prediction = try XCTUnwrap(service.predict(
            records: records,
            settings: settings,
            now: TestSupport.date(2026, 8, 5)
        ))

        XCTAssertEqual(prediction.basis, .history(cycleCount: 1))
        XCTAssertEqual(prediction.cycleLengthUsed, 31)
    }

    func test_주기_길이는_평균이_아니라_중앙값을_쓴다() throws {
        // 간격: 28, 28, 40 → 평균 32, 중앙값 28. 이상치에 덜 끌려가야 한다.
        let records = TestSupport.records(startDates: [
            TestSupport.day(2026, 1, 1),
            TestSupport.day(2026, 1, 29),
            TestSupport.day(2026, 2, 26),
            TestSupport.day(2026, 4, 7),
        ])

        let prediction = try XCTUnwrap(service.predict(
            records: records,
            settings: CycleSettingsSnapshot(),
            now: TestSupport.date(2026, 4, 10)
        ))

        XCTAssertEqual(prediction.cycleLengthUsed, 28)
        XCTAssertEqual(prediction.basis, .history(cycleCount: 3))
    }

    func test_21일_미만과_45일_초과_주기는_이상치로_제외한다() {
        let startDates = [
            TestSupport.day(2026, 1, 1),
            TestSupport.day(2026, 1, 15),   // 14일: 너무 짧음
            TestSupport.day(2026, 2, 12),   // 28일: 유효
            TestSupport.day(2026, 4, 30),   // 77일: 너무 김
            TestSupport.day(2026, 5, 28),   // 28일: 유효
        ]

        let lengths = service.validCycleLengths(from: startDates)

        XCTAssertEqual(lengths, [28, 28])
    }

    func test_유효한_간격이_하나도_없으면_추정값으로_되돌아간다() throws {
        // 두 기록의 간격이 90일이라 전부 이상치로 걸러진다.
        let settings = CycleSettingsSnapshot(estimatedCycleLength: 30)
        let records = TestSupport.records(startDates: [
            TestSupport.day(2026, 1, 1),
            TestSupport.day(2026, 4, 1),
        ])

        let prediction = try XCTUnwrap(service.predict(
            records: records,
            settings: settings,
            now: TestSupport.date(2026, 4, 5)
        ))

        XCTAssertEqual(prediction.basis, .estimate)
        XCTAssertEqual(prediction.cycleLengthUsed, 30)
    }

    func test_최근_6회_주기만_계산에_쓴다() throws {
        // 오래된 40일 주기 3회 뒤에 28일 주기 6회. 최근 6회만 보면 중앙값은 28이다.
        var startDates = [TestSupport.day(2026, 1, 1)]
        for length in [40, 40, 40, 28, 28, 28, 28, 28, 28] {
            let next = TestSupport.calendar.date(byAdding: .day, value: length, to: startDates.last!)!
            startDates.append(next)
        }

        let prediction = try XCTUnwrap(service.predict(
            records: TestSupport.records(startDates: startDates),
            settings: CycleSettingsSnapshot(),
            now: startDates.last!
        ))

        XCTAssertEqual(prediction.cycleLengthUsed, 28)
        XCTAssertEqual(prediction.basis, .history(cycleCount: 6))
    }

    func test_같은_날짜_기록이_중복돼도_주기_계산이_흔들리지_않는다() {
        let startDates = [
            TestSupport.day(2026, 1, 1),
            TestSupport.day(2026, 1, 1),
            TestSupport.day(2026, 1, 29),
        ]

        let normalized = service.normalizedStartDates(
            from: TestSupport.records(startDates: startDates),
            settings: CycleSettingsSnapshot()
        )

        XCTAssertEqual(normalized.count, 2)
        XCTAssertEqual(service.validCycleLengths(from: normalized), [28])
    }

    func test_설정값이_비정상적으로_커도_허용_범위로_잘린다() throws {
        let settings = CycleSettingsSnapshot(
            lastPeriodStartDate: TestSupport.day(2026, 9, 1),
            estimatedCycleLength: 400
        )

        let prediction = try XCTUnwrap(service.predict(
            records: [],
            settings: settings,
            now: TestSupport.date(2026, 9, 3)
        ))

        XCTAssertEqual(prediction.cycleLengthUsed, 45)
    }

    // MARK: - 중앙값 / 표준편차

    func test_중앙값은_홀수와_짝수_개수를_모두_처리한다() {
        XCTAssertEqual(CyclePredictionService.median(of: [28]), 28)
        XCTAssertEqual(CyclePredictionService.median(of: [26, 28, 30]), 28)
        XCTAssertEqual(CyclePredictionService.median(of: [26, 28, 30, 32]), 29)
        // 짝수 개수에서 가운데 두 값의 평균이 .5로 떨어지면 반올림한다.
        XCTAssertEqual(CyclePredictionService.median(of: [28, 29]), 29)
    }

    // MARK: - 배란일과 가임기 (PRD 6.2)

    func test_배란일은_주기의_절반이_아니라_예정일에서_14일을_역산한다() throws {
        // 40일 주기. 절반이면 20일째지만, 황체기 역산이면 예정일 -14일이다.
        let records = TestSupport.records(startDates: [
            TestSupport.day(2026, 1, 1),
            TestSupport.day(2026, 2, 10),
            TestSupport.day(2026, 3, 22),
        ])

        let prediction = try XCTUnwrap(service.predict(
            records: records,
            settings: CycleSettingsSnapshot(),
            now: TestSupport.date(2026, 3, 25)
        ))

        XCTAssertEqual(prediction.cycleLengthUsed, 40)
        XCTAssertEqual(prediction.nextPeriodStartDate, TestSupport.day(2026, 5, 1))
        XCTAssertEqual(prediction.ovulationDate, TestSupport.day(2026, 4, 17))
    }

    func test_가임기는_배란일_5일_전부터_1일_후까지다() throws {
        let settings = CycleSettingsSnapshot(
            lastPeriodStartDate: TestSupport.day(2026, 9, 1),
            estimatedCycleLength: 28
        )

        let prediction = try XCTUnwrap(service.predict(
            records: [],
            settings: settings,
            now: TestSupport.date(2026, 9, 3)
        ))

        // 예정일 9/29 → 배란 9/15 → 가임기 9/10 ~ 9/16
        XCTAssertEqual(prediction.ovulationDate, TestSupport.day(2026, 9, 15))
        XCTAssertEqual(prediction.fertileWindow.lowerBound, TestSupport.day(2026, 9, 10))
        XCTAssertEqual(prediction.fertileWindow.upperBound, TestSupport.day(2026, 9, 16))
    }

    // MARK: - 신뢰도 (PRD 6.2)

    func test_주기가_규칙적이면_높은_신뢰도다() throws {
        let records = TestSupport.records(startDates: [
            TestSupport.day(2026, 1, 1),
            TestSupport.day(2026, 1, 29),
            TestSupport.day(2026, 2, 26),
            TestSupport.day(2026, 3, 26),
        ])

        let prediction = try XCTUnwrap(service.predict(
            records: records,
            settings: CycleSettingsSnapshot(),
            now: TestSupport.date(2026, 3, 27)
        ))

        XCTAssertEqual(prediction.confidence, .high)
        XCTAssertTrue(prediction.showsCountdown)
    }

    func test_주기_편차가_크면_낮은_신뢰도로_전환한다() throws {
        // 간격 22, 35, 24, 40 → 표준편차가 기준(4일)을 크게 넘는다.
        var startDates = [TestSupport.day(2026, 1, 1)]
        for length in [22, 35, 24, 40] {
            startDates.append(
                TestSupport.calendar.date(byAdding: .day, value: length, to: startDates.last!)!
            )
        }

        let prediction = try XCTUnwrap(service.predict(
            records: TestSupport.records(startDates: startDates),
            settings: CycleSettingsSnapshot(),
            now: startDates.last!
        ))

        XCTAssertEqual(prediction.confidence, .low)
    }

    func test_주기_표본이_하나뿐이면_높은_신뢰도로_보지_않는다() throws {
        // 표본이 1개면 표준편차가 0으로 나와 확신이 과장된다.
        let records = TestSupport.records(startDates: [
            TestSupport.day(2026, 8, 1),
            TestSupport.day(2026, 8, 29),
        ])

        let prediction = try XCTUnwrap(service.predict(
            records: records,
            settings: CycleSettingsSnapshot(),
            now: TestSupport.date(2026, 8, 30)
        ))

        XCTAssertEqual(prediction.basis, .history(cycleCount: 1))
        XCTAssertEqual(prediction.confidence, .low)
    }

    func test_추정값_기반_예측은_항상_낮은_신뢰도다() throws {
        let settings = CycleSettingsSnapshot(lastPeriodStartDate: TestSupport.day(2026, 9, 1))

        let prediction = try XCTUnwrap(service.predict(
            records: [],
            settings: settings,
            now: TestSupport.date(2026, 9, 3)
        ))

        XCTAssertEqual(prediction.confidence, .low)
    }

    // MARK: - 예측 안전장치 (PRD 4.1 / 6.2)

    func test_예정일_전에는_남은_일수를_센다() {
        let status = service.status(
            nextStart: TestSupport.day(2026, 9, 10),
            now: TestSupport.date(2026, 9, 3)
        )

        XCTAssertEqual(status, .upcoming(daysRemaining: 7))
    }

    func test_예정일_당일은_남은_일수가_0이다() {
        let status = service.status(
            nextStart: TestSupport.day(2026, 9, 3),
            now: TestSupport.date(2026, 9, 3, hour: 23)
        )

        XCTAssertEqual(status, .upcoming(daysRemaining: 0))
    }

    func test_예정일이_지나도_7일까지는_카운트다운을_유지한다() {
        let status = service.status(
            nextStart: TestSupport.day(2026, 9, 3),
            now: TestSupport.date(2026, 9, 10)
        )

        XCTAssertEqual(status, .overdue(daysPast: 7))
    }

    func test_예정일이_7일을_넘게_지나면_카운트다운을_멈춘다() throws {
        // 임신 등으로 예측이 빗나갔을 때 계속 틀린 숫자를 보여주지 않기 위한 안전장치.
        let status = service.status(
            nextStart: TestSupport.day(2026, 9, 3),
            now: TestSupport.date(2026, 9, 11)
        )

        XCTAssertEqual(status, .stale(daysPast: 8))

        let settings = CycleSettingsSnapshot(lastPeriodStartDate: TestSupport.day(2026, 8, 6))
        let prediction = try XCTUnwrap(service.predict(
            records: [],
            settings: settings,
            now: TestSupport.date(2026, 9, 11)
        ))

        XCTAssertFalse(prediction.showsCountdown)
    }
}
