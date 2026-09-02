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
    static func shared() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
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
