import SwiftUI

@main
struct DadariApp: App {
    init() {
        #if DEBUG
        SampleDataSeeder.seedIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
