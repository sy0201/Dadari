import AppIntents
import SwiftUI
import WidgetKit

/// 1주차 기술 스파이크용 위젯.
/// 디자인은 5~8주차에 붙이고, 지금은 `Button(intent:)`가 잠금화면에서
/// 앱을 열지 않고 실행되는지만 확인한다.
struct SpikeLockScreenWidget: Widget {
    static let kind = "SpikeLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SpikeTimelineProvider()) { entry in
            SpikeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("다달이 스파이크")
        .description("잠금화면에서 바로 시작일/종료일을 기록합니다.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall])
    }
}

struct SpikeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpikeTimelineEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Button(intent: RecordPeriodStartIntent()) {
                Image(systemName: "drop.fill")
            }
            .buttonStyle(.plain)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.caption2)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    intentButton(.start)
                    intentButton(.end)
                }
            }

        default:
            VStack(spacing: 10) {
                Text(statusText)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                intentButton(.start)
                intentButton(.end)
            }
            .padding(4)
        }
    }

    /// App Group을 못 잡으면 위젯이 자기 로컬 저장소에 쓰게 되고, 그러면 앱에서는 기록이 안 보인다.
    /// 위젯 텍스트만 갱신되고 앱은 비어 있는 상태를 잠금화면에서 바로 구분할 수 있게 표시한다.
    private var statusText: String {
        let prefix = entry.isUsingSharedContainer ? "" : "⚠︎ 로컬 "
        guard let latest = entry.latest else { return prefix + "기록 없음" }
        return prefix + "\(latest.kind.label) \(latest.day.formatted(.dateTime.month().day())) · \(entry.count)건"
    }

    @ViewBuilder
    private func intentButton(_ kind: SpikeEntryKind) -> some View {
        switch kind {
        case .start:
            Button(intent: RecordPeriodStartIntent()) {
                Text("시작").font(.caption2)
            }
        case .end:
            Button(intent: RecordPeriodEndIntent()) {
                Text("종료").font(.caption2)
            }
        }
    }
}
