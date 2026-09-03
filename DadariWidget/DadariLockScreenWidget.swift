import AppIntents
import SwiftUI
import WidgetKit

/// 잠금화면 위젯. 이 앱의 메인 UX다(PRD 5.1).
///
/// 잠금화면 계열(`accessory*`)은 시스템이 단색으로 렌더링해서 색이 그대로 나오지 않는다.
/// 그래서 색이 아니라 **형태**로 정보를 전한다. 문페이즈 원의 차오른 정도가 주기 위치를,
/// 큰 숫자가 D-day를 나타낸다. 홈 화면용 `systemSmall`에서는 목업의 듀오톤을 그대로 쓴다.
struct DadariLockScreenWidget: Widget {
    static let kind = "DadariLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DadariTimelineProvider()) { entry in
            DadariWidgetView(entry: entry)
        }
        .configurationDisplayName("다달이")
        .description("잠금화면에서 탭 한 번으로 시작일과 종료일을 기록해요.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall])
    }
}

struct DadariWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DadariWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    // MARK: - 잠금화면: 원형

    /// 원형은 버튼 하나만 들어간다. 진행 중이면 종료를, 아니면 시작을 기록한다.
    @ViewBuilder
    private var circular: some View {
        if entry.hasOngoingPeriod {
            circularButton(intent: RecordIntents.end)
        } else {
            circularButton(intent: RecordIntents.start)
        }
    }

    private func circularButton(intent: some AppIntent) -> some View {
        Button(intent: intent) {
            ZStack {
                AccessoryWidgetBackground()
                MoonPhaseView(
                    fullness: entry.moonFullness,
                    diameter: 44,
                    tint: .white.opacity(0.35),
                    shadow: .clear
                )
                Text(entry.compactStatus)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
        }
        .buttonStyle(.plain)
        .containerBackground(.clear, for: .widget)
        .accessibilityLabel(entry.accessibilityLabel)
    }

    // MARK: - 잠금화면: 가로형

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                MoonPhaseView(
                    fullness: entry.moonFullness,
                    diameter: 14,
                    tint: .white.opacity(0.9),
                    shadow: .clear
                )
                Text(entry.headline)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 5) {
                intentButton("시작", intent: RecordIntents.start)
                intentButton("종료", intent: RecordIntents.end)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
        .accessibilityLabel(entry.accessibilityLabel)
    }

    private func intentButton(_ title: String, intent: some AppIntent) -> some View {
        Button(intent: intent) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.22))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 홈 화면: 정사각

    /// 홈 화면에서는 색이 그대로 나오므로 목업의 컬러 팝 카드 톤을 따른다.
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            MoonPhaseView(fullness: entry.moonFullness, diameter: 34)
                .padding(.bottom, 8)

            Text(entry.headline)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DadariColor.accentDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(entry.subheadline)
                .font(.system(size: 11))
                .foregroundStyle(DadariColor.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                smallButton("시작", intent: RecordIntents.start, filled: true)
                smallButton("종료", intent: RecordIntents.end, filled: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(DadariColor.background, for: .widget)
        .accessibilityLabel(entry.accessibilityLabel)
    }

    private func smallButton(_ title: String, intent: some AppIntent, filled: Bool) -> some View {
        Button(intent: intent) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(filled ? DadariColor.background : DadariColor.accentDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(filled ? DadariColor.accent : DadariColor.accentSoft)
                )
        }
        .buttonStyle(.plain)
    }
}

/// 위젯 버튼이 쓰는 인텐트 모음. 상황에 따라 시작/종료를 골라 넘긴다.
enum RecordIntents {
    static var start: RecordPeriodStartIntent { RecordPeriodStartIntent() }
    static var end: RecordPeriodEndIntent { RecordPeriodEndIntent() }
}
