import Foundation
import SwiftData

/// 생리 주기 기록 1건. PRD 6번의 데이터 모델.
///
/// ## CloudKit 대응 규칙 (PRD 6.3 / CLAUDE.md 원칙 5)
/// 지금은 CloudKit을 켜지 않지만, v1.1에서 `ModelConfiguration(cloudKitDatabase:)` 한 줄로
/// 동기화를 켤 수 있도록 아래 제약을 미리 지킨다. 하나라도 어기면 CloudKit을 켜는 순간
/// 스토어가 열리지 않거나 스키마 마이그레이션이 필요해진다.
///
/// - 모든 속성은 옵셔널이거나 기본값을 가진다.
/// - `@Attribute(.unique)`를 쓰지 않는다. (CloudKit이 유니크 제약을 지원하지 않는다)
/// - 관계를 추가하게 되면 옵셔널로 두고 역관계를 명시한다.
/// - enum은 원시값으로 저장하고 계산 프로퍼티로 감싼다.
@Model
final class PeriodRecord {
    /// CloudKit이 유니크 제약을 지원하지 않으므로 `.unique`를 붙이지 않는다.
    /// 중복 방지는 저장소(`PeriodRecordStore`)의 도메인 규칙으로 보장한다.
    var id: UUID = UUID()

    /// 생리 시작일(자정 정규화). 도메인상 필수지만 CloudKit 제약 때문에 기본값을 둔다.
    /// `.distantPast`를 자리표시자로 쓰는 이유는, 값이 비어 들어온 레코드를 조용히
    /// "오늘 기록"으로 오인하지 않고 눈에 띄게 만들기 위해서다.
    var startDate: Date = Date.distantPast

    /// 종료 전까지는 nil. 진행 중인 주기를 찾는 기준이 된다.
    var endDate: Date?

    /// `FlowLevel.rawValue`. 직접 읽고 쓰지 말고 `flow`를 쓴다.
    var flowRawValue: String?

    /// Phase 2에서 사용한다. 지금은 UI가 없지만, 나중에 필드를 추가하며
    /// 마이그레이션하는 일이 없도록 스키마에 미리 넣어둔다(PRD 6번).
    var symptomTags: [String]?

    /// `RecordSource.rawValue`. 직접 읽고 쓰지 말고 `source`를 쓴다.
    var sourceRawValue: String = RecordSource.app.rawValue

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        flow: FlowLevel? = nil,
        symptomTags: [String]? = nil,
        source: RecordSource = .app,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.flowRawValue = flow?.rawValue
        self.symptomTags = symptomTags
        self.sourceRawValue = source.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var flow: FlowLevel? {
        get { flowRawValue.flatMap(FlowLevel.init(rawValue:)) }
        set { flowRawValue = newValue?.rawValue }
    }

    /// 알 수 없는 원시값이 들어오면 `.app`으로 떨어진다.
    /// CloudKit으로 신버전이 쓴 값을 구버전이 읽는 상황을 대비한 것이다.
    var source: RecordSource {
        get { RecordSource(rawValue: sourceRawValue) ?? .app }
        set { sourceRawValue = newValue.rawValue }
    }

    /// 아직 종료일이 기록되지 않은 진행 중인 주기인지.
    var isOngoing: Bool {
        endDate == nil
    }
}
