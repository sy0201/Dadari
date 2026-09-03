import Foundation
import Observation
import WidgetKit

/// 홈 화면의 상태를 모은다. 저장소와 예측을 읽어 화면이 바로 쓸 수 있는 값으로 바꾼다.
@Observable
final class HomeViewModel {
    private(set) var records: [PeriodRecordSnapshot] = []
    private(set) var settings = CycleSettingsSnapshot()
    private(set) var prediction: CyclePrediction?

    var selectedDate = Calendar.current.startOfDay(for: Date())
    var isCalendarExpanded = false
    var isPhaseGuidePresented = false
    var message: String?

    private let calendarModel: CycleCalendar
    private var store: PeriodRecordStore { DadariEnvironment.recordStore }

    init(calendar: Calendar = .current) {
        self.calendarModel = CycleCalendar(calendar: calendar)
        #if DEBUG
        // 시뮬레이터에서 화면 상태별로 스크린샷을 찍기 위한 실행 인자.
        // 탭 없이도 월간 그리드와 단계 안내를 열어 목업과 대조할 수 있다.
        isCalendarExpanded = CommandLine.arguments.contains("-showMonth")
        isPhaseGuidePresented = CommandLine.arguments.contains("-showPhaseGuide")
        #endif
    }

    // MARK: - 읽기

    func reload(now: Date = Date()) {
        records = (try? store.records()) ?? []
        settings = (try? store.settings()) ?? CycleSettingsSnapshot()
        prediction = DadariEnvironment.currentPrediction(now: now)
    }

    func kind(for date: Date) -> CycleDayKind {
        calendarModel.kind(for: date, records: records, prediction: prediction, settings: settings)
    }

    /// 선택한 날짜 기준으로 달이 얼마나 찼는지. 예측이 없으면 그믐으로 둔다.
    var moonFullness: Double {
        guard let prediction else { return 0 }
        return calendarModel.moonFullness(for: selectedDate, prediction: prediction)
    }

    /// 문페이즈 아래 큰 문구. 목업 `updateMoon()`의 statusText와 같다.
    var statusText: String {
        guard prediction != nil else { return "기록을 시작해 보세요" }
        switch kind(for: selectedDate) {
        case .loggedPeriod:
            return "생리 \(loggedDayNumber)일째"
        case .fertile:
            return "가임기"
        case .pms:
            return "PMS 예상"
        case .predictedPeriod:
            return "예측 생리"
        case .ordinary:
            return "평상시"
        }
    }

    /// 문페이즈 아래 보조 문구. 목업의 sub와 같다.
    var subtitleText: String {
        guard let prediction else {
            return "온보딩 값이나 첫 기록이 있어야 예측할 수 있어요"
        }

        let cycleDay = calendarModel.cycleDay(for: selectedDate, prediction: prediction)
        let base = "주기 \(cycleDay)일차"

        switch prediction.status {
        case .stale:
            // 카운트다운을 멈춘다. 틀린 숫자를 계속 보여주지 않기 위한 안전장치(PRD 4.1).
            return "\(base) · 예정일이 한참 지났어요"
        case .overdue(let days):
            return "\(base) · 예정일 +\(days)일"
        case .upcoming(let days):
            let suffix = days == 0 ? "예정일" : "다음 예정일 D-\(days)"
            return prediction.confidence == .low ? "\(base) · \(suffix) 예상" : "\(base) · \(suffix)"
        }
    }

    /// 진행 중인(종료일이 없는) 기록이 있는지.
    var hasOngoingPeriod: Bool {
        records.contains { $0.isOngoing }
    }

    /// 기록에서 계산한 평균 생리 기간. 완료된 기록이 없으면 설정값을 쓴다.
    var periodLength: Int {
        let lengths = records.compactMap { record -> Int? in
            guard let end = record.endDate else { return nil }
            let days = Calendar.current.dateComponents([.day], from: record.startDate, to: end).day
            return days.map { $0 + 1 }
        }
        guard !lengths.isEmpty else { return settings.estimatedPeriodLength }
        return Int((Double(lengths.reduce(0, +)) / Double(lengths.count)).rounded())
    }

    private var loggedDayNumber: Int {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: selectedDate)
        guard let record = records.first(where: { calendar.startOfDay(for: $0.startDate) <= day }) else {
            return 1
        }
        let diff = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: record.startDate), to: day
        ).day ?? 0
        return diff + 1
    }

    // MARK: - 쓰기

    /// 컬러 팝 카드의 기록 버튼. 진행 중인 주기가 있으면 종료를, 없으면 시작을 남긴다.
    func recordToday(now: Date = Date()) {
        // 다른 화면에서 기록이 지워졌을 수 있으므로 최신 상태를 먼저 확인한다.
        // 오래된 상태로 판단하면 종료할 기록이 없는데 종료를 시도하는 일이 생긴다.
        reload(now: now)

        do {
            let outcome: PeriodRecordOutcome
            if hasOngoingPeriod {
                outcome = try store.recordPeriodEnd(on: now, now: now, source: .app)
            } else {
                outcome = try store.recordPeriodStart(on: now, now: now, source: .app)
            }

            if !outcome.isNewRecord {
                // 같은 날 같은 종류는 한 번만 저장된다. 아무 일도 일어나지 않은 것처럼
                // 보이지 않도록 이유를 알린다.
                message = "오늘은 이미 기록돼 있어요."
            }

            WidgetCenter.shared.reloadAllTimelines()
            selectedDate = Calendar.current.startOfDay(for: now)
            reload(now: now)
        } catch {
            message = error.localizedDescription
        }
    }
}
