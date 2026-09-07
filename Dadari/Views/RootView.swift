import SwiftUI

/// 앱의 첫 화면을 고른다. 온보딩을 마치지 않았으면 온보딩부터 띄운다(UX-설계 5번).
struct RootView: View {
    /// nil이면 아직 저장소를 읽기 전이다. 그 사이에 홈이 잠깐 보였다 사라지는 걸 막는다.
    @State private var hasCompletedOnboarding: Bool?

    var body: some View {
        Group {
            switch hasCompletedOnboarding {
            case true:
                HomeView()
            case false:
                OnboardingView { hasCompletedOnboarding = true }
            case nil:
                DadariColor.background.ignoresSafeArea()
            }
        }
        .onAppear(perform: resolveInitialScreen)
    }

    private func resolveInitialScreen() {
        guard hasCompletedOnboarding == nil else { return }

        #if DEBUG
        if CommandLine.arguments.contains("-showOnboarding") {
            hasCompletedOnboarding = false
            return
        }
        #endif

        let settings = try? DadariEnvironment.recordStore.settings()
        hasCompletedOnboarding = settings?.hasCompletedOnboarding ?? false
    }
}
