import Foundation
@testable import Dadari

/// HealthKit 쓰기를 가로채는 테스트용 대역.
/// 실제 HealthKit은 시뮬레이터에서 동작하지 않으므로(PRD 4.1) 여기서 대신 검증한다.
final class HealthKitWriterSpy: HealthKitWriting {
    var isAvailable = true
    var authorizationRequestCount = 0
    var authorizationError: Error?

    private(set) var savedRecords: [PeriodRecordSnapshot] = []
    private(set) var deletedRecords: [PeriodRecordSnapshot] = []

    /// 이 id를 가진 기록의 저장만 실패시킨다. 부분 실패 처리를 확인하는 용도.
    var failingRecordIDs: Set<UUID> = []

    func requestAuthorization() async throws {
        authorizationRequestCount += 1
        if let authorizationError { throw authorizationError }
    }

    func save(_ record: PeriodRecordSnapshot) async throws {
        if failingRecordIDs.contains(record.id) {
            throw HealthKitError.saveFailed("테스트 실패 주입")
        }
        savedRecords.append(record)
    }

    func delete(_ record: PeriodRecordSnapshot) async throws {
        deletedRecords.append(record)
    }
}
