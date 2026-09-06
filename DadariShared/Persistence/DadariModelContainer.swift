import Foundation
import SwiftData

/// 앱과 위젯 익스텐션이 함께 여는 SwiftData 컨테이너.
///
/// 스토어 파일이 App Group 컨테이너 안에 있어야 두 프로세스가 같은 데이터를 본다.
/// 1주차 스파이크에서 검증한 App Group 공유 구조를 그대로 SwiftData로 옮긴 것이다.
enum DadariModelContainer {
    static let schema = Schema([
        PeriodRecord.self,
        CycleSettings.self,
    ])

    /// App Group 컨테이너에 저장하는 공용 컨테이너.
    ///
    /// CloudKit은 아직 켜지 않는다(PRD 8번). 모델이 제약을 지키고 있으므로
    /// v1.1에서 `cloudKitDatabase: .private("iCloud.com.dadari.app")`만 추가하면 된다.
    ///
    /// - Important: SwiftData는 App Group 엔타이틀먼트가 없으면 오류를 던지는 게 아니라
    ///   `fatalError`로 프로세스를 죽인다. `try`로는 잡을 수 없으므로 만들기 전에 직접 확인한다.
    ///   1주차에 Xcode가 엔타이틀먼트를 비워버린 적이 있어(SPIKE.md) 실제로 일어나는 상황이다.
    static func shared() throws -> ModelContainer {
        guard AppGroup.isAvailable else {
            throw DadariModelContainerError.appGroupUnavailable
        }
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// App Group을 잡지 못했을 때 쓰는 앱 자체 컨테이너.
    ///
    /// 위젯과 데이터가 갈리지만, 최소한 앱을 껐다 켜도 기록이 남는다.
    /// 인메모리로 떨어뜨리면 사용자가 남긴 기록이 그대로 사라지기 때문에 디스크를 쓴다.
    static func localFallback() throws -> ModelContainer {
        // 갓 설치한 앱에는 Application Support 디렉터리가 아직 없다. 그대로 열면
        // "Failed to stat path ... No such file or directory"로 실패한다.
        // create: true로 디렉터리를 먼저 만들어 둔다.
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let configuration = ModelConfiguration(
            "DadariLocalFallback",
            schema: schema,
            url: directory.appendingPathComponent("DadariLocalFallback.store"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// 테스트와 프리뷰용. 디스크를 건드리지 않는다.
    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

enum DadariModelContainerError: LocalizedError, Equatable {
    /// App Group 엔타이틀먼트가 없거나 프로비저닝 프로파일에 빠져 있는 경우.
    case appGroupUnavailable

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "App Group(\(AppGroup.identifier))을 찾을 수 없어요. 엔타이틀먼트를 확인해 주세요."
        }
    }
}
