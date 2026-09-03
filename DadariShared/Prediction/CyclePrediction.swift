import Foundation

/// 예측 결과. 화면이 필요로 하는 값을 전부 담되, 계산은 하지 않는 순수한 값 타입이다.
struct CyclePrediction: Equatable, Sendable {
    /// 예측에 쓴 주기 길이가 어디서 나왔는지.
    enum Basis: Equatable, Sendable {
        /// 기록이 부족해 온보딩 추정값(PRD 6.1)을 쓴 경우.
        case estimate
        /// 실제 기록 간격을 쓴 경우. `cycleCount`는 중앙값 계산에 들어간 주기 수.
        case history(cycleCount: Int)
    }

    /// PRD 6.2의 신뢰도 표시. 낮으면 D-day를 단정적인 숫자로 보여주지 않는다.
    enum Confidence: Equatable, Sendable {
        case high
        case low
    }

    /// D-day 상태. PRD 4.1의 예측 안전장치가 여기에 들어간다.
    enum Status: Equatable, Sendable {
        /// 예정일까지 남은 일수. 0이면 오늘이 예정일이다.
        case upcoming(daysRemaining: Int)
        /// 예정일이 지났지만 아직 유예 기간 안이다.
        case overdue(daysPast: Int)
        /// 예정일이 지나고 유예 기간도 넘겼다. 카운트다운을 멈추고 안내로 전환한다.
        case stale(daysPast: Int)
    }

    /// 예측의 기준이 된 마지막 생리 시작일.
    var referenceStartDate: Date
    var nextPeriodStartDate: Date
    var ovulationDate: Date
    var fertileWindow: ClosedRange<Date>
    var cycleLengthUsed: Int
    var basis: Basis
    var confidence: Confidence
    var status: Status

    /// 카운트다운을 숫자로 보여줘도 되는 상태인지.
    var showsCountdown: Bool {
        if case .stale = status { return false }
        return true
    }
}
