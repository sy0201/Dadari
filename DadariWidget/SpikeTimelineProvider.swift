import WidgetKit

struct SpikeTimelineEntry: TimelineEntry {
    let date: Date
    let latest: SpikeEntry?
    let count: Int

    static let placeholder = SpikeTimelineEntry(date: .now, latest: nil, count: 0)
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
        let entries = SpikeRecordStore.shared.entries()
        return SpikeTimelineEntry(date: .now, latest: entries.first, count: entries.count)
    }
}
