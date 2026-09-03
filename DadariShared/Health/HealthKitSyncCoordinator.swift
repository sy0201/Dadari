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

    private let store: PeriodRecordStore
    private let writer: HealthKitWriting

    init(store: PeriodRecordStore, writer: HealthKitWriting) {
        self.store = store
        self.writer = writer
    }

    /// 설정에서 HealthKit 연동이 켜져 있을 때만 동작한다.
    @discardableResult
    func syncPending(now: Date = Date()) async -> Summary {
        guard writer.isAvailable else { return .skippedSummary }

        let syncEnabled = (try? store.settings().healthKitSyncEnabled) ?? false
        guard syncEnabled else { return .skippedSummary }

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

    /// 사용자가 설정에서 연동을 켤 때 호출한다. 권한을 받고 곧바로 밀린 기록을 내보낸다.
    @discardableResult
    func enableAndSync(now: Date = Date()) async throws -> Summary {
        guard writer.isAvailable else { throw HealthKitError.unavailable }
        try await writer.requestAuthorization()
        try store.updateSettings { $0.healthKitSyncEnabled = true }
        return await syncPending(now: now)
    }
}
