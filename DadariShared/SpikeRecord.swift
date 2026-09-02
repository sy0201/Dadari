import Foundation

/// 1주차 기술 스파이크 전용 기록 모델.
/// 정식 데이터 모델(SwiftData `PeriodRecord`)은 PRD 6번에 따라 2~4.5주차에 설계한다.
/// 여기서는 "잠금화면 버튼 → App Group 저장소 쓰기"가 실제로 동작하는지만 검증한다.
enum SpikeEntryKind: String, Codable, CaseIterable {
    case start
    case end

    var label: String {
        switch self {
        case .start: return "시작"
        case .end: return "종료"
        }
    }
}

/// 기록이 어디서 들어왔는지. PRD 6번의 `source` 필드와 같은 의도.
enum SpikeEntrySource: String, Codable {
    case lockScreen
    case app
}

struct SpikeEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: SpikeEntryKind
    /// 자정으로 정규화된 날짜. 하루 단위 중복 판정의 기준이 된다.
    var day: Date
    var recordedAt: Date
    var source: SpikeEntrySource

    init(
        id: UUID = UUID(),
        kind: SpikeEntryKind,
        day: Date,
        recordedAt: Date,
        source: SpikeEntrySource
    ) {
        self.id = id
        self.kind = kind
        self.day = day
        self.recordedAt = recordedAt
        self.source = source
    }
}

/// 기록 시도의 결과. 연타로 인한 중복은 실패가 아니라 "이미 기록됨"으로 다룬다.
enum SpikeRecordOutcome: Equatable {
    case recorded(SpikeEntry)
    case alreadyRecorded(SpikeEntry)

    var entry: SpikeEntry {
        switch self {
        case .recorded(let entry), .alreadyRecorded(let entry): return entry
        }
    }

    var isNewRecord: Bool {
        if case .recorded = self { return true }
        return false
    }
}
