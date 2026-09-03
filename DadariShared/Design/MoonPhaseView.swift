import SwiftUI

/// 문페이즈 히어로. PRD 3.2의 핵심 모티프다.
///
/// 도넛형 링 대신 달이 차고 기우는 모양으로 주기를 표현한다.
/// 원 두 개를 겹치고 위쪽 원을 가로로 밀어내는 순수 벡터 방식이라 이미지 에셋이 필요 없다.
///
/// `fullness`는 0이 그믐, 1이 보름이다. 그림자 원을 그만큼 오른쪽으로 밀어낸다.
/// 0이면 달을 완전히 덮어 그믐이 되고, 지름만큼 밀면 완전히 벗어나 보름이 된다.
struct MoonPhaseView: View {
    /// 0 = 그믐, 1 = 보름
    var fullness: Double
    var diameter: CGFloat
    var tint: Color = DadariColor.accent
    /// 달을 덮는 색.
    ///
    /// 목업은 흰색으로 덮지만, 그러면 그믐(fullness 0)일 때 흰 배경에 흰 원이 되어
    /// 달이 통째로 사라진다. 목업의 히어로 계산식이 그믐까지 도달하지 않아 드러나지 않았던 것이고,
    /// 팝오버의 생리 단계(`.phase-moon.p0`)는 카드색 원으로 그려져 있다.
    /// 그 쪽 표현을 따라 카드색으로 덮어서, 그믐에서도 옅은 원이 남게 한다.
    var shadow: Color = DadariColor.card

    var body: some View {
        ZStack(alignment: .leading) {
            Circle()
                .fill(tint)
            Circle()
                .fill(shadow)
                .offset(x: diameter * clampedFullness)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .animation(.easeInOut(duration: 0.35), value: clampedFullness)
        .accessibilityHidden(true)
    }

    private var clampedFullness: Double {
        max(0, min(1, fullness))
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                MoonPhaseView(fullness: value, diameter: 60)
            }
        }
        Text("왼쪽이 그믐(생리), 오른쪽이 보름(배란)")
            .font(.caption)
            .foregroundStyle(DadariColor.inkSoft)
    }
    .padding()
    .background(DadariColor.background)
}
