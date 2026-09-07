import Foundation
@testable import Dadari

/// 알림 예약을 가로채는 테스트용 대역.
/// 실제 `UNUserNotificationCenter`는 권한과 시스템 상태에 묶여 있어 테스트에서 쓰지 않는다.
final class NotificationSchedulerSpy: NotificationScheduling, @unchecked Sendable {
    private(set) var scheduled: [CycleReminder] = []
    private(set) var removedIdentifiers: [[String]] = []

    /// 이미 대기 중인 것으로 볼 식별자. 재예약이 기존 것을 지우는지 확인할 때 쓴다.
    var pending: [String] = []
    var scheduleError: Error?

    func removePending(identifiers: [String]) async {
        removedIdentifiers.append(identifiers)
        pending.removeAll { identifiers.contains($0) }
    }

    func schedule(_ reminder: CycleReminder, calendar: Calendar) async throws {
        if let scheduleError { throw scheduleError }
        scheduled.append(reminder)
        pending.append(reminder.identifier)
    }

    func pendingIdentifiers() async -> [String] {
        pending
    }
}
