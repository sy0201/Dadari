import Foundation
import Observation
import WidgetKit

/// 설정 화면 상태. PRD 5.4(평균 주기 수동 조정, 알림, HealthKit 토글)와
/// UX-설계 7번의 설정값 목록을 다룬다.
@Observable
final class SettingsViewModel {
    private(set) var settings = CycleSettingsSnapshot()
    private(set) var notificationStatus: NotificationAuthorizationStatus = .notDetermined
    private(set) var healthKitStatus: HealthKitShareAuthorization = .notDetermined
    private(set) var isHealthKitAvailable = false

    var message: String?

    private let calendar: Calendar
    private let notifications: NotificationAuthorizing
    private var store: PeriodRecordStore { DadariEnvironment.recordStore }

    let cycleLengthRange = 21...45
    let periodLengthRange = 2...10
    /// 알림을 보낼 수 있는 시점. PRD 4.1의 D-3, D-1.
    let selectableDaysBefore = [3, 1]

    init(
        calendar: Calendar = .current,
        notifications: NotificationAuthorizing = NotificationAuthorizer()
    ) {
        self.calendar = calendar
        self.notifications = notifications
    }

    func reload() async {
        settings = (try? store.settings()) ?? CycleSettingsSnapshot()
        notificationStatus = await notifications.authorizationStatus()

        let coordinator = DadariEnvironment.makeHealthKitCoordinator()
        isHealthKitAvailable = coordinator.isHealthKitAvailable
        healthKitStatus = coordinator.shareAuthorization
    }

    // MARK: - 주기

    func updateLastPeriodStartDate(_ date: Date, now: Date = Date()) {
        guard calendar.startOfDay(for: date) <= calendar.startOfDay(for: now) else {
            message = PeriodRecordError.futureDate.errorDescription
            return
        }
        apply { $0.lastPeriodStartDate = self.calendar.startOfDay(for: date) }
    }

    func updateCycleLength(_ value: Int) {
        apply { $0.estimatedCycleLength = value }
    }

    func updatePeriodLength(_ value: Int) {
        apply { $0.estimatedPeriodLength = value }
    }

    // MARK: - 알림

    /// 알림 예약 자체는 9주차 작업이다. 여기서는 설정값만 저장한다.
    ///
    /// 권한 상태는 캐시된 값이 아니라 **이 시점에 다시 조회한다.** 사용자가 앱을 백그라운드에
    /// 두고 시스템 설정에서 권한을 바꿨을 수 있어서, 화면을 열 때 읽은 값은 이미 낡았을 수 있다.
    /// 낡은 값으로 판단하면 이미 거부된 상태인데 시트를 띄우려 헛호출하게 된다.
    func setNotificationEnabled(_ enabled: Bool) async {
        if enabled {
            let current = await notifications.authorizationStatus()
            if current == .notDetermined {
                _ = try? await notifications.requestAuthorization()
            }
            notificationStatus = await notifications.authorizationStatus()
        }
        // apply가 재예약까지 하므로 여기서 따로 부르지 않는다.
        apply { $0.notificationEnabled = enabled }
    }

    func isDayBeforeSelected(_ days: Int) -> Bool {
        settings.notificationDaysBefore.contains(days)
    }

    func toggleDayBefore(_ days: Int) {
        var selected = Set(settings.notificationDaysBefore)
        if selected.contains(days) {
            selected.remove(days)
        } else {
            selected.insert(days)
        }
        // 큰 수(먼 시점)부터 정렬해 D-3, D-1 순으로 보이게 한다.
        apply { $0.notificationDaysBefore = selected.sorted(by: >) }
    }

    // MARK: - HealthKit

    func setHealthKitEnabled(_ enabled: Bool) async {
        let coordinator = DadariEnvironment.makeHealthKitCoordinator()

        guard enabled else {
            try? coordinator.disableSync()
            await reload()
            return
        }

        do {
            let summary = try await coordinator.enableAndSync()
            if let reason = summary.lastErrorDescription {
                message = reason
            }
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        await reload()
    }

    // MARK: - Private

    /// 설정을 저장하고 화면과 위젯을 갱신한다.
    private func apply(_ mutate: @escaping (CycleSettings) -> Void) {
        do {
            settings = try store.updateSettings(mutate)
            // 주기 설정이 바뀌면 예측이 달라지므로 위젯도 다시 그리고 알림도 다시 잡는다.
            WidgetCenter.shared.reloadAllTimelines()
            Task { await DadariEnvironment.rescheduleReminders() }
        } catch {
            message = error.localizedDescription
        }
    }
}
