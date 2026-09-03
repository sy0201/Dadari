import WidgetKit

struct DadariWidgetEntry: TimelineEntry {
    let date: Date
    let prediction: CyclePrediction?
    let hasOngoingPeriod: Bool
    /// 0 = 그믐(생리), 1 = 보름(배란기)
    let moonFullness: Double
    /// 위젯 익스텐션 프로세스가 App Group 스토어를 잡았는지.
    /// 앱과 위젯은 별개 프로세스라 한쪽만 실패할 수 있어서 위젯에 직접 표시한다(SPIKE.md).
    let isUsingSharedContainer: Bool

    static let placeholder = DadariWidgetEntry(
        date: .now,
        prediction: nil,
        hasOngoingPeriod: false,
        moonFullness: 0.5,
        isUsingSharedContainer: true
    )

    /// 가로형/정사각의 큰 문구.
    ///
    /// DEBUG 빌드에서는 뒤에 빌드 시각을 붙인다. 위젯이 이전 빌드에 물려 있는지
    /// 눈으로 바로 구분하기 위한 것이다(BuildStamp 참고).
    var headline: String {
        #if DEBUG
        return "\(baseHeadline) · \(BuildStamp.short)"
        #else
        return baseHeadline
        #endif
    }

    private var baseHeadline: String {
        guard isUsingSharedContainer else { return "연동 확인 필요" }
        guard let prediction else { return "기록을 시작해요" }
        if hasOngoingPeriod { return "생리 중" }

        switch prediction.status {
        case .upcoming(let days):
            let dday = days == 0 ? "오늘 예정" : "D-\(days)"
            return prediction.confidence == .low ? "\(dday) 예상" : dday
        case .overdue(let days):
            return "예정일 +\(days)일"
        case .stale:
            // 카운트다운을 멈춘다. 틀린 숫자를 계속 보여주지 않기 위한 안전장치(PRD 4.1).
            return "기록을 확인해요"
        }
    }

    /// 정사각에서 큰 문구 아래에 붙는 보조 문구.
    var subheadline: String {
        guard let prediction else { return "잠금화면에서 탭 한 번" }
        return "주기 \(prediction.cycleLengthUsed)일 기준"
    }

    /// 원형에 들어가는 아주 짧은 문구.
    var compactStatus: String {
        guard isUsingSharedContainer else { return "!" }
        guard let prediction else { return "–" }
        if hasOngoingPeriod { return "중" }

        switch prediction.status {
        case .upcoming(let days):
            return days == 0 ? "0" : "\(days)"
        case .overdue(let days):
            return "+\(days)"
        case .stale:
            return "?"
        }
    }

    var accessibilityLabel: String {
        "\(headline). 탭하면 오늘 날짜로 기록해요."
    }
}

struct DadariTimelineProvider: TimelineProvider {
    /// D-day가 자정마다 바뀌므로 며칠치 엔트리를 미리 만들어 둔다.
    private let scheduledDays = 8

    private var calendar: Calendar { .current }

    func placeholder(in context: Context) -> DadariWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DadariWidgetEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DadariWidgetEntry>) -> Void) {
        // 기록이 생기면 인텐트가 reloadAllTimelines()로 즉시 갱신한다.
        // 여기서 만드는 엔트리는 기록이 없는 동안 D-day가 매일 줄어들게 하는 용도다.
        let today = calendar.startOfDay(for: .now)
        var entries = [entry(at: .now)]
        for offset in 1..<scheduledDays {
            guard let midnight = calendar.date(byAdding: .day, value: offset, to: today) else { break }
            entries.append(entry(at: midnight))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> DadariWidgetEntry {
        let store = DadariEnvironment.recordStore
        let records = (try? store.records()) ?? []
        let prediction = DadariEnvironment.currentPrediction(now: date)
        let cycleCalendar = CycleCalendar(calendar: calendar)

        return DadariWidgetEntry(
            date: date,
            prediction: prediction,
            hasOngoingPeriod: records.contains { $0.isOngoing },
            moonFullness: prediction.map { cycleCalendar.moonFullness(for: date, prediction: $0) } ?? 0,
            isUsingSharedContainer: DadariEnvironment.isUsingSharedContainer
        )
    }
}
