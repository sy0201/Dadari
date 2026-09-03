import Foundation
import SwiftData

/// 앱과 위젯 익스텐션이 공유하는 의존성 조립 지점.
///
/// 두 프로세스가 각자 이 타입을 통해 같은 App Group 스토어를 연다.
/// 컨테이너를 만들지 못하면(App Group 엔타이틀먼트 문제 등) 앱이 죽는 대신
/// 인메모리로 떨어뜨리고 실패 사실을 남긴다. 1주차에 엔타이틀먼트가 비워진 채로
/// 조용히 동작하던 상황을 겪었기 때문에, 실패를 눈에 보이게 만드는 쪽을 택했다.
enum DadariEnvironment {
    /// 컨테이너 생성 실패 원인. nil이면 App Group 공유가 정상이다.
    private(set) static var containerFailure: Error?

    /// 테스트에서 갈아끼우는 자리. 설정돼 있으면 공유 스토어 대신 이걸 쓴다.
    /// 공유 스토어는 실제 App Group 파일을 열기 때문에, 테스트가 그걸 건드리지 않도록
    /// 별도 슬롯으로 분리한다.
    private static var overrideStore: PeriodRecordStore?

    /// 공유 스토어. 실제로 접근할 때 한 번만 만들어진다.
    private static let sharedStore: PeriodRecordStore = makeSharedStore()

    static var recordStore: PeriodRecordStore {
        get { overrideStore ?? sharedStore }
        set { overrideStore = newValue }
    }

    /// 테스트 종료 시 원래 상태로 되돌린다.
    static func resetStoreOverride() {
        overrideStore = nil
    }

    static var isUsingSharedContainer: Bool {
        containerFailure == nil && AppGroup.isAvailable
    }

    static let predictionService = CyclePredictionService()

    static func makeHealthKitCoordinator() -> HealthKitSyncCoordinator {
        HealthKitSyncCoordinator(store: recordStore, writer: HealthKitWriter())
    }

    /// 현재 저장된 기록과 설정으로 예측을 만든다. 기준 날짜가 없으면 nil이다.
    static func currentPrediction(now: Date = Date()) -> CyclePrediction? {
        guard let records = try? recordStore.recordsOldestFirst(),
              let settings = try? recordStore.settings() else {
            return nil
        }
        return predictionService.predict(records: records, settings: settings, now: now)
    }

    private static func makeSharedStore() -> PeriodRecordStore {
        do {
            let container = try DadariModelContainer.shared()
            DadariLog.store.notice("App Group 스토어 연결됨 (\(AppGroup.identifier, privacy: .public))")
            return PeriodRecordStore(container: container)
        } catch {
            containerFailure = error
            DadariLog.store.error("""
                App Group 스토어 연결 실패: \(String(describing: error), privacy: .public). \
                엔타이틀먼트와 프로비저닝 프로파일을 확인할 것. 앱 자체 저장소로 폴백한다.
                """)
        }

        // 여기서 죽으면 원인을 볼 방법이 없다. 동작은 시키되 공유는 안 되는 상태로 두고,
        // 실패 사실은 로그와 개발용 대시보드에 남긴다.
        if let fallback = try? DadariModelContainer.localFallback() {
            return PeriodRecordStore(container: fallback)
        }

        DadariLog.store.fault("로컬 폴백 저장소도 열지 못했다. 인메모리로 동작한다.")
        // 인메모리는 마지막 수단이다. 앱을 껐다 켜면 기록이 사라진다.
        return PeriodRecordStore(container: try! DadariModelContainer.inMemory())
    }
}
