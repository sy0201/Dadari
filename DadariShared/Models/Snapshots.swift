import Foundation

/// SwiftData 모델을 값 타입으로 떠낸 것.
///
/// `PeriodRecord`는 `ModelContext`에 묶여 있어 스레드를 넘길 수 없고, 테스트에서 쓰려면
/// 매번 컨테이너를 띄워야 한다. 예측 로직과 HealthKit 쓰기는 스냅샷만 받게 해서
/// 저장소 없이도 검증할 수 있게 한다(PRD 7번의 `CyclePredictionService` 분리 원칙).
struct PeriodRecordSnapshot: Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var flow: FlowLevel?
    var symptomTags: [String]?
    var source: RecordSource

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        flow: FlowLevel? = nil,
        symptomTags: [String]? = nil,
        source: RecordSource = .app
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.flow = flow
        self.symptomTags = symptomTags
        self.source = source
    }

    var isOngoing: Bool {
        endDate == nil
    }
}

struct CycleSettingsSnapshot: Equatable, Sendable {
    var lastPeriodStartDate: Date?
    var estimatedCycleLength: Int
    var estimatedPeriodLength: Int
    var notificationEnabled: Bool
    var notificationDaysBefore: [Int]
    var healthKitSyncEnabled: Bool

    init(
        lastPeriodStartDate: Date? = nil,
        estimatedCycleLength: Int = CycleDefaults.cycleLength,
        estimatedPeriodLength: Int = CycleDefaults.periodLength,
        notificationEnabled: Bool = true,
        notificationDaysBefore: [Int] = CycleDefaults.notificationDaysBefore,
        healthKitSyncEnabled: Bool = false
    ) {
        self.lastPeriodStartDate = lastPeriodStartDate
        self.estimatedCycleLength = estimatedCycleLength
        self.estimatedPeriodLength = estimatedPeriodLength
        self.notificationEnabled = notificationEnabled
        self.notificationDaysBefore = notificationDaysBefore
        self.healthKitSyncEnabled = healthKitSyncEnabled
    }
}

extension PeriodRecord {
    var snapshot: PeriodRecordSnapshot {
        PeriodRecordSnapshot(
            id: id,
            startDate: startDate,
            endDate: endDate,
            flow: flow,
            symptomTags: symptomTags,
            source: source
        )
    }
}

extension CycleSettings {
    var snapshot: CycleSettingsSnapshot {
        CycleSettingsSnapshot(
            lastPeriodStartDate: lastPeriodStartDate,
            estimatedCycleLength: estimatedCycleLength,
            estimatedPeriodLength: estimatedPeriodLength,
            notificationEnabled: notificationEnabled,
            notificationDaysBefore: notificationDaysBefore,
            healthKitSyncEnabled: healthKitSyncEnabled
        )
    }
}
