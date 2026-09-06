import SwiftUI

/// 라인아트 스탯 3개. PRD 3.2에 따라 보조 정보는 얇은 선 아이콘 + 텍스트로 담백하게 둔다.
struct StatRowView: View {
    let averageCycleLength: Int?
    let periodLength: Int?
    let confidence: CyclePrediction.Confidence?

    var body: some View {
        HStack(spacing: 10) {
            StatItem(icon: .clock, title: "평균 주기", value: averageCycleLength.map { "\($0)일" } ?? "–")
            StatItem(icon: .plus, title: "생리 기간", value: periodLength.map { "\($0)일" } ?? "–")
            StatItem(icon: .check, title: "신뢰도", value: confidenceText)
        }
    }

    private var confidenceText: String {
        switch confidence {
        case .high: return "높음"
        case .low: return "낮음"
        case nil: return "–"
        }
    }
}

private struct StatItem: View {
    enum Icon {
        case clock
        case plus
        case check
    }

    let icon: Icon
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            LineArtIcon(icon: icon)
                .frame(width: 22, height: 22)
                .padding(.bottom, 8)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DadariColor.inkSoft)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DadariColor.ink)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(DadariColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// 목업의 인라인 SVG를 그대로 옮긴 아이콘. 24x24 좌표계에 1.5pt 선으로 그린다.
private struct LineArtIcon: View {
    let icon: StatItem.Icon

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 24
            path
                .applying(CGAffineTransform(scaleX: scale, y: scale))
                .stroke(
                    DadariColor.accentDeep,
                    style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round, lineJoin: .round)
                )
        }
        .accessibilityHidden(true)
    }

    private var path: Path {
        var path = Path()
        switch icon {
        case .clock:
            path.addEllipse(in: CGRect(x: 4, y: 4, width: 16, height: 16))
            path.move(to: CGPoint(x: 12, y: 8))
            path.addLine(to: CGPoint(x: 12, y: 12))
            path.addLine(to: CGPoint(x: 15, y: 14))
        case .plus:
            path.move(to: CGPoint(x: 6, y: 12))
            path.addLine(to: CGPoint(x: 18, y: 12))
            path.move(to: CGPoint(x: 12, y: 6))
            path.addLine(to: CGPoint(x: 12, y: 18))
        case .check:
            path.move(to: CGPoint(x: 5, y: 12))
            path.addLine(to: CGPoint(x: 9, y: 16))
            path.addLine(to: CGPoint(x: 19, y: 6))
        }
        return path
    }
}

#Preview {
    StatRowView(averageCycleLength: 28, periodLength: 5, confidence: .high)
        .padding()
        .background(DadariColor.background)
}
