import Foundation

/// 저장소에 쌓인 기록을 HealthKit으로 내보낸다.
///
/// 잠금화면 기록은 위젯 익스텐션 프로세스에서 일어나는데, 거기서 HealthKit을 직접 쓰려면
/// 익스텐션에 별도 권한이 필요하고 잠금 상태의 권한 상태까지 다뤄야 한다.
/// 그래서 위젯은 저장만 하고, 앱이 앞으로 나올 때 이 코디네이터가 밀린 것을 모아 내보낸다.
/// PRD 6.3에서 HealthKit을 "이중 보험"으로 두는 목적에는 이 지연으로도 충분하다.
struct HealthKitSyncCoordinator {
    /// 한 번의 동기화 결과. 일부가 실패해도 나머지는 계속 진행한다.
    struct Summary: Equatable {
        var attempted = 0
        var synced = 0
        var failed = 0
        /// HealthKit을 쓸 수 없거나 설정에서 꺼져 있어 아무것도 하지 않은 경우.
        var skipped = false

        /// 마지막으로 발생한 실패 사유.
        ///
        /// HealthKit은 사용자가 쓰기 권한을 거부해도 `requestAuthorization`이 성공으로 돌아온다.
        /// 건강 정보 노출을 막기 위한 설계인데, 그래서 실제 저장을 시도해 봐야 거부를 알 수 있다.
        /// 실기기 확인 때 원인을 눈으로 볼 수 있도록 사유를 들고 온다.
        var lastErrorDescription: String?

        static let skippedSummary = Summary(skipped: true)
    }

    /// 삭제 결과. 앱에서 지운 기록을 HealthKit에서도 지웠는지 알려준다.
    struct DeletionResult: Equatable {
        /// HealthKit에서도 지웠는지. 내보낸 적이 없는 기록이면 false다(지울 게 없었다는 뜻).
        var removedFromHealthKit = false
        /// HealthKit 삭제가 실패한 경우의 사유. 로컬 삭제는 그래도 진행된다.
        var healthKitErrorDescription: String?
    }

    private let store: PeriodRecordStore
    private let writer: HealthKitWriting

    init(store: PeriodRecordStore, writer: HealthKitWriting) {
        self.store = store
        self.writer = writer
    }

    var isHealthKitAvailable: Bool { writer.isAvailable }

    var shareAuthorization: HealthKitShareAuthorization { writer.shareAuthorization }

    /// 설정에서 HealthKit 연동이 켜져 있을 때만 동작한다.
    @discardableResult
    func syncPending(now: Date = Date()) async -> Summary {
        guard writer.isAvailable else { return .skippedSummary }

        let syncEnabled = (try? store.settings().healthKitSyncEnabled) ?? false
        guard syncEnabled else { return .skippedSummary }

        // 권한이 없으면 기록마다 실패를 쌓는 대신 한 번에 사유를 알린다.
        guard writer.shareAuthorization == .authorized else {
            var summary = Summary.skippedSummary
            summary.lastErrorDescription = HealthKitError.sharingDenied.errorDescription
            return summary
        }

        guard let pending = try? store.recordsNeedingHealthKitSync(), !pending.isEmpty else {
            return Summary()
        }

        var summary = Summary(attempted: pending.count)
        for record in pending {
            do {
                try await writer.save(record)
                try store.markHealthKitSynced(id: record.id, at: now)
                summary.synced += 1
            } catch {
                // 한 건이 실패해도 나머지는 계속 시도한다.
                // 동기화되지 않은 기록은 다음 실행에서 다시 대상이 된다.
                DadariLog.health.error("HealthKit 동기화 실패: \(String(describing: error), privacy: .public)")
                summary.failed += 1
                summary.lastErrorDescription = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
        return summary
    }

    /// 앱에서 기록을 지울 때 쓴다. HealthKit에 내보낸 적이 있으면 거기서도 지운다.
    ///
    /// 저장소만 지우면 건강 앱에는 기록이 그대로 남는다. 잠금화면이 주 입력 경로라
    /// 오탭을 되돌리는 일이 잦은데(UX-설계 9번), 되돌려도 건강 앱에 남아 있으면
    /// 삭제가 삭제로 동작하지 않는 셈이다.
    ///
    /// HealthKit 삭제가 실패해도 로컬 삭제는 진행한다. 사용자가 지우라고 한 것이므로
    /// 앱에 남겨두는 쪽이 더 나쁘다. 대신 실패 사유를 돌려줘서 화면에 알릴 수 있게 한다.
    @discardableResult
    func deleteRecord(id: UUID) async throws -> DeletionResult {
        guard let snapshot = try store.records().first(where: { $0.id == id }) else {
            throw PeriodRecordError.recordNotFound
        }

        var result = DeletionResult()

        // 내보낸 적이 없으면 HealthKit에는 지울 게 없다.
        if snapshot.healthKitSyncedAt != nil, writer.isAvailable {
            do {
                try await writer.delete(snapshot)
                result.removedFromHealthKit = true
            } catch {
                DadariLog.health.error(
                    "HealthKit 삭제 실패: \(String(describing: error), privacy: .public)"
                )
                result.healthKitErrorDescription = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }

        try store.delete(id: id)
        return result
    }

    /// 여러 건을 한 번에 지운다. 한 건이 실패해도 나머지는 계속 진행한다.
    @discardableResult
    func deleteRecords(ids: [UUID]) async -> [UUID: DeletionResult] {
        var results: [UUID: DeletionResult] = [:]
        for id in ids {
            if let result = try? await deleteRecord(id: id) {
                results[id] = result
            }
        }
        return results
    }

    /// 사용자가 설정에서 연동을 켤 때 호출한다. 권한을 받고 곧바로 밀린 기록을 내보낸다.
    @discardableResult
    func enableAndSync(now: Date = Date()) async throws -> Summary {
        guard writer.isAvailable else { throw HealthKitError.unavailable }

        // 아직 물어본 적이 없을 때만 시트가 뜬다. 이미 거부된 상태면 아무 일도 일어나지 않는다.
        if writer.shareAuthorization == .notDetermined {
            try await writer.requestAuthorization()
        }

        // requestAuthorization은 사용자가 거부해도 성공으로 돌아온다.
        // 그 성공만 보고 연동을 켜면, 권한이 없는데 "켜짐"이 되어 계속 실패만 하고
        // 사용자는 이유도 끄는 방법도 알 수 없게 된다. 실제 상태를 확인하고 켠다.
        guard writer.shareAuthorization == .authorized else {
            try store.updateSettings { $0.healthKitSyncEnabled = false }
            throw HealthKitError.sharingDenied
        }

        try store.updateSettings { $0.healthKitSyncEnabled = true }
        return await syncPending(now: now)
    }

    /// 사용자가 연동을 끌 때. 이미 내보낸 기록은 건강 앱에 그대로 둔다.
    func disableSync() throws {
        try store.updateSettings { $0.healthKitSyncEnabled = false }
    }
}
