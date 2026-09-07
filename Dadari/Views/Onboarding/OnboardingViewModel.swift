import Foundation
import Observation

/// 온보딩 단계. UX-설계 5번의 "온보딩 → 권한 프리퍼미션 → 홈" 순서를 그대로 따른다.
enum OnboardingStep: Int, CaseIterable {
    /// 앱 소개 1장.
    case intro
    /// 마지막 생리 시작일과 주기 추정값(PRD 6.1).
    case cycleInput
    /// 알림 권한을 요청하기 전에 이유를 설명한다.
    case notificationPermission
    /// HealthKit 권한을 요청하기 전에 이유를 설명한다.
    case healthKitPermission
}

@Observable
final class OnboardingViewModel {
    var step: OnboardingStep = .intro

    /// PRD 6.1의 온보딩 입력값.
    var lastPeriodStartDate: Date
    var cycleLength = CycleDefaults.cycleLength
    var periodLength = CycleDefaults.periodLength

    private(set) var notificationStatus: NotificationAuthorizationStatus = .notDetermined
    private(set) var healthKitStatus: HealthKitShareAuthorization = .notDetermined
    private(set) var isRequestingPermission = false

    var message: String?

    private let calendar: Calendar
    private let notifications: NotificationAuthorizing
    private var store: PeriodRecordStore { DadariEnvironment.recordStore }

    /// 주기 길이를 고를 수 있는 범위. 예측이 이상치로 걸러내는 구간과 같다(PRD 6.2).
    let cycleLengthRange = 21...45
    let periodLengthRange = 2...10

    init(
        calendar: Calendar = .current,
        notifications: NotificationAuthorizing = NotificationAuthorizer()
    ) {
        self.calendar = calendar
        self.notifications = notifications
        self.lastPeriodStartDate = calendar.startOfDay(for: Date())
    }

    // MARK: - 단계 이동

    func advance() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    var isLastStep: Bool {
        step == OnboardingStep.allCases.last
    }

    // MARK: - 권한

    func refreshPermissionStatuses() async {
        notificationStatus = await notifications.authorizationStatus()
        healthKitStatus = DadariEnvironment.makeHealthKitCoordinator().shareAuthorization
    }

    /// 알림 권한을 요청한다. 거부돼도 온보딩은 계속 진행한다.
    func requestNotificationPermission() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        do {
            _ = try await notifications.requestAuthorization()
        } catch {
            DadariLog.store.error("알림 권한 요청 실패: \(String(describing: error), privacy: .public)")
        }
        notificationStatus = await notifications.authorizationStatus()
    }

    /// HealthKit 쓰기 권한을 요청하고 연동을 켠다.
    ///
    /// 거부돼도 온보딩을 막지 않는다. 연동은 나중에 설정에서 다시 켤 수 있다.
    func requestHealthKitPermission() async {
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let coordinator = DadariEnvironment.makeHealthKitCoordinator()
        guard coordinator.isHealthKitAvailable else {
            healthKitStatus = coordinator.shareAuthorization
            message = HealthKitError.unavailable.errorDescription
            return
        }

        do {
            _ = try await coordinator.enableAndSync()
        } catch {
            // 거부는 오류가 아니라 선택이다. 문구만 남기고 넘어간다.
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        healthKitStatus = coordinator.shareAuthorization
    }

    // MARK: - 완료

    /// 입력값을 저장하고 온보딩을 마친 것으로 표시한다.
    @discardableResult
    func complete(now: Date = Date()) -> Bool {
        do {
            try store.updateSettings({ settings in
                settings.lastPeriodStartDate = calendar.startOfDay(for: lastPeriodStartDate)
                settings.estimatedCycleLength = cycleLength
                settings.estimatedPeriodLength = periodLength
                settings.onboardingCompletedAt = now
            }, now: now)
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    /// 마지막 생리 시작일은 미래일 수 없다.
    func isLastPeriodStartDateValid(now: Date = Date()) -> Bool {
        calendar.startOfDay(for: lastPeriodStartDate) <= calendar.startOfDay(for: now)
    }
}
