import Foundation

/// 예정일 알림을 예약한다. PRD 7.1의 규칙을 그대로 옮긴 것.
///
/// 예측은 기록이 바뀔 때마다 달라지므로, 예약할 때는 **항상 기존 예약을 먼저 지우고**
/// 새로 계산된 날짜로 다시 넣는다. 그렇게 하지 않으면 날짜가 틀린 알림이 남는다.
struct CycleReminderService {
    struct Configuration: Equatable, Sendable {
        /// 알림이 울릴 시각.
        ///
        /// PRD와 UX-설계는 며칠 전에 보낼지(D-3, D-1)만 정하고 시각은 정하지 않았다.
        /// 아침에 받아 보는 게 자연스러워 오전 9시로 뒀다. 사용자가 고르게 하려면
        /// 설정에 항목을 하나 더 두고 이 값을 바꾸면 된다.
        var hour = 9
        var minute = 0

        init() {}
    }

    /// 이 접두어로 시작하는 알림은 전부 이 서비스가 관리한다.
    /// 설정에서 D-3을 껐을 때 예전에 넣어둔 예약까지 지우려면 접두어로 훑어야 한다.
    static let identifierPrefix = "period-reminder-"

    /// 예약을 건너뛴 이유. 화면과 로그에서 원인을 구분하는 데 쓴다.
    enum SkipReason: Error, Equatable, Sendable {
        case disabledInSettings
        case notAuthorized
        /// 기준으로 삼을 예측이 없다.
        case noPrediction
        /// 예정일이 한참 지나 카운트다운을 멈춘 상태다(PRD 4.1 안전장치).
        case predictionStale
        /// 계산된 알림 시각이 전부 과거다.
        case allDatesInPast
    }

    struct Summary: Equatable, Sendable {
        var removed: [String] = []
        var scheduled: [String] = []
        var skipReason: SkipReason?
    }

    var configuration = Configuration()
    var calendar: Calendar

    private let store: PeriodRecordStore
    private let scheduler: NotificationScheduling
    private let authorizer: NotificationAuthorizing
    private let predictionService: CyclePredictionService

    init(
        store: PeriodRecordStore,
        scheduler: NotificationScheduling,
        authorizer: NotificationAuthorizing,
        calendar: Calendar = .current,
        configuration: Configuration = Configuration()
    ) {
        self.store = store
        self.scheduler = scheduler
        self.authorizer = authorizer
        self.calendar = calendar
        self.configuration = configuration
        self.predictionService = CyclePredictionService(calendar: calendar)
    }

    // MARK: - 계산 (저장소도 알림 센터도 모른다)

    /// 예측과 설정으로 예약할 알림 목록을 만든다.
    ///
    /// 건너뛰는 경우:
    /// - 설정에서 알림을 껐을 때
    /// - 예측이 없을 때
    /// - 예정일이 한참 지나 예측을 멈춘 상태일 때. 빗나간 예측으로 알림까지 보내면
    ///   틀린 숫자를 보여주지 않겠다는 안전장치(PRD 4.1)가 무의미해진다
    /// - 계산된 시각이 이미 지났을 때
    func reminders(
        prediction: CyclePrediction?,
        settings: CycleSettingsSnapshot,
        now: Date
    ) -> Result<[CycleReminder], SkipReason> {
        guard settings.notificationEnabled else { return .failure(.disabledInSettings) }
        guard let prediction else { return .failure(.noPrediction) }
        if case .stale = prediction.status { return .failure(.predictionStale) }

        let daysBeforeValues = Set(settings.notificationDaysBefore).filter { $0 > 0 }.sorted(by: >)

        let reminders = daysBeforeValues.compactMap { days -> CycleReminder? in
            guard let fireDate = fireDate(daysBefore: days, from: prediction.nextPeriodStartDate),
                  fireDate > now else {
                return nil
            }
            return CycleReminder(
                daysBefore: days,
                fireDate: fireDate,
                title: CycleReminderText.title(daysBefore: days),
                body: CycleReminderText.body(daysBefore: days)
            )
        }

        return reminders.isEmpty ? .failure(.allDatesInPast) : .success(reminders)
    }

    private func fireDate(daysBefore: Int, from periodStart: Date) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: periodStart) else {
            return nil
        }
        return calendar.date(
            bySettingHour: configuration.hour,
            minute: configuration.minute,
            second: 0,
            of: day
        )
    }

    // MARK: - 예약

    /// 기존 예약을 지우고 새로 계산한 알림을 넣는다.
    ///
    /// 건너뛰는 경우에도 **지우는 것은 먼저 한다.** 설정에서 알림을 끄거나 권한이
    /// 거부됐는데 예전 예약이 남아 울리면 안 되기 때문이다.
    @discardableResult
    func reschedule(now: Date = Date()) async -> Summary {
        var summary = Summary()
        // 건너뛴 경로에서도 결과가 남아야 한다. 조기 반환마다 로그를 넣으면 빠뜨리기 쉽다.
        defer {
            DadariLog.store.notice("""
                알림 재예약 지움=\(summary.removed.count, privacy: .public) \
                예약=\(summary.scheduled.count, privacy: .public) \
                건너뜀=\(summary.skipReason.map { String(describing: $0) } ?? "없음", privacy: .public)
                """)
        }

        let pending = await scheduler.pendingIdentifiers()
        let stale = pending.filter { $0.hasPrefix(Self.identifierPrefix) }
        if !stale.isEmpty {
            await scheduler.removePending(identifiers: stale)
            summary.removed = stale
        }

        guard await authorizer.authorizationStatus().isAuthorized else {
            summary.skipReason = .notAuthorized
            return summary
        }

        let settings = (try? store.settings()) ?? CycleSettingsSnapshot()
        let records = (try? store.recordsOldestFirst()) ?? []
        let prediction = predictionService.predict(records: records, settings: settings, now: now)

        switch reminders(prediction: prediction, settings: settings, now: now) {
        case .failure(let reason):
            summary.skipReason = reason
        case .success(let reminders):
            for reminder in reminders {
                do {
                    try await scheduler.schedule(reminder, calendar: calendar)
                    summary.scheduled.append(reminder.identifier)
                } catch {
                    DadariLog.store.error(
                        "알림 예약 실패 \(reminder.identifier, privacy: .public): \(String(describing: error), privacy: .public)"
                    )
                }
            }
        }

        return summary
    }
}
