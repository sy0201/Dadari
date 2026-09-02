import AppIntents
import WidgetKit

/// 잠금화면 버튼이 앱을 열지 않고 위젯 익스텐션 프로세스 안에서 바로 실행하는 인텐트.
/// `openAppWhenRun == false`가 이 스파이크의 핵심 검증 포인트다.
struct RecordPeriodStartIntent: AppIntent {
    static let title: LocalizedStringResource = "생리 시작 기록"
    static let description = IntentDescription("오늘 날짜로 생리 시작일을 기록합니다.")
    static let openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult {
        SpikeRecordStore.shared.record(.start, source: .lockScreen)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct RecordPeriodEndIntent: AppIntent {
    static let title: LocalizedStringResource = "생리 종료 기록"
    static let description = IntentDescription("오늘 날짜로 생리 종료일을 기록합니다.")
    static let openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult {
        SpikeRecordStore.shared.record(.end, source: .lockScreen)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
