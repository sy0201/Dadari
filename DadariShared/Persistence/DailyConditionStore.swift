import Foundation
import SwiftData

/// 하루치 컨디션 기록의 저장·조회. `PeriodRecordStore`와 같은 컨테이너를 쓴다.
///
/// 하루에 한 건만 남긴다. CloudKit이 유니크 제약을 지원하지 않으므로 여기서 보장한다.
/// 동기화 충돌로 같은 날 여러 건이 생기면 가장 최근에 수정된 것을 정본으로 본다.
final class DailyConditionStore {
    private let container: ModelContainer
    private let calendar: Calendar
    private let lock = NSLock()

    init(container: ModelContainer, calendar: Calendar = .current) {
        self.container = container
        self.calendar = calendar
    }

    func condition(on date: Date) throws -> DailyConditionSnapshot? {
        try withContext { context in
            try Self.fetch(day: calendar.startOfDay(for: date), in: context)?.snapshot
        }
    }

    /// 최근 것이 앞에 오도록 정렬해서 돌려준다.
    func recentConditions(limit: Int = 30) throws -> [DailyConditionSnapshot] {
        try withContext { context in
            try Self.fetchAll(in: context)
                .sorted { $0.day > $1.day }
                .prefix(limit)
                .map(\.snapshot)
        }
    }

    /// 그날의 증상을 통째로 교체한다.
    ///
    /// 빈 목록이면 기록 자체를 지운다. 아무것도 고르지 않은 빈 행을 남겨두면
    /// "기록했지만 증상 없음"과 "기록 안 함"이 구분되지 않는데, 그 구분이 필요한 곳이 없다.
    @discardableResult
    func save(
        symptoms: Set<Symptom>,
        on date: Date,
        now: Date = Date()
    ) throws -> DailyConditionSnapshot? {
        try withContext { context in
            let day = calendar.startOfDay(for: date)
            try validateNotFuture(day, now: now)

            let existing = try Self.fetch(day: day, in: context)

            guard !symptoms.isEmpty else {
                if let existing { context.delete(existing) }
                try context.save()
                return nil
            }

            if let existing {
                existing.symptoms = symptoms
                existing.updatedAt = now
                try context.save()
                return existing.snapshot
            }

            let condition = DailyCondition(
                day: day,
                symptoms: symptoms,
                createdAt: now,
                updatedAt: now
            )
            context.insert(condition)
            try context.save()
            return condition.snapshot
        }
    }

    func delete(on date: Date) throws {
        try withContext { context in
            let day = calendar.startOfDay(for: date)
            guard let condition = try Self.fetch(day: day, in: context) else { return }
            context.delete(condition)
            try context.save()
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
        return try body(ModelContext(container))
    }

    /// 건수가 많아야 하루 한 건이라 전부 가져와 Swift에서 거른다.
    private static func fetchAll(in context: ModelContext) throws -> [DailyCondition] {
        try context.fetch(FetchDescriptor<DailyCondition>())
    }

    private static func fetch(day: Date, in context: ModelContext) throws -> DailyCondition? {
        try fetchAll(in: context)
            .filter { $0.day == day }
            .max { $0.updatedAt < $1.updatedAt }
    }
}
