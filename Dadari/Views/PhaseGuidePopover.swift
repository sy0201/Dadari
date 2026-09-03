import SwiftUI

/// 주기 5단계 안내 팝오버.
///
/// PRD 3.2에 따라 상시 노출하지 않고 히어로 옆 "?" 버튼을 눌렀을 때만 띄운다.
/// 평소 화면을 최대한 단순하게 유지하기 위한 것이다.
struct PhaseGuidePopover: View {
    /// 목업의 `.phase-moon` 클래스 다섯 개를 그대로 옮긴 값이다.
    private struct Phase: Identifiable {
        let id = UUID()
        let label: String
        let tint: Color
        let fullness: Double
    }

    private let phases: [Phase] = [
        Phase(label: "생리", tint: DadariColor.card, fullness: 1),
        Phase(label: "난포기", tint: DadariColor.accent, fullness: 16.0 / 26.0),
        Phase(label: "가임기", tint: DadariColor.accent, fullness: 1),
        Phase(label: "황체기", tint: DadariColor.accent2, fullness: 9.0 / 26.0),
        Phase(label: "PMS", tint: DadariColor.accent2Soft, fullness: 1),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("주기 단계 안내")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DadariColor.ink)
                .padding(.bottom, 14)

            HStack(alignment: .top) {
                ForEach(phases) { phase in
                    VStack(spacing: 6) {
                        MoonPhaseView(fullness: phase.fullness, diameter: 26, tint: phase.tint)
                        Text(phase.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(DadariColor.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 2)

            Text("그믐(생리)에서 보름(가임기)으로 차올랐다가 다시 그믐으로 기우는 흐름으로 표시돼요.")
                .font(.system(size: 11))
                .foregroundStyle(DadariColor.inkSoft)
                .lineSpacing(4)
                .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(DadariColor.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: DadariColor.ink.opacity(0.28), radius: 17, x: 0, y: 16)
    }
}

#Preview {
    ZStack {
        DadariColor.ink.opacity(0.35)
        PhaseGuidePopover().padding(20)
    }
}
