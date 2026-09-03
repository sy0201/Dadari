import SwiftUI

/// 목업(ui-mockup.html)의 CSS 변수를 그대로 옮긴 팔레트. PRD 3.3의 색상표와 같다.
///
/// 플랫 컬러 두 가지만 쓰는 듀오톤이고 그라데이션은 쓰지 않는다.
/// 핑크·레드 계열을 배제하는 것이 이 앱의 기본 원칙이다(PRD 3번).
///
/// - Note: 목업이 라이트 모드만 정의하고 있어 값을 고정해 두었다.
///   다크 모드 팔레트는 아직 정해진 바가 없어 별도 확정이 필요하다.
enum DadariColor {
    /// 화면 배경 `--bg`
    static let background = Color(hex: 0xFFFFFF)
    /// 카드 배경 `--card`
    static let card = Color(hex: 0xF7F6FB)
    /// 본문 텍스트 `--ink`
    static let ink = Color(hex: 0x1C1C1E)
    /// 보조 텍스트 `--ink-soft`
    static let inkSoft = Color(hex: 0x8A8A93)
    /// 구분선 `--line`
    static let line = Color(hex: 0xECECF3)

    /// 주 포인트 (버튼, 문페이즈, 워드마크) `--accent`
    static let accent = Color(hex: 0x7B82D9)
    /// 주 포인트 텍스트용 `--accent-deep`
    static let accentDeep = Color(hex: 0x5A61B8)
    /// 주 포인트 옅은 배경용 `--accent-soft`
    static let accentSoft = Color(hex: 0xEDEEFB)

    /// 보조 포인트 `--accent2`
    static let accent2 = Color(hex: 0xFF9F73)
    /// 보조 포인트 텍스트용 `--accent2-deep`
    static let accent2Deep = Color(hex: 0xE67E4F)
    /// 보조 포인트 옅은 배경용 `--accent2-soft`
    static let accent2Soft = Color(hex: 0xFFEFE6)

    /// 그룹 제목과 캡션에 쓰는 회색 (목업의 `#68686F`)
    static let inkMuted = Color(hex: 0x68686F)
}

extension Color {
    /// `0xRRGGBB` 형태의 정수로 색을 만든다. 목업의 헥사값을 그대로 옮겨 적기 위한 것이다.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
