import WidgetKit

struct DadariWidgetEntry: TimelineEntry {
    let date: Date
    let latestRecord: PeriodRecordSnapshot?
    let prediction: CyclePrediction?
    let recordCount: Int
    /// 위젯 익스텐션 프로세스가 App Group 스토어를 잡았는지.
    /// 앱과 위젯은 별개 프로세스라 한쪽만 실패할 수 있어서 위젯에 직접 표시한다(SPIKE.md).
    let isUsingSharedContainer: Bool

    static let placeholder = DadariWidgetEntry(
        date: .now,
        latestRecord: nil,
        prediction: nil,
        recordCount: 0,
        isUsingSharedContainer: true
    )
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
        return DadariWidgetEntry(
            date: date,
            latestRecord: records.first,
            prediction: DadariEnvironment.currentPrediction(now: date),
            recordCount: records.count,
            isUsingSharedContainer: DadariEnvironment.isUsingSharedContainer
        )
    }
}
