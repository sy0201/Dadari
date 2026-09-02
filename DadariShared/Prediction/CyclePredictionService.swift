import Foundation

/// 날짜 기록만으로 다음 생리일·배란일·가임기를 예측한다. PRD 6.2의 규칙을 그대로 옮긴 것.
///
/// 저장소나 UI를 전혀 모르고 값 타입만 받는다. 덕분에 컨테이너를 띄우지 않고
/// 케이스별로 빠르게 테스트할 수 있다(PRD 7번).
struct CyclePredictionService {
    /// 예측 규칙의 수치를 한 곳에 모은다. 테스트에서 갈아끼울 수 있도록 주입 가능하게 둔다.
    struct Configuration: Equatable, Sendable {
        /// 이 범위를 벗어나는 주기는 이상치로 보고 계산에서 제외한다(PRD 6.2).
        var minimumCycleLength = 21
        var maximumCycleLength = 45

        /// 중앙값 계산에 쓸 최근 주기 개수의 상한(PRD 6.2의 "최근 3~6회").
        var maximumCyclesConsidered = 6

        /// 배란 이후 다음 생리까지의 황체기. 사람마다 12~14일로 비교적 일정해서
        /// "주기의 절반"보다 이 역산이 불규칙한 주기에서도 안정적이다(PRD 6.2).
        var lutealPhaseLength = 14

        /// 정자 생존 약 5일, 난자 생존 약 1일을 감안한 가임기 폭(PRD 6.2).
        var fertileWindowDaysBeforeOvulation = 5
        var fertileWindowDaysAfterOvulation = 1

        /// 최근 주기 길이의 표준편차가 이 값 이상이면 낮은 신뢰도로 전환한다.
        /// PRD 6.2는 "일정 기준"이라고만 하고 수치를 정하지 않았다. 4일은 잠정값이고,
        /// 실제 사용 데이터가 쌓이면 조정한다.
        var lowConfidenceStandardDeviation = 4.0

        /// 높은 신뢰도로 보려면 최소 이만큼의 주기 표본이 필요하다.
        /// 표본이 1개면 표준편차가 0으로 나와 실제보다 확신이 과장되기 때문이다.
        var minimumCyclesForHighConfidence = 2

        /// 예정일이 지난 뒤 이만큼 새 기록이 없으면 카운트다운을 멈춘다(PRD 4.1 / 6.2).
        var stalePredictionGraceDays = 7

        init() {}
    }

    var configuration = Configuration()
    var calendar: Calendar

    init(configuration: Configuration = Configuration(), calendar: Calendar = .current) {
        self.configuration = configuration
        self.calendar = calendar
    }

    /// 기록과 설정으로 예측을 만든다.
    /// 기준으로 삼을 날짜가 하나도 없으면(기록도 없고 온보딩 입력도 없으면) nil을 돌려준다.
    /// 빈 상태 화면(UX-설계 9번)은 이 nil을 보고 그린다.
    func predict(
        records: [PeriodRecordSnapshot],
        settings: CycleSettingsSnapshot,
        now: Date
    ) -> CyclePrediction? {
        let startDates = normalizedStartDates(from: records, settings: settings)
        guard let reference = startDates.last else { return nil }

        let cycleLengths = validCycleLengths(from: startDates)
        let recent = Array(cycleLengths.suffix(configuration.maximumCyclesConsidered))

        let cycleLength: Int
        let basis: CyclePrediction.Basis
        let confidence: CyclePrediction.Confidence

        if recent.isEmpty {
            // 기록이 2건 미만이거나, 있는 간격이 전부 이상치로 걸러진 경우.
            cycleLength = clampedCycleLength(settings.estimatedCycleLength)
            basis = .estimate
            confidence = .low
        } else {
            cycleLength = clampedCycleLength(Self.median(of: recent))
            basis = .history(cycleCount: recent.count)
            confidence = Self.confidence(for: recent, configuration: configuration)
        }

        let nextStart = calendar.date(byAdding: .day, value: cycleLength, to: reference) ?? reference
        let ovulation = calendar.date(
            byAdding: .day,
            value: -configuration.lutealPhaseLength,
            to: nextStart
        ) ?? nextStart
        let fertileStart = calendar.date(
            byAdding: .day,
            value: -configuration.fertileWindowDaysBeforeOvulation,
            to: ovulation
        ) ?? ovulation
        let fertileEnd = calendar.date(
            byAdding: .day,
            value: configuration.fertileWindowDaysAfterOvulation,
            to: ovulation
        ) ?? ovulation

        return CyclePrediction(
            referenceStartDate: reference,
            nextPeriodStartDate: nextStart,
            ovulationDate: ovulation,
            fertileWindow: fertileStart...fertileEnd,
            cycleLengthUsed: cycleLength,
            basis: basis,
            confidence: confidence,
            status: status(nextStart: nextStart, now: now)
        )
    }

    // MARK: - 단계별 계산 (테스트에서 개별로 확인할 수 있도록 internal로 둔다)

    /// 기록의 시작일을 자정 정규화하고 중복을 제거해 오름차순으로 돌려준다.
    /// 기록이 하나도 없으면 온보딩에서 받은 마지막 생리 시작일을 유일한 기준으로 쓴다.
    func normalizedStartDates(
        from records: [PeriodRecordSnapshot],
        settings: CycleSettingsSnapshot
    ) -> [Date] {
        let fromRecords = records.map { calendar.startOfDay(for: $0.startDate) }
        let dates = fromRecords.isEmpty
            ? [settings.lastPeriodStartDate].compactMap { $0 }.map { calendar.startOfDay(for: $0) }
            : fromRecords
        return Array(Set(dates)).sorted()
    }

    /// 인접한 시작일 간격 중 이상치를 제외한 것. 오래된 것이 앞에 온다.
    func validCycleLengths(from startDates: [Date]) -> [Int] {
        guard startDates.count >= 2 else { return [] }
        return zip(startDates, startDates.dropFirst()).compactMap { previous, next in
            guard let days = calendar.dateComponents([.day], from: previous, to: next).day else {
                return nil
            }
            guard days >= configuration.minimumCycleLength,
                  days <= configuration.maximumCycleLength else {
                return nil
            }
            return days
        }
    }

    func status(nextStart: Date, now: Date) -> CyclePrediction.Status {
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: nextStart).day ?? 0
        if days >= 0 {
            return .upcoming(daysRemaining: days)
        }
        let past = -days
        return past > configuration.stalePredictionGraceDays
            ? .stale(daysPast: past)
            : .overdue(daysPast: past)
    }

    // MARK: - Private

    /// 사용자가 설정에서 극단적인 값을 넣더라도 예측이 무너지지 않도록 범위를 강제한다.
    private func clampedCycleLength(_ value: Int) -> Int {
        min(max(value, configuration.minimumCycleLength), configuration.maximumCycleLength)
    }

    /// 평균 대신 중앙값을 쓴다. 한두 번의 이상치에 덜 끌려가기 때문이다(PRD 6.2).
    static func median(of values: [Int]) -> Int {
        precondition(!values.isEmpty, "빈 배열의 중앙값은 정의되지 않는다")
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            let average = Double(sorted[middle - 1] + sorted[middle]) / 2.0
            return Int(average.rounded())
        }
        return sorted[middle]
    }

    static func standardDeviation(of values: [Int]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(values.count)
        return variance.squareRoot()
    }

    static func confidence(
        for cycleLengths: [Int],
        configuration: Configuration
    ) -> CyclePrediction.Confidence {
        guard cycleLengths.count >= configuration.minimumCyclesForHighConfidence else {
            return .low
        }
        return standardDeviation(of: cycleLengths) >= configuration.lowConfidenceStandardDeviation
            ? .low
            : .high
    }
}
