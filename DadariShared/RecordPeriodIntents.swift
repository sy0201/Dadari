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
        RecordPeriodIntentRunner.run(.start)
        return .result()
    }
}

struct RecordPeriodEndIntent: AppIntent {
    static let title: LocalizedStringResource = "생리 종료 기록"
    static let description = IntentDescription("오늘 날짜로 생리 종료일을 기록합니다.")
    static let openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult {
        RecordPeriodIntentRunner.run(.end)
        return .result()
    }
}

/// 두 인텐트가 공유하는 실행 본체. 검증 로그를 한 곳에서 남기기 위해 분리했다.
enum RecordPeriodIntentRunner {
    static func run(_ kind: SpikeEntryKind) {
        let store = SpikeRecordStore.shared
        let outcome = store.record(kind, source: .lockScreen)
        let total = store.entries().count

        SpikeLog.intent.notice("""
            인텐트 실행 kind=\(kind.rawValue, privacy: .public) \
            결과=\(outcome.isNewRecord ? "기록됨" : "중복무시", privacy: .public) \
            총건수=\(total, privacy: .public) \
            AppGroup=\(store.isUsingSharedContainer ? "연결됨" : "실패", privacy: .public)
            """)

        WidgetCenter.shared.reloadAllTimelines()
    }
}
