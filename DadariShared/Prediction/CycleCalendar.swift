import Foundation

/// 달력 셀 하나의 상태. 목업의 `dayType()`과 같은 구분이다.
enum CycleDayKind: String, Equatable, Sendable {
    /// 실제로 기록된 생리 기간.
    case loggedPeriod
    /// 가임기(예측).
    case fertile
    /// 예측 생리 직전 며칠.
    case pms
    /// 예측 생리 기간.
    case predictedPeriod
    /// 위 어디에도 속하지 않는 날.
    case ordinary
}

/// 날짜별 상태와 문페이즈 값을 계산한다.
///
/// 예측 자체는 `CyclePredictionService`가 하고, 여기서는 그 결과를 화면이 쓰기 좋은
/// 하루 단위 정보로 바꾸기만 한다. 둘을 나눠 두면 예측 규칙을 건드리지 않고
/// 표시 방식만 바꿀 수 있다.
struct CycleCalendar {
    /// 예측 생리 시작 며칠 전부터 PMS로 볼지. 목업 기준 3일(8/17~8/19 → 예측 8/20).
    var pmsLength = 3

    var calendar: Calendar

    init(calendar: Calendar = .current, pmsLength: Int = 3) {
        self.calendar = calendar
        self.pmsLength = pmsLength
    }

    // MARK: - 날짜 분류

    /// 목업의 우선순위를 그대로 따른다: 실제 기록 > 가임기 > PMS > 예측 생리.
    func kind(
        for date: Date,
        records: [PeriodRecordSnapshot],
        prediction: CyclePrediction?,
        settings: CycleSettingsSnapshot
    ) -> CycleDayKind {
        let day = calendar.startOfDay(for: date)

        if isLogged(day, in: records, settings: settings) { return .loggedPeriod }

        guard let prediction else { return .ordinary }

        if prediction.fertileWindow.contains(day) { return .fertile }
        if isPMS(day, prediction: prediction) { return .pms }
        if isPredictedPeriod(day, prediction: prediction, settings: settings) { return .predictedPeriod }
        return .ordinary
    }

    /// 종료일이 아직 없는 기록은 설정의 예상 생리 기간만큼 이어진다고 본다.
    private func isLogged(
        _ day: Date,
        in records: [PeriodRecordSnapshot],
        settings: CycleSettingsSnapshot
    ) -> Bool {
        records.contains { record in
            let start = calendar.startOfDay(for: record.startDate)
            let end: Date
            if let endDate = record.endDate {
                end = calendar.startOfDay(for: endDate)
            } else {
                let length = max(settings.estimatedPeriodLength, 1)
                end = calendar.date(byAdding: .day, value: length - 1, to: start) ?? start
            }
            return day >= start && day <= end
        }
    }

    private func isPMS(_ day: Date, prediction: CyclePrediction) -> Bool {
        guard pmsLength > 0,
              let start = calendar.date(
                  byAdding: .day, value: -pmsLength, to: prediction.nextPeriodStartDate
              ),
              let end = calendar.date(
                  byAdding: .day, value: -1, to: prediction.nextPeriodStartDate
              )
        else { return false }
        return day >= start && day <= end
    }

    private func isPredictedPeriod(
        _ day: Date,
        prediction: CyclePrediction,
        settings: CycleSettingsSnapshot
    ) -> Bool {
        let start = prediction.nextPeriodStartDate
        let length = max(settings.estimatedPeriodLength, 1)
        guard let end = calendar.date(byAdding: .day, value: length - 1, to: start) else {
            return false
        }
        return day >= start && day <= end
    }

    // MARK: - 주기 일차와 문페이즈

    /// 기준 시작일로부터 며칠째인지. 1일차부터 센다.
    /// 기준일보다 앞선 날짜는 이전 주기로 보고 한 주기를 더해 되돌린다(목업과 동일).
    func cycleDay(for date: Date, prediction: CyclePrediction) -> Int {
        let day = calendar.startOfDay(for: date)
        let reference = calendar.startOfDay(for: prediction.referenceStartDate)
        let diff = calendar.dateComponents([.day], from: reference, to: day).day ?? 0
        var cycleDay = diff + 1
        while cycleDay < 1 {
            cycleDay += prediction.cycleLengthUsed
        }
        return cycleDay
    }

    /// 달이 얼마나 찼는지. 0이면 그믐, 1이면 보름.
    ///
    /// PRD 3.2의 "생리 시작(그믐) → 배란기(보름) → 다시 그믐"을 그대로 옮긴 것이다.
    /// 주기 중앙에서 가장 크고 양 끝에서 0이 된다.
    func moonFullness(for date: Date, prediction: CyclePrediction) -> Double {
        let length = max(prediction.cycleLengthUsed, 1)
        let progress = Double(cycleDay(for: date, prediction: prediction)) / Double(length)
        return max(0, min(1, 1 - abs(progress - 0.5) * 2))
    }
}
