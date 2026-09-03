import SwiftData
import XCTest
@testable import Dadari

/// 홈 화면의 기록 버튼과 상태 갱신을 검증한다.
///
/// 실기기 확인에서 "기록 후 삭제하고 다시 탭하면 기록이 안 되고 날짜도 리셋되지 않는다"는
/// 문제가 나왔다. 다른 화면에서 데이터가 바뀐 뒤 홈이 옛 상태로 판단하던 것이 원인이라,
/// 그 경로를 여기서 고정한다.
@MainActor
final class HomeViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var model: HomeViewModel!

    private var store: PeriodRecordStore { DadariEnvironment.recordStore }

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try DadariModelContainer.inMemory()
        DadariEnvironment.recordStore = PeriodRecordStore(
            container: container,
            calendar: TestSupport.calendar
        )
        model = HomeViewModel(calendar: TestSupport.calendar)
    }

    override func tearDown() {
        model = nil
        DadariEnvironment.resetStoreOverride()
        container = nil
        super.tearDown()
    }

    private let today = TestSupport.date(2026, 9, 3)

    func test_기록_버튼은_진행_중인_주기가_없으면_시작을_남긴다() throws {
        model.recordToday(now: today)

        let records = try store.records()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.startDate, TestSupport.day(2026, 9, 3))
        XCTAssertNil(records.first?.endDate)
        XCTAssertNil(model.message)
    }

    func test_기록_버튼은_진행_중인_주기가_있으면_종료를_남긴다() throws {
        model.recordToday(now: today)
        model.recordToday(now: today)

        let records = try store.records()
        XCTAssertEqual(records.count, 1, "종료는 새 기록을 만들지 않는다")
        XCTAssertEqual(records.first?.endDate, TestSupport.day(2026, 9, 3))
    }

    func test_같은_날_이미_기록됐으면_아무_일도_없는_대신_이유를_알린다() throws {
        model.recordToday(now: today)   // 시작
        model.recordToday(now: today)   // 종료
        model.message = nil

        model.recordToday(now: today)   // 다시 시작 시도 → 같은 날이라 중복

        XCTAssertEqual(try store.records().count, 1)
        XCTAssertNotNil(model.message, "버튼이 먹통인 것처럼 보이면 안 된다")
    }

    func test_다른_화면에서_기록이_지워져도_홈이_옛_상태로_판단하지_않는다() throws {
        model.recordToday(now: today)
        XCTAssertTrue(model.hasOngoingPeriod)

        // 개발용 대시보드 등 다른 경로에서 지운 상황. 홈은 아직 모른다.
        let record = try XCTUnwrap(store.records().first)
        try store.delete(id: record.id)
        XCTAssertTrue(model.hasOngoingPeriod, "아직 갱신 전이라 옛 상태다")

        // 이 상태에서 버튼을 누르면 종료를 시도해 실패하는 게 아니라,
        // 최신 상태를 다시 읽고 새 시작 기록을 남겨야 한다.
        model.recordToday(now: today)

        XCTAssertNil(model.message)
        let records = try store.records()
        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records.first?.endDate, "새로 시작한 기록이어야 한다")
    }

    func test_기록을_지우고_다시_읽으면_날짜_표시가_돌아온다() throws {
        model.recordToday(now: today)
        model.reload(now: today)
        XCTAssertEqual(model.kind(for: today), .loggedPeriod)

        let record = try XCTUnwrap(store.records().first)
        try store.delete(id: record.id)
        model.reload(now: today)

        XCTAssertNotEqual(model.kind(for: today), .loggedPeriod, "지운 날짜는 생리 표시가 빠져야 한다")
        XCTAssertFalse(model.hasOngoingPeriod)
    }

    func test_기록이_없으면_예측도_비어_있다() {
        model.reload(now: today)

        XCTAssertNil(model.prediction)
        XCTAssertEqual(model.statusText, "기록을 시작해 보세요")
    }
}
