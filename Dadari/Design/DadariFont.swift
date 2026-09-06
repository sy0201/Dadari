import SwiftUI

/// 타이포그래피. PRD 3.4와 목업 기준.
///
/// - 본문/UI: 시스템 폰트(SF Pro). 목업의 Pretendard는 웹용 대체 폰트이고,
///   실제 iOS 빌드에서는 시스템 폰트를 쓴다고 PRD 3.4에 명시돼 있다.
/// - 워드마크와 큰 숫자: 고운바탕(Gowun Batang, OFL-1.1).
///
/// 고운바탕은 앱에서 실제로 쓰는 글자만 남겨 서브셋한 파일을 번들에 넣는다
/// (`Scripts/subset_fonts.py`). 원본은 두 벌 합쳐 16MB라 그대로 넣기엔 과하다.
/// 고운바탕으로 새 문구를 표시하려면 스크립트의 글자 목록을 갱신해야 한다.
///
/// 위젯 익스텐션에는 폰트를 넣지 않았다. 잠금화면 위젯은 단색으로 렌더링되고
/// 크기도 작아서 세리프가 가독성을 해치기 때문에 시스템 폰트를 그대로 쓴다.
enum DadariFont {
    private static let serifRegular = "GowunBatang-Regular"
    private static let serifBold = "GowunBatang-Bold"

    /// 워드마크 "다달이". 목업 기준 16pt Bold.
    static func wordmark(size: CGFloat = 16) -> Font {
        .custom(serifBold, size: size)
    }

    /// 월 레이블("2026년 8월") 등 세리프로 표시하는 짧은 문구. 목업 기준 13.5pt.
    static func serif(size: CGFloat) -> Font {
        .custom(serifRegular, size: size)
    }

    static func serifBold(size: CGFloat) -> Font {
        .custom(serifBold, size: size)
    }
}
