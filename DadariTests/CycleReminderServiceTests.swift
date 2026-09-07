import SwiftData
import XCTest
@testable import Dadari

/// 예정일 알림 예약 규칙을 고정한다. PRD 7.1과 4.1이 기준이다.
final class CycleReminderServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var store: PeriodRecordStore!
    private var scheduler: NotificationSchedulerSpy!
    private var authorizer: NotificationAuthorizerSpy!
    private var service: CycleReminderService!

    private let now = TestSupport.date(2026, 9, 7, hour: 10)

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try DadariModelContainer.inMemory()
        store = PeriodRecordStore(container: container, calendar: TestSupport.calendar)
        scheduler = NotificationSchedulerSpy()
        authorizer = NotificationAuthorizerSpy()
        authorizer.status = .authorized
        service = CycleReminderService(
            store: store,
            scheduler: scheduler,
            authorizer: authorizer,
            calendar: TestSupport.calendar
        )
    }

    override func tearDown() {
        service = nil
        authorizer = nil
        scheduler = nil
        store = nil
        container = nil
        super.tearDown()
    }

    /// 예정일이 2026-10-01이 되도록 만든 예측.
    private func prediction(nextStart: Date, status: CyclePrediction.Status? = nil) -> CyclePrediction {
        let calendar = TestSupport.calendar
        let ovulation = calendar.date(byAdding: .day, value: -14, to: nextStart)!
        let fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulation)!
        let fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulation)!
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: nextStart
        ).day ?? 0
        return CyclePrediction(
            referenceStartDate: calendar.date(byAdding: .day, value: -28, to: nextStart)!,
            nextPeriodStartDate: nextStart,
            ovulationDate: ovulation,
            fertileWindow: fertileStart...fertileEnd,
            cycleLengthUsed: 28,
            basis: .history(cycleCount: 3),
            confidence: .high,
            status: status ?? .upcoming(daysRemaining: days)
        )
    }

    private var settings: CycleSettingsSnapshot {
        CycleSettingsSnapshot(notificationEnabled: true, notificationDaysBefore: [3, 1])
    }

    // MARK: - 무엇을 언제 예약하는가

    func test_예정일_3일_전과_1일_전에_예약한다() throws {
        let nextStart = TestSupport.day(2026, 10, 1)

        let reminders = try service.reminders(
            prediction: prediction(nextStart: nextStart),
            settings: settings,
            now: now
        ).get()

        XCTAssertEqual(reminders.map(\.daysBefore), [3, 1])
        XCTAssertEqual(
            reminders.map(\.identifier),
            ["period-reminder-3d", "period-reminder-1d"],
            "PRD 7.1이 정한 식별자"
        )
    }

    func test_알림은_예정일_기준_날짜의_오전_9시에_울린다() throws {
        let nextStart = TestSupport.day(2026, 10, 1)

        let reminders = try service.reminders(
            prediction: prediction(nextStart: nextStart),
            settings: settings,
            now: now
        ).get()

        let calendar = TestSupport.calendar
        let first = try XCTUnwrap(reminders.first)
        XCTAssertEqual(calendar.startOfDay(for: first.fireDate), TestSupport.day(2026, 9, 28))
        XCTAssertEqual(calendar.component(.hour, from: first.fireDate), 9)
    }

    func test_설정에서_고른_시점만_예약한다() throws {
        var custom = settings
        custom.notificationDaysBefore = [1]

        let reminders = try service.reminders(
            prediction: prediction(nextStart: TestSupport.day(2026, 10, 1)),
            settings: custom,
            now: now
        ).get()

        XCTAssertEqual(reminders.map(\.daysBefore), [1])
    }

    func test_이미_지난_시각은_예약하지_않는다() throws {
        // 예정일이 이틀 뒤면 D-3 시각은 이미 지났다.
        let reminders = try service.reminders(
            prediction: prediction(nextStart: TestSupport.day(2026, 9, 9)),
            settings: settings,
            now: now
        ).get()

        XCTAssertEqual(reminders.map(\.daysBefore), [1])
    }

    // MARK: - 예약하지 않는 경우

    func test_설정에서_알림을_끄면_예약하지_않는다() {
        var disabled = settings
        disabled.notificationEnabled = false

        let result = service.reminders(
            prediction: prediction(nextStart: TestSupport.day(2026, 10, 1)),
            settings: disabled,
            now: now
        )

        XCTAssertEqual(result.failureReason, .disabledInSettings)
    }

    func test_예측이_없으면_예약하지_않는다() {
        let result = service.reminders(prediction: nil, settings: settings, now: now)

        XCTAssertEqual(result.failureReason, .noPrediction)
    }

    func test_예측이_멈춘_상태면_예약하지_않는다() {
        // 예정일이 한참 지나 카운트다운을 멈춘 상태(PRD 4.1). 빗나간 예측으로 알림까지
        // 보내면 틀린 숫자를 보여주지 않겠다는 안전장치가 무의미해진다.
        let result = service.reminders(
            prediction: prediction(nextStart: TestSupport.day(2026, 8, 20), status: .stale(daysPast: 18)),
            settings: settings,
            now: now
        )

        XCTAssertEqual(result.failureReason, .predictionStale)
    }

    func test_모든_시각이_지났으면_예약하지_않는다() {
        let result = service.reminders(
            prediction: prediction(nextStart: TestSupport.day(2026, 9, 7)),
            settings: settings,
            now: now
        )

        XCTAssertEqual(result.failureReason, .allDatesInPast)
    }

    // MARK: - 재예약

    func test_재예약은_기존_예약을_먼저_지운다() async throws {
        // 날짜가 틀린 알림이 남지 않도록 항상 지우고 다시 넣는다(PRD 7.1).
        scheduler.pending = ["period-reminder-3d", "period-reminder-1d", "다른-알림"]
        try seedRecordsForPrediction()

        let summary = await service.reschedule(now: now)

        XCTAssertEqual(summary.removed.sorted(), ["period-reminder-1d", "period-reminder-3d"])
        XCTAssertFalse(summary.removed.contains("다른-알림"), "우리 접두어가 아닌 알림은 건드리지 않는다")
    }

    func test_권한이_없으면_기존_예약만_지우고_새로_넣지_않는다() async {
        scheduler.pending = ["period-reminder-3d"]
        authorizer.status = .denied

        let summary = await service.reschedule(now: now)

        XCTAssertEqual(summary.removed, ["period-reminder-3d"])
        XCTAssertTrue(summary.scheduled.isEmpty)
        XCTAssertEqual(summary.skipReason, .notAuthorized)
    }

    func test_설정에서_껐을_때도_기존_예약은_지운다() async throws {
        try seedRecordsForPrediction()
        try store.updateSettings { $0.notificationEnabled = false }
        scheduler.pending = ["period-reminder-3d"]

        let summary = await service.reschedule(now: now)

        XCTAssertEqual(summary.removed, ["period-reminder-3d"])
        XCTAssertEqual(summary.skipReason, .disabledInSettings)
    }

    func test_기록이_있으면_실제로_예약된다() async throws {
        try seedRecordsForPrediction()

        let summary = await service.reschedule(now: now)

        XCTAssertNil(summary.skipReason)
        XCTAssertFalse(summary.scheduled.isEmpty)
        XCTAssertEqual(scheduler.scheduled.count, summary.scheduled.count)
    }

    func test_예약에_실패해도_나머지는_계속_시도한다() async throws {
        try seedRecordsForPrediction()
        struct Boom: Error {}
        scheduler.scheduleError = Boom()

        let summary = await service.reschedule(now: now)

        XCTAssertTrue(summary.scheduled.isEmpty)
        XCTAssertNil(summary.skipReason, "예약 실패는 건너뛴 것과 다르다")
    }

    // MARK: - 문구

    func test_알림_문구에_생리라는_말을_쓰지_않는다() throws {
        // 남이 화면을 봐도 무슨 앱인지 알아채기 어려워야 한다(UX-설계 3번).
        let reminders = try service.reminders(
            prediction: prediction(nextStart: TestSupport.day(2026, 10, 1)),
            settings: settings,
            now: now
        ).get()

        for reminder in reminders {
            XCTAssertFalse(reminder.title.contains("생리"))
            XCTAssertFalse(reminder.body.contains("생리"))
        }
    }

    func test_알림_탭_경로가_담긴다() throws {
        let reminders = try service.reminders(
            prediction: prediction(nextStart: TestSupport.day(2026, 10, 1)),
            settings: settings,
            now: now
        ).get()

        XCTAssertEqual(
            reminders.first?.userInfo[NotificationRoute.key],
            NotificationRoute.home.rawValue
        )
    }

    // MARK: - 겹쳐 도는 재예약

    func test_재예약이_겹쳐_돌아도_설정과_어긋나지_않는다() async throws {
        // 재예약은 "지우고 넣는" 두 단계다. 겹쳐 돌면 한쪽이 지운 뒤 다른 쪽이 넣어
        // 설정과 어긋난 상태로 끝날 수 있다. 큐로 순서를 지키면 마지막 상태가 정답이어야 한다.
        try seedRecordsForPrediction()
        let queue = ReminderRescheduleQueue()
        let service = self.service!

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await queue.enqueue { await service.reschedule(now: self.now) }
                }
            }
        }

        // 식별자가 정해져 있으므로 몇 번을 돌아도 최종 대기 목록은 두 건이어야 한다.
        let pending = await scheduler.pendingIdentifiers()
        XCTAssertEqual(
            Set(pending),
            ["period-reminder-3d", "period-reminder-1d"]
        )
    }

    func test_알림을_끄는_재예약이_마지막이면_예약이_남지_않는다() async throws {
        try seedRecordsForPrediction()
        let queue = ReminderRescheduleQueue()
        let service = self.service!
        let store = self.store!

        await queue.enqueue { await service.reschedule(now: self.now) }
        let afterFirst = await scheduler.pendingIdentifiers()
        XCTAssertFalse(afterFirst.isEmpty)

        try store.updateSettings { $0.notificationEnabled = false }
        await queue.enqueue { await service.reschedule(now: self.now) }

        let pending = await scheduler.pendingIdentifiers()
        XCTAssertTrue(pending.isEmpty, "껐는데 예약이 남으면 안 된다")
    }

    // MARK: - Helpers

    /// 28일 간격 기록 세 건. 예정일이 충분히 미래로 잡히도록 만든다.
    /// 마지막 기록의 종료일까지 과거여야 저장소가 미래 날짜로 거부하지 않는다.
    private func seedRecordsForPrediction() throws {
        let calendar = TestSupport.calendar
        let anchor = calendar.date(byAdding: .day, value: -10, to: calendar.startOfDay(for: now))!
        for offset in [-56, -28, 0] {
            let start = calendar.date(byAdding: .day, value: offset, to: anchor)!
            let end = calendar.date(byAdding: .day, value: 4, to: start)!
            try store.recordPeriodStart(on: start, now: now, source: .app)
            try store.recordPeriodEnd(on: end, now: now, source: .app)
        }
    }
}

private extension Result where Failure == CycleReminderService.SkipReason {
    var failureReason: CycleReminderService.SkipReason? {
        if case .failure(let reason) = self { return reason }
        return nil
    }
}
