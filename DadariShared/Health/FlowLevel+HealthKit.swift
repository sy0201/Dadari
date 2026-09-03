import Foundation

extension FlowLevel {
    /// HealthKit `menstrualFlow` 카테고리에 저장할 값.
    ///
    /// iOS 18에서 `HKCategoryValueMenstrualFlow`가 `HKCategoryValueVaginalBleeding`으로
    /// 대체됐다. 최소 지원이 iOS 17이라 새 열거형을 직접 쓸 수 없고, 구 열거형을 쓰면
    /// iOS 18 이상에서 deprecation 경고가 난다. 두 열거형의 원시값이 동일하므로
    /// 원시값으로 다루고, `HealthKitFlowMappingTests`가 iOS 18 이상에서
    /// 실제 열거형과 이 매핑이 어긋나지 않는지 검증한다.
    var healthKitCategoryValue: Int {
        switch self {
        case .light: return 2
        case .medium: return 3
        case .heavy: return 4
        }
    }

    /// 생리량을 고르지 않고 잠금화면에서 날짜만 기록한 경우에 쓴다.
    static let healthKitUnspecifiedValue = 1
}
