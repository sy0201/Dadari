import Foundation

/// 기록 저장이 거부되는 경우. UX-설계 9번의 예외 처리 항목과 1:1로 대응한다.
enum PeriodRecordError: LocalizedError, Equatable {
    /// 미래 날짜로 기록하려는 경우.
    case futureDate
    /// 시작일보다 이른 종료일을 넣으려는 경우.
    case endDateBeforeStartDate
    /// 진행 중인 주기가 없는데 종료일을 기록하려는 경우.
    case noOngoingRecord
    /// 수정/삭제하려는 기록을 찾지 못한 경우.
    case recordNotFound

    var errorDescription: String? {
        switch self {
        case .futureDate:
            return "아직 오지 않은 날짜는 기록할 수 없어요."
        case .endDateBeforeStartDate:
            return "종료일은 시작일보다 빠를 수 없어요."
        case .noOngoingRecord:
            return "종료할 기록이 없어요. 시작일을 먼저 기록해 주세요."
        case .recordNotFound:
            return "기록을 찾을 수 없어요."
        }
    }
}

/// 기록 시도의 결과. 잠금화면 연타로 인한 중복은 실패가 아니라 "이미 기록됨"으로 다룬다.
enum PeriodRecordOutcome: Equatable {
    case recorded(PeriodRecordSnapshot)
    case alreadyRecorded(PeriodRecordSnapshot)

    var snapshot: PeriodRecordSnapshot {
        switch self {
        case .recorded(let snapshot), .alreadyRecorded(let snapshot):
            return snapshot
        }
    }

    var isNewRecord: Bool {
        if case .recorded = self { return true }
        return false
    }
}
