import Foundation

/// HealthKit 쓰기의 추상화. 테스트에서는 스파이로 갈아끼운다.
///
/// 읽기는 Phase 2다(PRD 4.2). 지금은 기록을 내보내기만 한다.
protocol HealthKitWriting {
    /// 이 기기에서 HealthKit을 쓸 수 있는지. 시뮬레이터/일부 기기에서는 false다.
    var isAvailable: Bool { get }

    /// 쓰기 권한을 요청한다. 사용자가 거부해도 HealthKit은 그 사실을 알려주지 않는다.
    func requestAuthorization() async throws

    /// 기록 1건을 HealthKit에 저장한다. 같은 기록을 다시 저장하면 이전 샘플을 대체한다.
    func save(_ record: PeriodRecordSnapshot) async throws

    /// 앱에서 지운 기록을 HealthKit에서도 지운다.
    func delete(_ record: PeriodRecordSnapshot) async throws
}

enum HealthKitError: LocalizedError, Equatable {
    /// 시뮬레이터 등 HealthKit 자체를 쓸 수 없는 환경.
    case unavailable
    /// 권한 요청이 거부되거나 실패한 경우.
    case authorizationFailed
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "이 기기에서는 건강 앱 연동을 쓸 수 없어요."
        case .authorizationFailed:
            return "건강 앱 권한을 확인해 주세요. 설정 > 개인정보 보호 및 보안 > 건강에서 바꿀 수 있어요."
        case .saveFailed(let reason):
            return "건강 앱에 저장하지 못했어요. (\(reason))"
        case .deleteFailed(let reason):
            return "건강 앱에서 삭제하지 못했어요. (\(reason))"
        }
    }
}
