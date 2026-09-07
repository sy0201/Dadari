import Foundation
import UserNotifications

/// 알림 예약을 추상화한다. 테스트에서는 대역으로 갈아끼운다.
protocol NotificationScheduling: Sendable {
    /// 주어진 식별자의 대기 중인 알림을 지운다.
    func removePending(identifiers: [String]) async
    /// 알림을 예약한다.
    func schedule(_ reminder: CycleReminder, calendar: Calendar) async throws
    /// 현재 대기 중인 알림 식별자. 디버깅과 검증에 쓴다.
    func pendingIdentifiers() async -> [String]
}

struct NotificationScheduler: NotificationScheduling {
    private var center: UNUserNotificationCenter { .current() }

    func removePending(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func schedule(_ reminder: CycleReminder, calendar: Calendar) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.userInfo = reminder.userInfo

        // 날짜와 시각이 맞을 때 한 번만 울린다. 반복하지 않는다.
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        try await center.add(
            UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: trigger
            )
        )
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }
}
