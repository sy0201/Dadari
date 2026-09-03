import SwiftData
import XCTest
@testable import Dadari

/// 컨테이너 생성 경로를 고정한다.
///
/// SwiftData는 App Group 엔타이틀먼트가 없으면 오류를 던지는 게 아니라 `fatalError`로
/// 프로세스를 죽인다. 1주차에 Xcode가 엔타이틀먼트를 비워버린 적이 있어서(SPIKE.md)
/// 실제로 일어나는 상황이고, 그때 앱이 크래시하는 대신 폴백해야 한다.
///
/// CI는 `CODE_SIGNING_ALLOWED=NO`로 빌드해 엔타이틀먼트가 없는 상태로 돌기 때문에,
/// 이 파일의 테스트가 그 경로를 실제로 지나간다.
final class DadariModelContainerTests: XCTestCase {
    func test_인메모리_컨테이너를_열_수_있다() throws {
        let container = try DadariModelContainer.inMemory()

        XCTAssertNoThrow(try ModelContext(container).fetch(FetchDescriptor<PeriodRecord>()))
    }

    func test_로컬_폴백_컨테이너를_열_수_있다() throws {
        // App Group을 못 잡았을 때 여기로 떨어진다. 인메모리가 아니라 디스크를 써서
        // 앱을 껐다 켜도 기록이 남아야 한다.
        let container = try DadariModelContainer.localFallback()

        XCTAssertNoThrow(try ModelContext(container).fetch(FetchDescriptor<PeriodRecord>()))
    }

    func test_App_Group이_없으면_크래시_대신_오류를_던진다() throws {
        guard !AppGroup.isAvailable else {
            throw XCTSkip("이 실행 환경에는 App Group 엔타이틀먼트가 있다. CI(서명 없음)에서 검증된다.")
        }

        XCTAssertThrowsError(try DadariModelContainer.shared()) { error in
            XCTAssertEqual(error as? DadariModelContainerError, .appGroupUnavailable)
        }
    }

    func test_App_Group이_있으면_공유_컨테이너를_연다() throws {
        guard AppGroup.isAvailable else {
            throw XCTSkip("이 실행 환경에는 App Group 엔타이틀먼트가 없다.")
        }

        XCTAssertNoThrow(try DadariModelContainer.shared())
    }

    func test_스키마에_두_모델이_모두_들어있다() {
        let names = DadariModelContainer.schema.entities.map(\.name).sorted()

        XCTAssertEqual(names, ["CycleSettings", "PeriodRecord"])
    }
}
