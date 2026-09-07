import SwiftUI

@main
struct DadariApp: App {
    /// 로컬 알림 딜리게이트를 받기 위한 최소한의 얹기(CLAUDE.md 원칙 2).
    @UIApplicationDelegateAdaptor(DadariAppDelegate.self) private var appDelegate

    init() {
        #if DEBUG
        SampleDataSeeder.seedIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
