import Foundation

/// HealthKit 쓰기의 추상화. 테스트에서는 스파이로 갈아끼운다.
///
/// 읽기는 Phase 2다(PRD 4.2). 지금은 기록을 내보내기만 한다.
protocol HealthKitWriting {
    /// 이 기기에서 HealthKit을 쓸 수 있는지. 시뮬레이터/일부 기기에서는 false다.
    var isAvailable: Bool { get }

    /// 현재 쓰기 권한 상태.
    ///
    /// 읽기 권한과 달리 **쓰기 권한은 상태를 그대로 조회할 수 있다.**
    /// 읽기는 "거부됨"을 알려주면 그 자체로 건강 정보가 새기 때문에 감추지만,
    /// 쓰기는 그런 문제가 없어서 애플이 실제 상태를 준다.
    var shareAuthorization: HealthKitShareAuthorization { get }

    /// 쓰기 권한을 요청한다.
    ///
    /// - Important: 사용자가 거부해도 이 호출은 성공으로 돌아온다. 그러니 이 함수가
    ///   던지지 않았다는 것만으로 권한을 받았다고 판단하면 안 된다.
    ///   요청 뒤에 `shareAuthorization`을 확인해야 한다.
    ///   한 번 거부되면 다시 호출해도 시스템 시트가 뜨지 않으므로, 사용자를 설정으로 안내해야 한다.
    func requestAuthorization() async throws

    /// 기록 1건을 HealthKit에 저장한다. 같은 기록을 다시 저장하면 이전 샘플을 대체한다.
    func save(_ record: PeriodRecordSnapshot) async throws

    /// 앱에서 지운 기록을 HealthKit에서도 지운다.
    func delete(_ record: PeriodRecordSnapshot) async throws
}

/// 쓰기 권한 상태.
enum HealthKitShareAuthorization: Equatable, Sendable {
    /// 아직 물어보지 않았다. 요청하면 시스템 시트가 뜬다.
    case notDetermined
    /// 사용자가 거부했다. 다시 요청해도 시트가 뜨지 않으므로 설정으로 안내해야 한다.
    case denied
    case authorized
}

enum HealthKitError: LocalizedError, Equatable {
    /// 시뮬레이터 등 HealthKit 자체를 쓸 수 없는 환경.
    case unavailable
    /// 권한 요청 호출 자체가 실패한 경우.
    case authorizationFailed
    /// 사용자가 쓰기 권한을 거부한 경우. 앱에서 다시 물어볼 수 없다.
    case sharingDenied
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "이 기기에서는 건강 앱 연동을 쓸 수 없어요."
        case .authorizationFailed:
            return "건강 앱 권한을 요청하지 못했어요. 잠시 후 다시 시도해 주세요."
        case .sharingDenied:
            return """
                건강 앱 쓰기 권한이 꺼져 있어요. 앱에서는 다시 물어볼 수 없어서 직접 켜주셔야 해요.
                건강 앱 > 우측 상단 프로필 > 앱 및 서비스 > 다달이 에서 '월경'을 켜주세요.
                """
        case .saveFailed(let reason):
            return "건강 앱에 저장하지 못했어요. (\(reason))"
        case .deleteFailed(let reason):
            return "건강 앱에서 삭제하지 못했어요. (\(reason))"
        }
    }
}
