import Foundation
import SwiftData

/// 온보딩 입력값과 설정값. PRD 6.1 / UX-설계 7번.
///
/// 저장소에 항상 한 건만 존재한다. CloudKit이 유니크 제약을 지원하지 않으므로
/// 단일성은 `PeriodRecordStore`가 보장한다(없으면 만들고, 여러 건이면 가장 최근 것을 쓴다).
@Model
final class CycleSettings {
    /// 온보딩에서 받는 마지막 생리 시작일. 첫 예측의 기준점이다.
    var lastPeriodStartDate: Date?

    /// 기록이 2건 미만일 때 예측에 쓰는 추정 주기 길이(PRD 6.2).
    var estimatedCycleLength: Int = CycleDefaults.cycleLength

    var estimatedPeriodLength: Int = CycleDefaults.periodLength

    var notificationEnabled: Bool = true

    /// 예정일 기준 며칠 전에 알릴지. PRD 4.1의 D-3, D-1.
    var notificationDaysBefore: [Int] = CycleDefaults.notificationDaysBefore

    var healthKitSyncEnabled: Bool = false

    var updatedAt: Date = Date()

    init(
        lastPeriodStartDate: Date? = nil,
        estimatedCycleLength: Int = CycleDefaults.cycleLength,
        estimatedPeriodLength: Int = CycleDefaults.periodLength,
        notificationEnabled: Bool = true,
        notificationDaysBefore: [Int] = CycleDefaults.notificationDaysBefore,
        healthKitSyncEnabled: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.lastPeriodStartDate = lastPeriodStartDate
        self.estimatedCycleLength = estimatedCycleLength
        self.estimatedPeriodLength = estimatedPeriodLength
        self.notificationEnabled = notificationEnabled
        self.notificationDaysBefore = notificationDaysBefore
        self.healthKitSyncEnabled = healthKitSyncEnabled
        self.updatedAt = updatedAt
    }
}

/// PRD 6.1의 기본값을 한 곳에 모아둔다.
enum CycleDefaults {
    static let cycleLength = 28
    static let periodLength = 5
    static let notificationDaysBefore = [3, 1]
}
