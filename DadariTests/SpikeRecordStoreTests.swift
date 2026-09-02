import XCTest
@testable import Dadari

/// 잠금화면이 주 입력 경로라 오탭·연타가 잦다(UX-설계 9번).
/// 중복 방지가 UI가 아니라 저장소 레벨에서 보장되는지 검증한다.
final class SpikeRecordStoreTests: XCTestCase {
    private var calendar: Calendar!
    private var store: SpikeRecordStore!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        store = SpikeRecordStore(store: InMemoryKeyValueStore(), calendar: calendar)
    }

    override func tearDown() {
        store = nil
        calendar = nil
        super.tearDown()
    }

    func test_첫_기록은_새_기록으로_저장된다() {
        let outcome = store.record(.start, on: date(2026, 9, 2, hour: 9), source: .lockScreen)

        XCTAssertTrue(outcome.isNewRecord)
        XCTAssertEqual(store.entries().count, 1)
        XCTAssertEqual(store.entries().first?.kind, .start)
        XCTAssertEqual(store.entries().first?.source, .lockScreen)
    }

    func test_같은_날_같은_종류를_연타해도_기록은_하나다() {
        let first = store.record(.start, on: date(2026, 9, 2, hour: 9), source: .lockScreen)

        for _ in 0..<10 {
            let repeated = store.record(.start, on: date(2026, 9, 2, hour: 9), source: .lockScreen)
            XCTAssertFalse(repeated.isNewRecord)
            XCTAssertEqual(repeated.entry.id, first.entry.id)
        }

        XCTAssertEqual(store.entries().count, 1)
    }

    func test_같은_날이면_시각이_달라도_중복으로_처리된다() {
        store.record(.start, on: date(2026, 9, 2, hour: 0), source: .lockScreen)
        let evening = store.record(.start, on: date(2026, 9, 2, hour: 23), source: .lockScreen)

        XCTAssertFalse(evening.isNewRecord)
        XCTAssertEqual(store.entries().count, 1)
    }

    func test_같은_날이라도_시작과_종료는_따로_기록된다() {
        XCTAssertTrue(store.record(.start, on: date(2026, 9, 2), source: .lockScreen).isNewRecord)
        XCTAssertTrue(store.record(.end, on: date(2026, 9, 2), source: .lockScreen).isNewRecord)

        XCTAssertEqual(store.entries().count, 2)
    }

    func test_날짜가_다르면_같은_종류라도_각각_기록된다() {
        XCTAssertTrue(store.record(.start, on: date(2026, 9, 2), source: .lockScreen).isNewRecord)
        XCTAssertTrue(store.record(.start, on: date(2026, 10, 1), source: .lockScreen).isNewRecord)

        XCTAssertEqual(store.entries().count, 2)
    }

    func test_기록은_최신순으로_정렬된다() {
        store.record(.start, on: date(2026, 9, 2), now: date(2026, 9, 2, hour: 8), source: .lockScreen)
        store.record(.end, on: date(2026, 9, 6), now: date(2026, 9, 6, hour: 8), source: .app)

        let entries = store.entries()
        XCTAssertEqual(entries.map(\.kind), [.end, .start])
    }

    func test_기록을_전체_삭제할_수_있다() {
        store.record(.start, on: date(2026, 9, 2), source: .lockScreen)
        store.removeAll()

        XCTAssertTrue(store.entries().isEmpty)
    }

    func test_저장소를_공유하면_다른_인스턴스에서도_같은_기록이_보인다() {
        // 위젯 익스텐션과 앱이 별개 프로세스라는 점을 인스턴스 분리로 흉내낸다.
        let backing = InMemoryKeyValueStore()
        let widgetSide = SpikeRecordStore(store: backing, calendar: calendar)
        let appSide = SpikeRecordStore(store: backing, calendar: calendar)

        widgetSide.record(.start, on: date(2026, 9, 2), source: .lockScreen)

        XCTAssertEqual(appSide.entries().count, 1)
        XCTAssertEqual(appSide.entries().first?.source, .lockScreen)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )
        guard let date = components.date else {
            fatalError("테스트 픽스처 날짜 생성 실패: \(year)-\(month)-\(day)")
        }
        return date
    }
}
