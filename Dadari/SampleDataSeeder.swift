import Foundation
import UIKit

#if DEBUG
/// 개발 중 화면을 눈으로 확인하기 위한 시드 데이터.
///
/// 실행 인자에 `-seedSampleData`를 넣고 실행하면 기존 기록을 지우고
/// 목업(ui-mockup.html)이 쓴 예시 데이터를 넣는다. 릴리스 빌드에는 포함되지 않는다.
///
///     xcrun simctl launch <udid> com.dadari.app -seedSampleData
enum SampleDataSeeder {
    static let launchArgument = "-seedSampleData"

    static func seedIfRequested() {
        logFontAvailability()
        guard CommandLine.arguments.contains(launchArgument) else { return }
        seed()
    }

    /// 번들 폰트가 실제로 등록됐는지 확인한다. 등록에 실패하면 조용히 시스템 폰트로 대체돼
    /// 눈으로는 알아채기 어렵다.
    static func logFontAvailability() {
        guard UIFont.fontNames(forFamilyName: "Gowun Batang").isEmpty else { return }
        DadariLog.store.error("고운바탕이 등록되지 않았다. UIAppFonts와 번들 리소스를 확인할 것.")
    }

    /// 28일 주기 3회를 넣는다. 마지막 시작일을 오늘로부터 13일 전에 두어
    /// 오늘이 주기 14일차(보름)가 되게 한다. 문페이즈와 가임기 표시를 한 화면에서 볼 수 있다.
    private static func seed() {
        let store = DadariEnvironment.recordStore
        let calendar = Calendar.current
        let anchor = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: Date()))!

        for record in (try? store.records()) ?? [] {
            try? store.delete(id: record.id)
        }

        let starts = [-56, -28, 0].compactMap { calendar.date(byAdding: .day, value: $0, to: anchor) }
        for start in starts {
            guard let end = calendar.date(byAdding: .day, value: 4, to: start) else { continue }
            let now = Date()
            _ = try? store.recordPeriodStart(on: start, now: now, source: .app, flow: .medium)
            _ = try? store.recordPeriodEnd(on: end, now: now, source: .app)
        }

        _ = try? store.updateSettings {
            $0.lastPeriodStartDate = anchor
            $0.estimatedCycleLength = 28
            $0.estimatedPeriodLength = 5
        }

        DadariLog.store.notice("시드 데이터 주입 완료")
    }
}
#endif
