import XCTest
@testable import Dadari

/// 주간 스트립이 보여줄 날짜를 계산하는 규칙을 고정한다.
///
/// 실기기 확인에서 "고른 날짜가 늘 맨 앞에 오고 요일 열이 어긋난다"는 문제가 나왔다.
/// 선택한 날짜가 속한 달력 주를 보여주도록 바꾸면서 그 규칙을 여기에 묶어둔다.
final class WeekStripDatesTests: XCTestCase {
    private var calendar: Calendar { TestSupport.calendar }

    /// `CycleCalendarView`가 쓰는 것과 같은 계산.
    private func weekDates(containing date: Date) -> [Date] {
        let day = calendar.startOfDay(for: date)
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: day) else { return [day] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    func test_주간은_선택한_날짜가_속한_주를_보여준다() {
        // 2026-09-03은 목요일. 그 주는 8/30(일) ~ 9/5(토).
        let dates = weekDates(containing: TestSupport.date(2026, 9, 3))

        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(dates.first, TestSupport.day(2026, 8, 30))
        XCTAssertEqual(dates.last, TestSupport.day(2026, 9, 5))
    }

    func test_같은_주_안에서_날짜를_바꿔도_주는_그대로다() {
        let thursday = weekDates(containing: TestSupport.date(2026, 9, 3))
        let saturday = weekDates(containing: TestSupport.date(2026, 9, 5))

        XCTAssertEqual(thursday, saturday, "같은 주면 격자가 흔들리지 않아야 한다")
    }

    func test_고른_날짜가_늘_맨_앞에_오지_않는다() {
        // 이전 구현은 선택한 날짜부터 7일을 만들어 요일 열이 매번 어긋났다.
        let dates = weekDates(containing: TestSupport.date(2026, 9, 3))

        XCTAssertNotEqual(dates.first, TestSupport.day(2026, 9, 3))
        XCTAssertTrue(dates.contains(TestSupport.day(2026, 9, 3)))
    }

    func test_요일_순서가_일요일부터_시작한다() {
        let dates = weekDates(containing: TestSupport.date(2026, 9, 3))
        let weekdays = dates.map { calendar.component(.weekday, from: $0) }

        XCTAssertEqual(weekdays, [1, 2, 3, 4, 5, 6, 7], "일~토 순서")
    }

    func test_주를_옮기면_같은_요일이_유지된다() {
        let day = TestSupport.day(2026, 9, 3)
        let nextWeekDay = calendar.date(byAdding: .day, value: 7, to: day)!

        XCTAssertEqual(
            calendar.component(.weekday, from: day),
            calendar.component(.weekday, from: nextWeekDay)
        )
        XCTAssertEqual(weekDates(containing: nextWeekDay).first, TestSupport.day(2026, 9, 6))
    }

    func test_달을_넘어가는_주도_이어서_보여준다() {
        // 8/30(일)~9/5(토)는 8월과 9월에 걸쳐 있다.
        let dates = weekDates(containing: TestSupport.date(2026, 8, 31))

        XCTAssertEqual(dates.first, TestSupport.day(2026, 8, 30))
        XCTAssertEqual(dates.last, TestSupport.day(2026, 9, 5))
    }
}

/// 달력 이동 범위 규칙. 과거는 자유롭게, 미래는 다음 달까지만 본다.
final class CalendarViewableRangeTests: XCTestCase {
    private var calendar: Calendar { TestSupport.calendar }
    /// 2026-10-28을 "오늘"로 고정한다. 허용 한도는 2026-11-30이다.
    private let now = TestSupport.date(2026, 10, 28)

    func test_가장_먼_날짜는_다음_달_말일이다() {
        let latest = CycleCalendarView.latestViewableDate(now: now, calendar: calendar)

        XCTAssertEqual(latest, TestSupport.day(2026, 11, 30))
    }

    func test_연말에는_다음_해_1월_말일까지다() {
        let latest = CycleCalendarView.latestViewableDate(
            now: TestSupport.date(2026, 12, 15), calendar: calendar
        )

        XCTAssertEqual(latest, TestSupport.day(2027, 1, 31))
    }

    func test_과거는_아무리_멀어도_볼_수_있다() {
        XCTAssertTrue(CycleCalendarView.isWithinViewableRange(
            TestSupport.date(2024, 1, 1), now: now, calendar: calendar
        ))
    }

    func test_다음_달_말일까지는_허용하고_그_다음날부터는_막는다() {
        XCTAssertTrue(CycleCalendarView.isWithinViewableRange(
            TestSupport.date(2026, 11, 30), now: now, calendar: calendar
        ))
        XCTAssertFalse(CycleCalendarView.isWithinViewableRange(
            TestSupport.date(2026, 12, 1), now: now, calendar: calendar
        ))
    }

    func test_이전_달로_옮기면_한_달_전_같은_날이다() {
        let moved = CycleCalendarView.shifted(
            TestSupport.day(2026, 10, 28), byMonths: -1, now: now, calendar: calendar
        )

        XCTAssertEqual(moved, TestSupport.day(2026, 9, 28))
    }

    func test_다음_달로는_한_번만_옮길_수_있다() {
        let once = CycleCalendarView.shifted(
            TestSupport.day(2026, 10, 28), byMonths: 1, now: now, calendar: calendar
        )
        XCTAssertEqual(once, TestSupport.day(2026, 11, 28))

        let twice = CycleCalendarView.shifted(
            TestSupport.day(2026, 11, 28), byMonths: 1, now: now, calendar: calendar
        )
        XCTAssertNil(twice, "두 달 뒤는 볼 수 없다")
    }

    func test_31일에서_짧은_달로_옮겨도_날짜가_넘치지_않는다() {
        let moved = CycleCalendarView.shifted(
            TestSupport.day(2026, 3, 31), byMonths: -1, now: now, calendar: calendar
        )

        XCTAssertEqual(moved, TestSupport.day(2026, 2, 28))
    }
}
