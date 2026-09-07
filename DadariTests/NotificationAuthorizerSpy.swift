import Foundation
@testable import Dadari

/// 알림 권한 요청을 가로채는 테스트용 대역.
/// 실제 `UNUserNotificationCenter`는 테스트에서 시스템 시트를 띄우려 하므로 쓰지 않는다.
final class NotificationAuthorizerSpy: NotificationAuthorizing, @unchecked Sendable {
    var status: NotificationAuthorizationStatus = .notDetermined
    /// 요청 시트에서 사용자가 고를 결과.
    var grantsAuthorization = true
    var requestError: Error?

    private(set) var requestCount = 0

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        if let requestError { throw requestError }
        status = grantsAuthorization ? .authorized : .denied
        return grantsAuthorization
    }
}
