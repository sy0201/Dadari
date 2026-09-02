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

## 기록이 실제로 저장됐는지 확인하는 방법

잠금화면에서 버튼이 눌리는 것과 기록이 저장되는 것은 별개다. 아래 순서로 확인한다.

### 1. 위젯 텍스트 (잠금화면에서 바로)

가로형 위젯의 첫 줄이 `기록 없음` → `시작 9월 2일 · 1건`으로 바뀌면 저장까지 된 것이다.
인텐트가 저장 후 `WidgetCenter.shared.reloadAllTimelines()`를 부르고, 갱신된 타임라인이
저장소를 **다시 읽어서** 그리기 때문에 화면이 바뀐 것 자체가 읽기/쓰기가 다 됐다는 증거다.
버튼은 눌리는데(햅틱/애니메이션은 있는데) 텍스트가 안 바뀌면 저장이 실패한 것이다.

### 2. 앱을 열어서 목록 확인 (가장 확실한 확인)

이게 진짜 검증이다. 위젯 익스텐션과 앱은 **별개 프로세스**라서, 위젯에서 쓴 기록이 앱에 보이면
App Group 공유가 실제로 동작한다는 뜻이다.

- 상단 "App Group / 컨테이너"가 **공유됨**이고 컨테이너 경로가 보이는지
- 목록에 방금 누른 항목이 `lockScreen` 출처와 초 단위 시각까지 찍혀 있는지

### 3. Console.app 로그 (안 될 때 원인 찾기)

위젯 익스텐션은 별개 프로세스라 Xcode 콘솔에 로그가 안 섞여 나온다. 대신 macOS의 **Console.app**을 열고
왼쪽에서 연결된 iPhone을 선택한 뒤, 검색창에 `subsystem:com.dadari.app`을 넣고 **Start streaming**을 누른다.
잠금화면에서 버튼을 누르면 이런 줄이 떠야 한다.

```
인텐트 실행 kind=start 결과=기록됨 총건수=1 AppGroup=연결됨
```

이 로그로 세 가지가 한 번에 구분된다.

| 증상 | 의미 |
|---|---|
| 로그가 아예 안 뜸 | 인텐트가 실행되지 않음. 위젯/인텐트 배선 문제 |
| `AppGroup=실패` | 인텐트는 실행됐지만 공유 컨테이너를 못 잡음. 엔타이틀먼트/프로비저닝 문제 |
| `결과=중복무시` | 정상. 오늘 같은 종류를 이미 기록해둔 상태 |

### 4. 디버거 붙이기 (그래도 모르겠을 때)

Xcode에서 **Debug → Attach to Process by PID or Name**에 `DadariWidget`을 넣어두면
위젯 익스텐션이 뜨는 순간 붙는다. `RecordPeriodIntentRunner.run(_:)`에 중단점을 걸고 잠금화면에서 탭한다.

## 함정: 잠금 상태에서는 인텐트가 조용히 무시된다

`AppIntent.authenticationPolicy`의 기본값은 `.requiresAuthentication`이다.
이 상태에서는 **기기가 잠겨 있으면 잠금화면 위젯의 버튼을 눌러도 인텐트가 실행되지 않는다.**
오류도 안 뜨고 아무 반응이 없어서, 위젯 배선이 잘못된 것처럼 보인다.

```swift
static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
```

잠금 해제 없이 탭 한 번으로 기록하는 게 이 앱의 핵심 행동(UX-설계 4번)이므로 명시적으로 허용한다.
`RecordPeriodIntentsTests`가 이 설정을 고정한다.

참고로 얼굴 인식이 걸린 상태에서 우연히 잠금이 풀린 채로 테스트하면 기본값으로도 동작하는 것처럼 보인다.
검증할 때는 화면을 끄고 **잠긴 상태에서** 눌러야 한다.

### 이 값을 `.alwaysAllowed`로 두는 것의 의미

기기를 잠근 채로도 기록이 남는다는 뜻이다. 건강 데이터를 다루는 앱이라 짚고 넘어갈 필요가 있는데,
위젯이 노출하는 정보는 사용자가 직접 잠금화면에 올리기로 선택한 것이고,
버튼이 하는 일은 오늘 날짜 기록 한 건 추가가 전부다. 되돌리기 경로(기록 수정/삭제)도 MVP 범위에 있다.
설정에서 이 동작을 끄고 싶어지면 v1.1의 Face ID 잠금 옵션(UX-설계 8번)과 함께 다룬다.

## 위젯 텍스트는 바뀌는데 앱 목록이 비어 있을 때

앱과 위젯은 별개 프로세스라 **한쪽만 App Group을 놓칠 수 있다.** 위젯이 공유 컨테이너를 못 잡으면
자기 로컬 저장소에 쓰고 그걸 다시 읽으므로, 위젯 텍스트는 정상적으로 갱신되는데 앱에서는 아무것도 안 보인다.

이걸 잠금화면에서 바로 구분할 수 있게, 위젯이 공유 컨테이너를 못 잡으면 상태 텍스트 앞에 `⚠︎ 로컬`을 붙인다.

### 확인 순서

1. **기기에서 앱을 삭제한다.** 앱을 지우면 App Group 컨테이너도 같이 지워져서, 엔타이틀먼트가 잘못됐던
   시절의 기록이 남아 헷갈리는 일이 없어진다. 스파이크 중에는 이 초기화를 먼저 하고 시작한다.
2. Xcode에서 다시 빌드해 설치하고, 잠금화면 위젯을 다시 추가한다.
3. 잠금화면에서 시작 버튼을 누르고 위젯 텍스트를 본다.

| 위젯 표시 | 앱 목록 | 해석 |
|---|---|---|
| `시작 9월 2일 · 1건` | 보임 | 정상. 스파이크 통과 |
| `⚠︎ 로컬 시작 9월 2일 · 1건` | 비어 있음 | 위젯이 App Group을 못 잡음. 위젯 타겟의 Signing & Capabilities 확인 |
| `시작 9월 2일 · 1건` | 비어 있고 앱이 "실패 (로컬 폴백)" | 앱이 App Group을 못 잡음. 앱 타겟 쪽 확인 |
| `시작 9월 2일 · 1건` | 비어 있고 앱은 "공유됨" | 양쪽 다 연결됐는데 데이터가 안 넘어옴. 아래 참고 |

마지막 경우는 `UserDefaults`의 프로세스 간 반영 문제일 수 있다. 그때는 저장소를 App Group 컨테이너의
**파일**로 바꿔서 재확인한다. 어차피 2~4.5주차에 App Group 컨테이너의 SwiftData로 교체할 예정이라,
그 방향으로 앞당기는 셈이 된다.

## 함정: Xcode가 App Group 엔타이틀먼트를 비워버린다

Signing & Capabilities에서 팀을 고를 때, 그 팀의 개발자 계정에 App Group이 등록돼 있지 않으면
**Xcode가 `.entitlements`의 app-groups 배열을 조용히 `<array/>`로 비운다.** 실제로 1주차에 한 번 발생했다.

이 상태가 특히 나쁜 이유는 앱은 정상적으로 빌드되고 실행되기 때문이다. 잠금화면 버튼도 눌리고,
위젯 쪽에는 엔타이틀먼트가 남아 있으면 위젯 텍스트까지 갱신된다. 그런데 앱에서는 기록이 안 보인다.

`UserDefaults(suiteName:)`은 엔타이틀먼트가 없어도 nil이 아닌 객체를 돌려주기 때문에 판단 근거가 못 된다.
그래서 `AppGroup.isAvailable`은 `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`로 판정한다.
이 API는 엔타이틀먼트가 없으면 nil을 반환한다.

**대응**: 앱과 위젯 **두 타겟 모두**에서 Signing & Capabilities → App Groups의 `group.com.dadari.app`이
체크돼 있는지 확인한다. 없으면 `+ Capability → App Groups`로 추가한다 (Xcode가 개발자 계정에도 등록해준다).
그 뒤 `Config/Dadari.entitlements`와 `Config/DadariWidget.entitlements`가 비워지지 않았는지
git diff로 확인하는 습관을 들인다.

## 남은 이슈 / 다음 단계로 넘길 것

- **다른 날짜 기록 경로**: PRD 4.1의 "다른 날짜로 기록할 때만 앱이 열리고 캘린더 피커로 전환"은 이번 스파이크 범위 밖이다.
  위젯의 `widgetURL` / `Link`로 딥링크를 열고 앱에서 라우팅하는 구조가 되며, 5~8주차 위젯 정식 UI 단계에서 붙인다.
- **저장소 교체**: `SpikeRecordStore`(UserDefaults)는 2~4.5주차에 App Group 컨테이너의 SwiftData로 교체한다.
  이때 위젯 익스텐션에서도 같은 `ModelContainer`를 열 수 있는지 별도 확인이 필요하다.
- **위젯 갱신 예산**: 현재 타임라인 정책은 `.never`이고 인텐트 실행 시점에만 갱신한다.
  정식 위젯은 D-day가 매일 바뀌므로 자정 기준 타임라인 엔트리를 만들어야 한다.
