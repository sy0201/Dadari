import Foundation

/// 컨디션 기록에 쓰는 증상 태그.
///
/// PRD 12번은 "Flo, 해피문데이 수준의 무거운 증상 분석은 지양"하고 가볍게 시작하라고 못박고 있다.
/// 그래서 항목을 여덟 개로 제한하고, 정도(강/중/약)나 자유 입력은 두지 않는다.
/// 고르고 끝나는 수준이라 바텀시트에서 몇 초면 남길 수 있다.
///
/// SwiftData에는 이 타입을 직접 저장하지 않고 `rawValue`로 저장한다(다른 열거형과 같은 이유).
enum Symptom: String, Codable, CaseIterable, Sendable, Identifiable {
    case cramps
    case headache
    case backache
    case bloating
    case fatigue
    case moodSwing
    case acne
    case nausea

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cramps: return "복통"
        case .headache: return "두통"
        case .backache: return "허리 통증"
        case .bloating: return "부종"
        case .fatigue: return "피로"
        case .moodSwing: return "예민"
        case .acne: return "여드름"
        case .nausea: return "메스꺼움"
        }
    }
}
