import Foundation

/// 생리량. PRD 4.1의 경/중/다량에 대응한다.
///
/// SwiftData 모델에는 이 타입을 직접 저장하지 않고 `rawValue`(String)로 저장한다.
/// CloudKit은 스칼라 타입만 안전하게 다루고, 나중에 케이스를 추가하거나 이름을 바꿀 때
/// 원시값 매핑이 명시적으로 남아 있는 편이 마이그레이션이 쉽다.
enum FlowLevel: String, Codable, CaseIterable, Sendable {
    case light
    case medium
    case heavy

    var label: String {
        switch self {
        case .light: return "적음"
        case .medium: return "보통"
        case .heavy: return "많음"
        }
    }
}

/// 기록이 어디서 들어왔는지. 잠금화면이 주 입력 경로라 출처를 남겨둔다(PRD 6번).
enum RecordSource: String, Codable, CaseIterable, Sendable {
    case lockScreen
    case app

    var label: String {
        switch self {
        case .lockScreen: return "잠금화면"
        case .app: return "앱"
        }
    }
}
