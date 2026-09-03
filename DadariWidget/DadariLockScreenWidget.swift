import AppIntents
import SwiftUI
import WidgetKit

/// 잠금화면 위젯. 이 앱의 메인 UX다(PRD 5.1).
///
/// 디자인은 PRD 10번 일정상 5~8주차 작업이라 아직 붙이지 않았다.
/// 지금은 1주차에 검증한 배선 위에 2주차의 예측 결과를 얹어 놓은 상태다.
struct DadariLockScreenWidget: Widget {
    static let kind = "DadariLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DadariTimelineProvider()) { entry in
            DadariWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("다달이")
        .description("잠금화면에서 바로 시작일/종료일을 기록합니다.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall])
    }
}

struct DadariWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DadariWidgetEntry

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
                    startButton
                    endButton
                }
            }

        default:
            VStack(spacing: 10) {
                Text(statusText)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                startButton
                endButton
            }
            .padding(4)
        }
    }

    private var startButton: some View {
        Button(intent: RecordPeriodStartIntent()) {
            Text("시작").font(.caption2)
        }
    }

    private var endButton: some View {
        Button(intent: RecordPeriodEndIntent()) {
            Text("종료").font(.caption2)
        }
    }

    /// App Group을 못 잡으면 위젯이 자기 로컬 저장소에 쓰게 되고, 그러면 앱에서는 기록이 안 보인다.
    /// 잠금화면에서 바로 구분할 수 있게 표시한다(SPIKE.md).
    private var statusText: String {
        let prefix = entry.isUsingSharedContainer ? "" : "⚠︎ 로컬 "
        return prefix + predictionText
    }

    private var predictionText: String {
        guard let prediction = entry.prediction else {
            return "기록 없음"
        }
        switch prediction.status {
        case .upcoming(let days):
            let dday = days == 0 ? "오늘" : "D-\(days)"
            return prediction.confidence == .low ? "\(dday) 예상" : dday
        case .overdue(let days):
            return "예정일 +\(days)일"
        case .stale:
            // 카운트다운을 멈춘다. 틀린 숫자를 계속 보여주지 않기 위한 안전장치(PRD 4.1).
            return "기록을 확인해 주세요"
        }
    }
}
