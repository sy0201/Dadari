# 위젯 기술 스파이크 (1주차)

PRD 10번 일정 1주차의 "App Intents 버튼이 잠금화면에서 실제로 동작하는지 UI 없이 최소 프로토타입으로 먼저 검증" 항목에 대한 기록.

## 무엇을 검증하려는가

이 프로젝트에서 리스크가 가장 큰 가정은 하나다.

> 잠금화면 위젯의 버튼을 누르면, **앱을 열지 않고** 위젯 익스텐션 프로세스 안에서 기록이 저장되고,
> 그 기록이 App Group을 통해 앱 프로세스에서도 그대로 보인다.

이게 안 되면 UX-설계 4번의 핵심 행동 자체가 성립하지 않는다. 그래서 데이터 모델도 디자인도 붙이기 전에
이 가정만 먼저 확인한다.

## 검증 구조

```
잠금화면 위젯 버튼  Button(intent: RecordPeriodStartIntent())
        │
        ▼
RecordPeriodStartIntent.perform()      ← openAppWhenRun = false (위젯 익스텐션 프로세스에서 실행)
        │
        ▼
SpikeRecordStore.shared.record(.start, source: .lockScreen)
        │
        ▼
UserDefaults(suiteName: "group.com.dadari.app")   ← App Group 공유 컨테이너
        │
        ├─▶ WidgetCenter.shared.reloadAllTimelines()  → 위젯이 즉시 갱신
        └─▶ 앱(SpikeVerificationView)이 같은 저장소를 읽음
```

스파이크 코드는 전부 `Spike` 접두어를 달아 정식 구현과 구분한다.
정식 데이터 모델(SwiftData `PeriodRecord`)과 `CyclePredictionService`는 PRD 10번의 2~4.5주차 작업이고,
그 시점에 `SpikeRecordStore`는 걷어낸다. 검증된 것은 인텐트/위젯 배선 구조이지 저장소 구현이 아니다.

## 자동으로 검증된 것

`xcodebuild test`로 CI에서 매번 확인된다.

| 항목 | 검증 방법 |
|---|---|
| 앱 타겟과 위젯 익스텐션 타겟이 같은 `DadariShared` 소스를 공유해 빌드됨 | CI 빌드 |
| 위젯 익스텐션이 `NSExtensionPointIdentifier = com.apple.widgetkit-extension`로 앱에 임베드됨 | CI 빌드 |
| 앱/위젯 양쪽 서명에 `group.com.dadari.app` 엔타이틀먼트가 들어감 | 로컬 빌드 산출물 확인 |
| 인텐트가 `openAppWhenRun == false`로 설정돼 있음 | `RecordPeriodIntentsTests` |
| 인텐트 실행이 공유 저장소에 `source: .lockScreen`으로 기록을 남김 | `RecordPeriodIntentsTests` |
| 같은 날 같은 종류를 연타해도 기록이 하나만 남음 (UX-설계 9번) | `SpikeRecordStoreTests` |
| 별개 인스턴스(= 별개 프로세스)에서 같은 기록이 보임 | `SpikeRecordStoreTests` |

시뮬레이터(iPhone 15 / iOS 17.0)에서 앱을 실행해 App Group 컨테이너가 "공유됨"으로 잡히는 것까지 확인했다.

## 실기기에서 직접 확인해야 하는 것

잠금화면 위젯 추가와 탭은 자동화가 안 되므로 아래는 손으로 확인한다.
**이 절차가 통과해야 1주차 스파이크가 끝난 것으로 본다.**

1. Xcode에서 `Dadari` 스킴을 실기기로 선택하고 실행한다.
   - Signing & Capabilities에서 팀을 선택하고, 앱과 위젯 타겟 모두에 App Groups(`group.com.dadari.app`)가 켜져 있는지 확인한다.
2. 잠금화면을 길게 눌러 **사용자화 → 잠금 화면 → 위젯 영역**을 탭하고 "다달이 스파이크" 위젯을 추가한다.
   - 가로형(`accessoryRectangular`)을 추가하면 시작/종료 버튼이 둘 다 보인다.
3. 잠금 상태에서 **시작** 버튼을 탭한다.
   - [ ] 앱이 열리지 않는다 (가장 중요한 확인 항목)
   - [ ] 위젯 텍스트가 즉시 "시작 <오늘 날짜> · 1건"으로 바뀐다
4. 같은 버튼을 빠르게 여러 번 탭한다.
   - [ ] 건수가 1건에서 늘어나지 않는다 (중복 방지)
5. 앱을 열어 기록 목록을 확인한다.
   - [ ] "App Group / 컨테이너"가 **공유됨**으로 표시된다
   - [ ] 방금 누른 기록이 `lockScreen` 출처로 보인다
6. 앱에서 "전체 삭제"를 누르고 잠금화면으로 돌아간다.
   - [ ] 위젯이 "기록 없음"으로 갱신된다 (앱 → 위젯 방향 갱신)

### 확인 결과

- 확인 일자:
- 기기 / iOS 버전:
- 결과:
- 특이사항:

## 남은 이슈 / 다음 단계로 넘길 것

- **다른 날짜 기록 경로**: PRD 4.1의 "다른 날짜로 기록할 때만 앱이 열리고 캘린더 피커로 전환"은 이번 스파이크 범위 밖이다.
  위젯의 `widgetURL` / `Link`로 딥링크를 열고 앱에서 라우팅하는 구조가 되며, 5~8주차 위젯 정식 UI 단계에서 붙인다.
- **저장소 교체**: `SpikeRecordStore`(UserDefaults)는 2~4.5주차에 App Group 컨테이너의 SwiftData로 교체한다.
  이때 위젯 익스텐션에서도 같은 `ModelContainer`를 열 수 있는지 별도 확인이 필요하다.
- **위젯 갱신 예산**: 현재 타임라인 정책은 `.never`이고 인텐트 실행 시점에만 갱신한다.
  정식 위젯은 D-day가 매일 바뀌므로 자정 기준 타임라인 엔트리를 만들어야 한다.
