import HealthKit
import SwiftData
import XCTest
@testable import Dadari

/// 생리량 매핑이 HealthKit 열거형과 어긋나지 않는지 확인한다.
///
/// iOS 18에서 `HKCategoryValueMenstrualFlow`가 `HKCategoryValueVaginalBleeding`으로
/// 대체됐는데 최소 지원이 iOS 17이라 원시값으로 다루고 있다. 그 원시값이 맞는지
/// 여기서 실제 열거형과 대조한다.
final class HealthKitFlowMappingTests: XCTestCase {
    func test_생리량_매핑이_HealthKit_열거형과_일치한다() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("HKCategoryValueVaginalBleeding은 iOS 18 이상에서만 확인할 수 있다")
        }

        XCTAssertEqual(FlowLevel.light.healthKitCategoryValue, HKCategoryValueVaginalBleeding.light.rawValue)
        XCTAssertEqual(FlowLevel.medium.healthKitCategoryValue, HKCategoryValueVaginalBleeding.medium.rawValue)
        XCTAssertEqual(FlowLevel.heavy.healthKitCategoryValue, HKCategoryValueVaginalBleeding.heavy.rawValue)
        XCTAssertEqual(FlowLevel.healthKitUnspecifiedValue, HKCategoryValueVaginalBleeding.unspecified.rawValue)
    }
}

/// 기록 1건을 HealthKit 샘플로 펼치는 규칙을 고정한다.
final class HealthKitWriterSampleTests: XCTestCase {
    private var writer: HealthKitWriter!

    override func setUp() {
        super.setUp()
        writer = HealthKitWriter(calendar: TestSupport.calendar)
    }

    override func tearDown() {
        writer = nil
        super.tearDown()
    }

    func test_기간이_있는_기록은_하루당_샘플_하나로_펼쳐진다() {
        let record = PeriodRecordSnapshot(
            startDate: TestSupport.day(2026, 9, 1),
            endDate: TestSupport.day(2026, 9, 5),
            flow: .medium
        )

        let samples = writer.makeSamples(for: record)

        XCTAssertEqual(samples.count, 5, "9월 1일부터 5일까지 5일치")
        XCTAssertTrue(samples.allSatisfy { $0.value == FlowLevel.medium.healthKitCategoryValue })
    }

    func test_시작일_샘플에만_주기_시작_표시가_붙는다() {
        let record = PeriodRecordSnapshot(
            startDate: TestSupport.day(2026, 9, 1),
            endDate: TestSupport.day(2026, 9, 3)
        )

        let samples = writer.makeSamples(for: record)
        let cycleStartFlags = samples.map { $0.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool }

        XCTAssertEqual(cycleStartFlags, [true, false, false])
    }

    func test_기록_UUID를_메타데이터에_남겨_나중에_찾을_수_있게_한다() {
        let record = PeriodRecordSnapshot(startDate: TestSupport.day(2026, 9, 1))

        let samples = writer.makeSamples(for: record)

        XCTAssertEqual(
            samples.first?.metadata?[HKMetadataKeyExternalUUID] as? String,
            record.id.uuidString
        )
    }

    func test_진행_중인_기록은_시작일_하루만_저장한다() {
        let record = PeriodRecordSnapshot(startDate: TestSupport.day(2026, 9, 1), endDate: nil)

        XCTAssertEqual(writer.makeSamples(for: record).count, 1)
    }

    func test_생리량을_고르지_않으면_unspecified로_저장한다() {
        let record = PeriodRecordSnapshot(startDate: TestSupport.day(2026, 9, 1), flow: nil)

        XCTAssertEqual(writer.makeSamples(for: record).first?.value, FlowLevel.healthKitUnspecifiedValue)
    }
}

/// 잠금화면에서 쌓인 기록을 앱이 나중에 내보내는 흐름을 검증한다.
final class HealthKitSyncCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var store: PeriodRecordStore!
    private var spy: HealthKitWriterSpy!
    private var coordinator: HealthKitSyncCoordinator!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try DadariModelContainer.inMemory()
        store = PeriodRecordStore(container: container, calendar: TestSupport.calendar)
        spy = HealthKitWriterSpy()
        coordinator = HealthKitSyncCoordinator(store: store, writer: spy)
    }

    override func tearDown() {
        coordinator = nil
        spy = nil
        store = nil
        container = nil
        super.tearDown()
    }

    private func seedRecord(day: Int = 1) throws {
        let date = TestSupport.date(2026, 9, day)
        try store.recordPeriodStart(on: date, now: date, source: .lockScreen)
    }

    func test_연동이_꺼져_있으면_아무것도_내보내지_않는다() async throws {
        try seedRecord()

        let summary = await coordinator.syncPending()

        XCTAssertTrue(summary.skipped)
        XCTAssertTrue(spy.savedRecords.isEmpty)
    }

    func test_HealthKit을_쓸_수_없는_기기에서는_건너뛴다() async throws {
        try seedRecord()
        try store.updateSettings { $0.healthKitSyncEnabled = true }
        spy.isAvailable = false

        let summary = await coordinator.syncPending()

        XCTAssertTrue(summary.skipped)
        XCTAssertTrue(spy.savedRecords.isEmpty)
    }

    func test_연동을_켜면_권한을_받고_밀린_기록을_내보낸다() async throws {
        try seedRecord(day: 1)
        try seedRecord(day: 29)

        let summary = try await coordinator.enableAndSync(now: TestSupport.date(2026, 9, 30))

        XCTAssertEqual(spy.authorizationRequestCount, 1)
        XCTAssertEqual(summary.synced, 2)
        XCTAssertEqual(spy.savedRecords.count, 2)
        XCTAssertTrue(try store.settings().healthKitSyncEnabled)
    }

    func test_한번_내보낸_기록은_다시_내보내지_않는다() async throws {
        try seedRecord()
        try await coordinator.enableAndSync(now: TestSupport.date(2026, 9, 2))
        XCTAssertEqual(spy.savedRecords.count, 1)

        let second = await coordinator.syncPending(now: TestSupport.date(2026, 9, 3))

        XCTAssertEqual(second.attempted, 0)
        XCTAssertEqual(spy.savedRecords.count, 1)
    }

    func test_기록을_수정하면_다시_내보낸다() async throws {
        try seedRecord()
        try await coordinator.enableAndSync(now: TestSupport.date(2026, 9, 2))

        let record = try XCTUnwrap(store.records().first)
        try store.update(
            id: record.id,
            startDate: record.startDate,
            endDate: TestSupport.date(2026, 9, 4),
            flow: .heavy,
            now: TestSupport.date(2026, 9, 5)
        )

        let summary = await coordinator.syncPending(now: TestSupport.date(2026, 9, 6))

        XCTAssertEqual(summary.synced, 1)
        XCTAssertEqual(spy.savedRecords.count, 2)
        XCTAssertEqual(spy.savedRecords.last?.flow, .heavy)
    }

    func test_한_건이_실패해도_나머지는_계속_내보낸다() async throws {
        try seedRecord(day: 1)
        try seedRecord(day: 29)
        try store.updateSettings { $0.healthKitSyncEnabled = true }

        let first = try XCTUnwrap(store.recordsNeedingHealthKitSync().first)
        spy.failingRecordIDs = [first.id]

        let summary = await coordinator.syncPending(now: TestSupport.date(2026, 9, 30))

        XCTAssertEqual(summary.attempted, 2)
        XCTAssertEqual(summary.synced, 1)
        XCTAssertEqual(summary.failed, 1)

        // 실패한 기록은 다음 실행에서 다시 대상이 된다.
        XCTAssertEqual(try store.recordsNeedingHealthKitSync().map(\.id), [first.id])
    }

    func test_실패_사유를_요약에_담아_화면에서_볼_수_있다() async throws {
        // HealthKit은 쓰기 권한을 거부해도 requestAuthorization이 성공으로 돌아온다.
        // 실제 저장을 시도해야 거부를 알 수 있으므로, 사유가 화면까지 전달돼야 한다.
        try seedRecord()
        try store.updateSettings { $0.healthKitSyncEnabled = true }
        let record = try XCTUnwrap(store.recordsNeedingHealthKitSync().first)
        spy.failingRecordIDs = [record.id]

        let summary = await coordinator.syncPending(now: TestSupport.date(2026, 9, 2))

        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(
            summary.lastErrorDescription,
            HealthKitError.saveFailed("테스트 실패 주입").errorDescription
        )
    }

    // MARK: - 삭제

    func test_앱에서_지운_기록은_HealthKit에서도_지워진다() async throws {
        // 실기기 확인에서 발견한 문제. 저장소만 지우면 건강 앱에는 기록이 그대로 남았다.
        try seedRecord()
        try await coordinator.enableAndSync(now: TestSupport.date(2026, 9, 2))
        let record = try XCTUnwrap(store.records().first)

        let result = try await coordinator.deleteRecord(id: record.id)

        XCTAssertTrue(result.removedFromHealthKit)
        XCTAssertEqual(spy.deletedRecords.map(\.id), [record.id])
        XCTAssertTrue(try store.records().isEmpty)
    }

    func test_내보낸_적_없는_기록을_지울_때는_HealthKit을_건드리지_않는다() async throws {
        try seedRecord()
        let record = try XCTUnwrap(store.records().first)

        let result = try await coordinator.deleteRecord(id: record.id)

        XCTAssertFalse(result.removedFromHealthKit)
        XCTAssertTrue(spy.deletedRecords.isEmpty)
        XCTAssertTrue(try store.records().isEmpty)
    }

    func test_HealthKit_삭제가_실패해도_앱에서는_지운다() async throws {
        // 사용자가 지우라고 한 것이므로 앱에 남겨두는 쪽이 더 나쁘다. 대신 사유를 알린다.
        try seedRecord()
        try await coordinator.enableAndSync(now: TestSupport.date(2026, 9, 2))
        let record = try XCTUnwrap(store.records().first)
        spy.deleteError = HealthKitError.deleteFailed("테스트 실패 주입")

        let result = try await coordinator.deleteRecord(id: record.id)

        XCTAssertFalse(result.removedFromHealthKit)
        XCTAssertEqual(
            result.healthKitErrorDescription,
            HealthKitError.deleteFailed("테스트 실패 주입").errorDescription
        )
        XCTAssertTrue(try store.records().isEmpty, "HealthKit 실패와 무관하게 로컬은 지워야 한다")
    }

    func test_여러_건을_지울_때_한_건이_실패해도_나머지는_지운다() async throws {
        try seedRecord(day: 1)
        try seedRecord(day: 29)
        try await coordinator.enableAndSync(now: TestSupport.date(2026, 9, 30))
        let ids = try store.records().map(\.id)

        spy.deleteError = HealthKitError.deleteFailed("테스트 실패 주입")
        let results = await coordinator.deleteRecords(ids: ids)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(try store.records().isEmpty)
    }

    func test_없는_기록을_지우면_오류다() async throws {
        do {
            _ = try await coordinator.deleteRecord(id: UUID())
            XCTFail("오류가 나야 한다")
        } catch {
            XCTAssertEqual(error as? PeriodRecordError, .recordNotFound)
        }
    }

    func test_내보낼_기록이_없으면_시도_자체를_하지_않는다() async throws {
        try store.updateSettings { $0.healthKitSyncEnabled = true }

        let summary = await coordinator.syncPending()

        XCTAssertFalse(summary.skipped)
        XCTAssertEqual(summary.attempted, 0)
    }
}
