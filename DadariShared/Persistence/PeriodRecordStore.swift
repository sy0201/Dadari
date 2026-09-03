import Foundation
import SwiftData

/// 기록의 저장·조회·수정·삭제를 담당한다. 도메인 규칙(UX-설계 9번)도 여기서 보장한다.
///
/// 앱과 위젯 익스텐션이 각각 다른 프로세스에서 호출하므로, 호출마다 `ModelContext`를
/// 새로 만든다. `ModelContext`는 스레드 안전하지 않고 오래 들고 있으면 다른 프로세스의
/// 변경을 놓친다. 컨테이너는 App Group 안의 같은 스토어 파일을 가리킨다.
final class PeriodRecordStore {
    private let container: ModelContainer
    private let calendar: Calendar

    /// 잠금화면 연타 시 읽고-쓰기가 섞이지 않도록 프로세스 안에서 직렬화한다.
    private let lock = NSLock()

    init(container: ModelContainer, calendar: Calendar = .current) {
        self.container = container
        self.calendar = calendar
    }

    // MARK: - 조회

    /// 최근 시작일이 앞에 오도록 정렬해서 돌려준다.
    func records() throws -> [PeriodRecordSnapshot] {
        try withContext { context in
            try Self.fetchRecords(in: context)
                .sorted { $0.startDate > $1.startDate }
                .map(\.snapshot)
        }
    }

    /// 예측에 넘길 수 있도록 오래된 것부터 정렬해서 돌려준다.
    func recordsOldestFirst() throws -> [PeriodRecordSnapshot] {
        try records().reversed()
    }

    func settings() throws -> CycleSettingsSnapshot {
        try withContext { context in
            try Self.fetchOrCreateSettings(in: context, save: true).snapshot
        }
    }

    // MARK: - 기록

    /// 생리 시작일을 기록한다. 같은 날 시작 기록이 이미 있으면 새로 만들지 않는다.
    @discardableResult
    func recordPeriodStart(
        on date: Date,
        now: Date = Date(),
        source: RecordSource,
        flow: FlowLevel? = nil
    ) throws -> PeriodRecordOutcome {
        try withContext { context in
            let day = calendar.startOfDay(for: date)
            try validateNotFuture(day, now: now)

            let existing = try Self.fetchRecords(in: context)
            if let duplicate = existing.first(where: { calendar.startOfDay(for: $0.startDate) == day }) {
                return .alreadyRecorded(duplicate.snapshot)
            }

            let record = PeriodRecord(
                startDate: day,
                flow: flow,
                source: source,
                createdAt: now,
                updatedAt: now
            )
            context.insert(record)
            try context.save()
            return .recorded(record.snapshot)
        }
    }

    /// 진행 중인 주기에 종료일을 기록한다.
    @discardableResult
    func recordPeriodEnd(
        on date: Date,
        now: Date = Date(),
        source: RecordSource
    ) throws -> PeriodRecordOutcome {
        try withContext { context in
            let day = calendar.startOfDay(for: date)
            try validateNotFuture(day, now: now)

            let existing = try Self.fetchRecords(in: context)

            guard let ongoing = existing
                .filter(\.isOngoing)
                .max(by: { $0.startDate < $1.startDate })
            else {
                // 진행 중인 주기가 없다. 같은 날로 이미 종료한 기록이 있으면 연타로 보고 멱등 처리한다.
                if let closed = existing.first(where: {
                    $0.endDate.map { calendar.startOfDay(for: $0) == day } ?? false
                }) {
                    return .alreadyRecorded(closed.snapshot)
                }
                throw PeriodRecordError.noOngoingRecord
            }

            guard day >= calendar.startOfDay(for: ongoing.startDate) else {
                throw PeriodRecordError.endDateBeforeStartDate
            }

            ongoing.endDate = day
            ongoing.updatedAt = now
            try context.save()
            return .recorded(ongoing.snapshot)
        }
    }

    // MARK: - 수정 / 삭제

    /// 캘린더에서 날짜를 탭해 들어가는 수정 화면이 쓴다(PRD 4.1).
    /// 잠금화면이 주 입력 경로라 오탭을 되돌릴 수 있는 경로가 반드시 필요하다.
    ///
    /// 수정 화면은 항상 모든 값을 들고 있으므로 부분 수정 대신 전체 교체로 받는다.
    /// `endDate`/`flow`에 nil을 넘기면 "값을 비운다"는 뜻이다.
    @discardableResult
    func update(
        id: UUID,
        startDate: Date,
        endDate: Date?,
        flow: FlowLevel?,
        now: Date = Date()
    ) throws -> PeriodRecordSnapshot {
        try withContext { context in
            guard let record = try Self.fetchRecords(in: context).first(where: { $0.id == id }) else {
                throw PeriodRecordError.recordNotFound
            }

            let newStart = calendar.startOfDay(for: startDate)
            let newEnd = endDate.map { calendar.startOfDay(for: $0) }

            try validateNotFuture(newStart, now: now)
            if let newEnd {
                try validateNotFuture(newEnd, now: now)
                guard newEnd >= newStart else {
                    throw PeriodRecordError.endDateBeforeStartDate
                }
            }

            record.startDate = newStart
            record.endDate = newEnd
            record.flow = flow
            record.updatedAt = now
            try context.save()
            return record.snapshot
        }
    }

    /// - Warning: 저장소만 지운다. HealthKit에 내보낸 기록이면 건강 앱에는 그대로 남는다.
    ///   앱 화면에서 지울 때는 `HealthKitSyncCoordinator.deleteRecord(id:)`를 써야 한다.
    ///   실기기 확인에서 이 경로를 직접 부르는 바람에 건강 앱에 기록이 남는 문제가 있었다.
    func delete(id: UUID) throws {
        try withContext { context in
            guard let record = try Self.fetchRecords(in: context).first(where: { $0.id == id }) else {
                throw PeriodRecordError.recordNotFound
            }
            context.delete(record)
            try context.save()
        }
    }

    // MARK: - HealthKit 동기화 보조

    /// 아직 HealthKit으로 내보내지 않았거나, 내보낸 뒤 수정된 기록.
    func recordsNeedingHealthKitSync() throws -> [PeriodRecordSnapshot] {
        try withContext { context in
            try Self.fetchRecords(in: context)
                .filter(\.needsHealthKitSync)
                .sorted { $0.startDate < $1.startDate }
                .map(\.snapshot)
        }
    }

    func markHealthKitSynced(id: UUID, at date: Date = Date()) throws {
        try withContext { context in
            guard let record = try Self.fetchRecords(in: context).first(where: { $0.id == id }) else {
                throw PeriodRecordError.recordNotFound
            }
            record.healthKitSyncedAt = date
            try context.save()
        }
    }

    // MARK: - 설정

    @discardableResult
    func updateSettings(
        _ mutate: (CycleSettings) -> Void,
        now: Date = Date()
    ) throws -> CycleSettingsSnapshot {
        try withContext { context in
            let settings = try Self.fetchOrCreateSettings(in: context, save: false)
            mutate(settings)
            settings.updatedAt = now
            try context.save()
            return settings.snapshot
        }
    }

    // MARK: - Private

    private func validateNotFuture(_ day: Date, now: Date) throws {
        guard day <= calendar.startOfDay(for: now) else {
            throw PeriodRecordError.futureDate
        }
    }

    private func withContext<T>(_ body: (ModelContext) throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        let context = ModelContext(container)
        return try body(context)
    }

    /// 기록 수가 많아야 연 12건 수준이라 전부 가져와 Swift에서 거른다.
    /// `#Predicate`로 옵셔널/열거형을 다루면 표현이 복잡해지는 데 비해 얻는 게 없다.
    private static func fetchRecords(in context: ModelContext) throws -> [PeriodRecord] {
        try context.fetch(FetchDescriptor<PeriodRecord>())
    }

    /// 설정은 항상 한 건만 유지한다. CloudKit이 유니크 제약을 지원하지 않으므로
    /// 동기화 충돌로 여러 건이 생길 수 있고, 그때는 가장 최근에 수정된 것을 정본으로 본다.
    private static func fetchOrCreateSettings(
        in context: ModelContext,
        save: Bool
    ) throws -> CycleSettings {
        let all = try context.fetch(FetchDescriptor<CycleSettings>())
        if let latest = all.max(by: { $0.updatedAt < $1.updatedAt }) {
            return latest
        }
        let settings = CycleSettings()
        context.insert(settings)
        if save { try context.save() }
        return settings
    }
}
