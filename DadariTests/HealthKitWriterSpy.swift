import Foundation
@testable import Dadari

/// HealthKit 쓰기를 가로채는 테스트용 대역.
/// 실제 HealthKit은 시뮬레이터에서 동작하지 않으므로(PRD 4.1) 여기서 대신 검증한다.
final class HealthKitWriterSpy: HealthKitWriting {
    var isAvailable = true
    var shareAuthorization: HealthKitShareAuthorization = .authorized
    var authorizationRequestCount = 0
    var authorizationError: Error?

    /// 권한 요청 시트가 뜬 뒤 사용자가 고를 결과. 실제 HealthKit 흐름을 흉내낸다.
    var authorizationResult: HealthKitShareAuthorization?

    private(set) var savedRecords: [PeriodRecordSnapshot] = []
    private(set) var deletedRecords: [PeriodRecordSnapshot] = []

    /// 이 id를 가진 기록의 저장만 실패시킨다. 부분 실패 처리를 확인하는 용도.
    var failingRecordIDs: Set<UUID> = []

    /// 설정하면 모든 삭제가 실패한다.
    var deleteError: Error?

    func requestAuthorization() async throws {
        authorizationRequestCount += 1
        if let authorizationError { throw authorizationError }
        // 실제 HealthKit은 거부돼도 성공으로 돌아온다. 상태만 바뀐다.
        if let authorizationResult { shareAuthorization = authorizationResult }
    }

    func save(_ record: PeriodRecordSnapshot) async throws {
        if failingRecordIDs.contains(record.id) {
            throw HealthKitError.saveFailed("테스트 실패 주입")
        }
        savedRecords.append(record)
    }

    func delete(_ record: PeriodRecordSnapshot) async throws {
        if let deleteError { throw deleteError }
        deletedRecords.append(record)
    }
}
