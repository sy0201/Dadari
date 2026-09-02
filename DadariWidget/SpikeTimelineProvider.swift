import WidgetKit

struct SpikeTimelineEntry: TimelineEntry {
    let date: Date
    let latest: SpikeEntry?
    let count: Int
    /// 위젯 익스텐션 프로세스가 App Group 컨테이너를 잡았는지.
    /// 앱과 위젯은 별개 프로세스라 한쪽만 실패할 수 있어서, 위젯 쪽 상태를 위젯에 직접 표시한다.
    let isUsingSharedContainer: Bool

    static let placeholder = SpikeTimelineEntry(
        date: .now,
        latest: nil,
        count: 0,
        isUsingSharedContainer: true
    )
}

struct SpikeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpikeTimelineEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SpikeTimelineEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpikeTimelineEntry>) -> Void) {
        // 기록 시점에 인텐트가 reloadAllTimelines()를 호출하므로 주기적 갱신은 필요 없다.
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> SpikeTimelineEntry {
        let store = SpikeRecordStore.shared
        let entries = store.entries()
        return SpikeTimelineEntry(
            date: .now,
            latest: entries.first,
            count: entries.count,
            isUsingSharedContainer: store.isUsingSharedContainer
        )
    }
}
