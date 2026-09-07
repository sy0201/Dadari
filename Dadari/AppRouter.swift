import Observation
import SwiftUI
import UserNotifications

/// 알림 탭 같은 외부 진입으로 이동할 화면을 담아둔다.
/// SwiftUI가 이 값을 관찰하고 있다가 해당 화면으로 보낸다(PRD 7.1).
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    /// 처리해야 할 이동 요청. 화면이 처리하고 나면 nil로 되돌린다.
    var pendingRoute: NotificationRoute?

    private init() {}

    /// `userInfo`에서 뽑아낸 라우트 문자열을 받는다.
    /// 딕셔너리를 그대로 넘기면 Sendable이 아니라 액터 경계를 넘길 수 없다.
    func handle(routeValue: String?) {
        // 라우트를 못 읽어도 앱은 열려야 한다. 그때는 홈으로 보낸다.
        pendingRoute = routeValue.flatMap(NotificationRoute.init(rawValue:)) ?? .home
    }
}

/// 알림 딜리게이트를 받기 위한 최소한의 `UIApplicationDelegate`.
///
/// 이 앱은 화면을 100% SwiftUI로 만들고 UIKit 화면을 두지 않는다(CLAUDE.md 원칙 2).
/// 다만 `UNUserNotificationCenterDelegate`는 앱 델리게이트에 붙여야 해서,
/// `@UIApplicationDelegateAdaptor`로 이만큼만 얹는다.
final class DadariAppDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// 알림을 탭했을 때. `userInfo`의 라우트를 읽어 화면 이동 상태를 바꾼다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let routeValue = response.notification.request.content
            .userInfo[NotificationRoute.key] as? String
        await MainActor.run {
            AppRouter.shared.handle(routeValue: routeValue)
        }
    }

    /// 앱을 보고 있는 중에도 배너를 띄운다. 예정일 알림은 놓치면 의미가 없다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
