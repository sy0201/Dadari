import SwiftUI

/// 목업의 컬러 팝 카드 버튼과 같은 톤. 화면 하나에 진한 포인트는 하나만 둔다(PRD 3.2).
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(DadariColor.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DadariColor.accent.opacity(isEnabled ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// 보조 동작. "나중에" 같은 건너뛰기 경로에 쓴다.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DadariColor.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
