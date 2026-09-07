import Foundation
import UserNotifications

/// 알림 권한 요청을 추상화한다. 테스트에서는 대역으로 갈아끼운다.
///
/// 이 앱은 서버가 없어 원격 알림(APNs)을 쓰지 않는다. 로컬 알림만 쓰므로
/// 권한도 `UNUserNotificationCenter`에서만 받는다(PRD 7.1).
/// 알림 예약 자체는 9주차 작업이고, 여기서는 권한만 다룬다.
protocol NotificationAuthorizing: Sendable {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    /// 권한 시트를 띄우고 허용 여부를 돌려준다.
    /// 한 번 거부되면 다시 호출해도 시트가 뜨지 않으므로, 그때는 설정으로 안내해야 한다.
    @discardableResult
    func requestAuthorization() async throws -> Bool
}

enum NotificationAuthorizationStatus: Equatable, Sendable {
    /// 아직 물어보지 않았다. 요청하면 시스템 시트가 뜬다.
    case notDetermined
    case denied
    case authorized
    /// 임시 허용 등 위 셋에 들지 않는 상태.
    case other

    var isAuthorized: Bool { self == .authorized }
}

struct NotificationAuthorizer: NotificationAuthorizing {
    private var center: UNUserNotificationCenter { .current() }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        default: return .other
        }
    }

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        // PRD 7.1이 정한 옵션. 알림, 소리, 배지.
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}
