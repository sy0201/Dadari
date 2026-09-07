import Foundation
import SwiftData

/// 하루치 컨디션 기록. UX-설계 6번의 "컨디션 기록 바텀시트"가 저장하는 대상이다.
///
/// `PeriodRecord.symptomTags`가 아니라 별도 모델로 둔 이유는 **생리 기간 밖의 날에도
/// 남길 수 있어야 하기 때문이다.** 앱이 캘린더에 PMS를 표시하는데 그 날 컨디션을 못 남기면
/// 앞뒤가 맞지 않는다. 기록에 붙이면 기간 전체가 태그 하나를 공유하게 되는 문제도 있다.
///
/// CloudKit 대응 규칙은 `PeriodRecord`와 같다. 모든 속성이 옵셔널이거나 기본값을 갖고,
/// `@Attribute(.unique)`를 쓰지 않는다. 하루 한 건이라는 제약은 저장소가 보장한다.
@Model
final class DailyCondition {
    var id: UUID = UUID()

    /// 자정으로 정규화된 날짜. 하루 한 건 판정의 기준이다.
    var day: Date = Date.distantPast

    /// `Symptom.rawValue` 목록. 직접 읽고 쓰지 말고 `symptoms`를 쓴다.
    var symptomRawValues: [String]?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        day: Date,
        symptoms: Set<Symptom> = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.day = day
        self.symptomRawValues = Self.rawValues(from: symptoms)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 알 수 없는 원시값은 버린다. CloudKit으로 신버전이 쓴 태그를 구버전이 읽는 상황 대비.
    var symptoms: Set<Symptom> {
        get { Set((symptomRawValues ?? []).compactMap(Symptom.init(rawValue:))) }
        set { symptomRawValues = Self.rawValues(from: newValue) }
    }

    /// 저장 순서를 고정해 두면 비교와 테스트가 쉬워진다.
    private static func rawValues(from symptoms: Set<Symptom>) -> [String] {
        Symptom.allCases.filter(symptoms.contains).map(\.rawValue)
    }
}

/// 값 타입 스냅샷. 화면과 테스트는 이것만 다룬다.
struct DailyConditionSnapshot: Identifiable, Equatable, Sendable {
    var id: UUID
    var day: Date
    var symptoms: Set<Symptom>

    init(id: UUID = UUID(), day: Date, symptoms: Set<Symptom> = []) {
        self.id = id
        self.day = day
        self.symptoms = symptoms
    }

    /// 고른 순서와 무관하게 항상 같은 순서로 보여주기 위한 정렬.
    var orderedSymptoms: [Symptom] {
        Symptom.allCases.filter(symptoms.contains)
    }
}

extension DailyCondition {
    var snapshot: DailyConditionSnapshot {
        DailyConditionSnapshot(id: id, day: day, symptoms: symptoms)
    }
}
