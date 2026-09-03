import SwiftUI

/// 달력 한 칸. 주간 스트립에서는 원, 월간 그리드에서는 둥근 사각형으로 그린다.
///
/// 상태별 표현은 목업의 `.week-cell` / `.cal-day` 클래스를 그대로 옮긴 것이다.
/// 채움(실제 생리), 파선 테두리(예측), 옅은 배경(가임기), 점선 테두리(PMS)로 구분해서
/// 색 하나에만 의존하지 않게 했다.
struct DayMarker: View {
    enum MarkerShape {
        case circle
        case roundedRectangle
    }

    let date: Date
    let kind: CycleDayKind
    let isSelected: Bool
    let shape: MarkerShape

    private var calendar: Calendar { .current }

    var body: some View {
        ZStack {
            background
            border
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 12, weight: isSelected ? .bold : textWeight))
                .foregroundStyle(foreground)
        }
        .overlay(selectionOverlay)
    }

    // MARK: - 상태별 표현

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .loggedPeriod:
            shapeView.fill(DadariColor.accent)
        case .fertile:
            shapeView.fill(DadariColor.accentSoft)
        default:
            shapeView.fill(.clear)
        }
    }

    @ViewBuilder
    private var border: some View {
        switch kind {
        case .predictedPeriod:
            shapeView.strokeBorder(
                DadariColor.accent,
                style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5])
            )
        case .pms:
            shapeView.strokeBorder(
                DadariColor.accent2,
                style: StrokeStyle(lineWidth: 2, dash: [0.5, 3], dashPhase: 0)
            )
        default:
            EmptyView()
        }
    }

    /// 선택 표시는 상태와 겹칠 수 있어 바깥쪽 윤곽으로 그린다(목업의 outline / inset shadow).
    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            switch shape {
            case .circle:
                Circle()
                    .strokeBorder(DadariColor.ink, lineWidth: 1.5)
                    .padding(-1.5)
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(DadariColor.ink, lineWidth: 1.5)
            }
        }
    }

    private var foreground: Color {
        switch kind {
        case .loggedPeriod: return .white
        case .predictedPeriod, .fertile: return DadariColor.accentDeep
        case .pms: return DadariColor.accent2Deep
        case .ordinary: return DadariColor.ink
        }
    }

    private var textWeight: Font.Weight {
        kind == .loggedPeriod ? .semibold : .regular
    }

    private var shapeView: AnyInsettableShape {
        switch shape {
        case .circle:
            return AnyInsettableShape(Circle())
        case .roundedRectangle:
            return AnyInsettableShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

/// 셀 모양을 값으로 넘기기 위한 타입 지우개.
/// `strokeBorder`가 `InsettableShape`를 요구해서 `AnyShape`로는 부족하다.
struct AnyInsettableShape: InsettableShape {
    private let makePath: @Sendable (CGRect) -> Path
    private let makeInset: @Sendable (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) {
        makePath = { shape.path(in: $0) }
        makeInset = { AnyInsettableShape(shape.inset(by: $0)) }
    }

    func path(in rect: CGRect) -> Path {
        makePath(rect)
    }

    func inset(by amount: CGFloat) -> AnyInsettableShape {
        makeInset(amount)
    }
}

/// 범례의 색 견본. 목업의 `.sw` 클래스.
struct LegendSwatch: View {
    let kind: CycleDayKind

    var body: some View {
        Group {
            switch kind {
            case .loggedPeriod:
                RoundedRectangle(cornerRadius: 3).fill(DadariColor.accent)
            case .predictedPeriod:
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(DadariColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
            case .fertile:
                RoundedRectangle(cornerRadius: 3)
                    .fill(DadariColor.accentSoft)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(DadariColor.accent, lineWidth: 1))
            case .pms:
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(DadariColor.accent2, style: StrokeStyle(lineWidth: 2, dash: [0.5, 2.5]))
            case .ordinary:
                RoundedRectangle(cornerRadius: 3).fill(DadariColor.card)
            }
        }
        .frame(width: 9, height: 9)
    }
}
