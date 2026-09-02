import XCTest
@testable import Dadari

/// 잠금화면 버튼이 실행하는 인텐트가 실제로 공유 저장소에 기록을 남기는지 검증한다.
/// 잠금화면에서의 탭 자체는 실기기 확인 사항이고(SPIKE.md), 여기서는 그 뒤의 로직을 고정한다.
final class RecordPeriodIntentsTests: XCTestCase {
    private var originalStore: SpikeRecordStore!

    override func setUp() {
        super.setUp()
        originalStore = SpikeRecordStore.shared
        SpikeRecordStore.shared = SpikeRecordStore(store: InMemoryKeyValueStore())
    }

    override func tearDown() {
        SpikeRecordStore.shared = originalStore
        originalStore = nil
        super.tearDown()
    }

    func test_시작_인텐트는_잠금화면_출처로_기록한다() async throws {
        _ = try await RecordPeriodStartIntent().perform()

        let entries = SpikeRecordStore.shared.entries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.kind, .start)
        XCTAssertEqual(entries.first?.source, .lockScreen)
    }

    func test_종료_인텐트는_잠금화면_출처로_기록한다() async throws {
        _ = try await RecordPeriodEndIntent().perform()

        let entries = SpikeRecordStore.shared.entries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.kind, .end)
        XCTAssertEqual(entries.first?.source, .lockScreen)
    }

    func test_인텐트를_연속으로_실행해도_같은_날_기록은_하나다() async throws {
        for _ in 0..<5 {
            _ = try await RecordPeriodStartIntent().perform()
        }

        XCTAssertEqual(SpikeRecordStore.shared.entries().count, 1)
    }

    func test_앱을_열지_않고_실행되도록_설정돼_있다() {
        // 이 스파이크의 핵심 조건. true가 되면 잠금화면에서 앱이 열려버린다.
        XCTAssertFalse(RecordPeriodStartIntent.openAppWhenRun)
        XCTAssertFalse(RecordPeriodEndIntent.openAppWhenRun)
    }
}
