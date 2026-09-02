import Foundation

/// App Group 컨테이너를 통해 앱과 위젯 익스텐션이 공유하는 스파이크용 저장소.
///
/// 같은 날짜 + 같은 종류의 기록은 한 번만 남긴다. 잠금화면 버튼은 오탭과 연타가
/// 잦은 입력 경로라(UX-설계 9번), 중복 방지가 저장소 레벨에서 보장돼야 한다.
final class SpikeRecordStore {
    static let storageKey = "spike.entries.v1"

    /// 앱과 위젯이 공용으로 쓰는 인스턴스.
    /// 인텐트가 이 인스턴스를 직접 참조하므로, 테스트에서 갈아끼울 수 있도록 `var`로 둔다.
    static var shared: SpikeRecordStore = {
        if let defaults = AppGroup.sharedDefaults {
            SpikeLog.store.notice("App Group 연결됨 (\(AppGroup.identifier, privacy: .public))")
            return SpikeRecordStore(store: defaults, isUsingSharedContainer: true)
        }
        // App Group 프로비저닝이 잘못된 경우. 앱은 계속 동작하되 위젯과 데이터가 갈린다.
        SpikeLog.store.error("""
            App Group 연결 실패 (\(AppGroup.identifier, privacy: .public)). \
            엔타이틀먼트 또는 프로비저닝 프로파일을 확인할 것. 로컬 저장소로 폴백한다.
            """)
        return SpikeRecordStore(store: UserDefaults.standard, isUsingSharedContainer: false)
    }()

    /// App Group 컨테이너를 실제로 잡았는지. 스파이크의 검증 포인트라 UI에 노출한다.
    let isUsingSharedContainer: Bool

    private let store: KeyValueStore
    private let calendar: Calendar
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        store: KeyValueStore,
        calendar: Calendar = .current,
        isUsingSharedContainer: Bool = false
    ) {
        self.store = store
        self.calendar = calendar
        self.isUsingSharedContainer = isUsingSharedContainer
    }

    /// 최신 기록이 앞에 오도록 정렬해서 반환한다.
    func entries() -> [SpikeEntry] {
        lock.lock()
        defer { lock.unlock() }
        return loadUnlocked().sorted { $0.recordedAt > $1.recordedAt }
    }

    /// 하루 단위로 멱등하게 기록한다. 같은 날 같은 종류를 다시 눌러도 새 항목이 생기지 않는다.
    @discardableResult
    func record(
        _ kind: SpikeEntryKind,
        on date: Date = Date(),
        now: Date = Date(),
        source: SpikeEntrySource
    ) -> SpikeRecordOutcome {
        lock.lock()
        defer { lock.unlock() }

        let day = calendar.startOfDay(for: date)
        var entries = loadUnlocked()

        if let existing = entries.first(where: { $0.kind == kind && $0.day == day }) {
            return .alreadyRecorded(existing)
        }

        let entry = SpikeEntry(kind: kind, day: day, recordedAt: now, source: source)
        entries.append(entry)
        saveUnlocked(entries)
        return .recorded(entry)
    }

    /// 스파이크 검증을 반복하기 위한 초기화 경로.
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        store.setData(nil, forKey: Self.storageKey)
    }

    // MARK: - Private

    private func loadUnlocked() -> [SpikeEntry] {
        guard let data = store.data(forKey: Self.storageKey) else { return [] }
        return (try? decoder.decode([SpikeEntry].self, from: data)) ?? []
    }

    private func saveUnlocked(_ entries: [SpikeEntry]) {
        guard let data = try? encoder.encode(entries) else { return }
        store.setData(data, forKey: Self.storageKey)
    }
}
