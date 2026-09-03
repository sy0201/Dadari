import Foundation
import HealthKit

/// 실제 HealthKit 저장소에 쓰는 구현.
///
/// 기록 1건을 날짜 하루당 샘플 하나로 펼쳐서 저장한다. 건강 앱이 주기를 하루 단위로
/// 다루기 때문이고, 시작일 샘플에만 `HKMetadataKeyMenstrualCycleStart`를 켠다.
/// 우리 기록의 UUID를 `HKMetadataKeyExternalUUID`에 넣어두면, 나중에 그 기록만
/// 정확히 찾아 지우거나 대체할 수 있다.
struct HealthKitWriter: HealthKitWriting {
    private let store: HKHealthStore
    private let calendar: Calendar

    init(store: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    private var menstrualFlowType: HKCategoryType {
        HKCategoryType(.menstrualFlow)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var shareAuthorization: HealthKitShareAuthorization {
        guard isAvailable else { return .notDetermined }
        switch store.authorizationStatus(for: menstrualFlowType) {
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        do {
            // 읽기는 Phase 2라 toShare만 요청한다.
            try await store.requestAuthorization(toShare: [menstrualFlowType], read: [])
        } catch {
            throw HealthKitError.authorizationFailed
        }
    }

    func save(_ record: PeriodRecordSnapshot) async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        // 같은 기록을 다시 저장하는 경우(수정 등)를 위해 기존 샘플을 먼저 지운다.
        try? await delete(record)

        let samples = makeSamples(for: record)
        guard !samples.isEmpty else { return }

        do {
            try await store.save(samples)
        } catch {
            throw HealthKitError.saveFailed(error.localizedDescription)
        }
    }

    func delete(_ record: PeriodRecordSnapshot) async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyExternalUUID,
            allowedValues: [record.id.uuidString]
        )

        do {
            // 자기 앱이 저장한 샘플만 지워진다. 읽기 권한은 필요 없다.
            try await store.deleteObjects(of: menstrualFlowType, predicate: predicate)
        } catch {
            throw HealthKitError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Private

    /// 기록 기간을 하루 단위 샘플로 펼친다. 종료일이 아직 없으면 시작일 하루만 저장한다.
    ///
    /// - Important: 각 샘플은 그날 자정부터 **23:59:59까지**로 끝난다. 다음 날 0시로 끝내면
    ///   샘플이 자정 경계에 걸쳐 건강 앱이 다음 날에도 데이터가 있다고 보게 되고,
    ///   그러면 건강 앱에서 그 날짜를 직접 기록할 수 없게 된다(다른 앱이 쓴 날짜는
    ///   사용자가 토글하지 못하고 원본 앱에서 관리해야 하기 때문).
    ///   실기기 확인에서 "9월 3일 이후로 건강 앱 버튼이 안 먹힌다"로 드러난 문제다.
    func makeSamples(for record: PeriodRecordSnapshot) -> [HKCategorySample] {
        let start = calendar.startOfDay(for: record.startDate)
        let end = calendar.startOfDay(for: record.endDate ?? record.startDate)
        guard end >= start else { return [] }

        let value = record.flow?.healthKitCategoryValue ?? FlowLevel.healthKitUnspecifiedValue

        var samples: [HKCategorySample] = []
        var day = start
        while day <= end {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                  let dayEnd = calendar.date(byAdding: .second, value: -1, to: nextDay) else {
                break
            }
            let metadata: [String: Any] = [
                HKMetadataKeyMenstrualCycleStart: day == start,
                HKMetadataKeyExternalUUID: record.id.uuidString,
            ]
            samples.append(
                HKCategorySample(
                    type: menstrualFlowType,
                    value: value,
                    start: day,
                    end: dayEnd,
                    metadata: metadata
                )
            )
            day = nextDay
        }
        return samples
    }
}
