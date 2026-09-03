import AppIntents
import WidgetKit

/// 잠금화면 버튼이 앱을 열지 않고 위젯 익스텐션 프로세스 안에서 바로 실행하는 인텐트.
/// `openAppWhenRun == false`와 `authenticationPolicy == .alwaysAllowed`가
/// 1주차 스파이크에서 확인한 핵심 조건이다(SPIKE.md).
struct RecordPeriodStartIntent: AppIntent {
    static let title: LocalizedStringResource = "생리 시작 기록"
    static let description = IntentDescription("오늘 날짜로 생리 시작일을 기록합니다.")
    static let openAppWhenRun = false
    /// 기본값 `.requiresAuthentication`이면 기기가 잠긴 상태에서는 인텐트가 조용히 무시된다.
    /// 잠금 해제 없이 탭 한 번으로 기록하는 게 이 앱의 핵심 행동이라 명시적으로 허용한다.
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

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
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    init() {}

    func perform() async throws -> some IntentResult {
        RecordPeriodIntentRunner.run(.end)
        return .result()
    }
}

/// 두 인텐트가 공유하는 실행 본체.
///
/// HealthKit 쓰기는 여기서 하지 않는다. 위젯 익스텐션에서 HealthKit을 쓰려면 별도 권한과
/// 잠금 상태 처리가 필요해서, 저장만 하고 앱이 열릴 때 `HealthKitSyncCoordinator`가
/// 밀린 기록을 내보낸다.
enum RecordPeriodIntentRunner {
    enum Kind: String {
        case start
        case end
    }

    static func run(_ kind: Kind, on date: Date = Date(), now: Date = Date()) {
        let store = DadariEnvironment.recordStore
        do {
            let outcome: PeriodRecordOutcome
            switch kind {
            case .start:
                outcome = try store.recordPeriodStart(on: date, now: now, source: .lockScreen)
            case .end:
                outcome = try store.recordPeriodEnd(on: date, now: now, source: .lockScreen)
            }

            DadariLog.intent.notice("""
                인텐트 실행 kind=\(kind.rawValue, privacy: .public) \
                결과=\(outcome.isNewRecord ? "기록됨" : "중복무시", privacy: .public) \
                AppGroup=\(DadariEnvironment.isUsingSharedContainer ? "연결됨" : "실패", privacy: .public)
                """)
        } catch {
            // 잠금화면에는 오류를 띄울 자리가 없다. 로그로만 남기고 위젯 갱신은 그대로 진행해서
            // 사용자가 "아무 일도 안 일어났다"는 사실 자체는 위젯에서 알 수 있게 한다.
            DadariLog.intent.error("""
                인텐트 실패 kind=\(kind.rawValue, privacy: .public) \
                오류=\(String(describing: error), privacy: .public)
                """)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
