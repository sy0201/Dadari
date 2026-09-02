import Foundation
@testable import Dadari

/// 테스트가 실행 환경의 로캘/타임존에 흔들리지 않도록 달력을 고정한다.
enum TestSupport {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )
        guard let date = components.date else {
            fatalError("테스트 픽스처 날짜 생성 실패: \(year)-\(month)-\(day)")
        }
        return date
    }

    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.startOfDay(for: date(year, month, day))
    }

    /// 시작일만 지정한 기록 스냅샷.
    static func record(
        start: Date,
        end: Date? = nil,
        flow: FlowLevel? = nil,
        source: RecordSource = .app
    ) -> PeriodRecordSnapshot {
        PeriodRecordSnapshot(startDate: start, endDate: end, flow: flow, source: source)
    }

    /// 시작일 목록으로 기록 배열을 만든다.
    static func records(startDates: [Date]) -> [PeriodRecordSnapshot] {
        startDates.map { PeriodRecordSnapshot(startDate: $0) }
    }
}
