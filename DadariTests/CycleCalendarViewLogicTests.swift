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
