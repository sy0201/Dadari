# 다달이 (Dadari)

생리주기 관리 iOS 앱. 잠금화면에서 탭 한 번으로 생리 시작일/종료일을 기록하는 것이 핵심이다.

- 기획: [PRD.md](PRD.md)
- UX 설계: [UX-설계.md](UX-설계.md)
- 1주차 위젯 기술 스파이크: [SPIKE.md](SPIKE.md)

## 현재 상태

PRD 10번 일정 **1주차** 완료 단계. 레포/CI 셋업과 위젯 기술 스파이크까지 되어 있고,
데이터 모델·예측 로직·정식 UI는 아직 없다.

## 요구 환경

- Xcode 16 이상 (`project.pbxproj`가 동기화 폴더 그룹을 사용)
- iOS 17.0 이상 (인터랙티브 위젯의 `Button(intent:)`가 iOS 17부터)

## 타겟 구성

| 타겟 | 번들 ID | 설명 |
|---|---|---|
| `Dadari` | `com.dadari.app` | SwiftUI 앱 |
| `DadariWidget` | `com.dadari.app.Widget` | WidgetKit 익스텐션 (잠금화면 위젯) |
| `DadariTests` | `com.dadari.app.Tests` | XCTest 유닛 테스트 |

App Group `group.com.dadari.app`으로 앱과 위젯이 데이터를 공유한다.

## 폴더 구조

```
Dadari/          앱 타겟 전용 소스
DadariWidget/    위젯 익스텐션 전용 소스
DadariShared/    앱 + 위젯이 함께 컴파일하는 공유 소스 (App Intents, 저장소)
DadariTests/     유닛 테스트
Config/          엔타이틀먼트, 위젯 Info.plist
```

`Dadari`, `DadariWidget`, `DadariShared`, `DadariTests`는 Xcode 16의 동기화 폴더 그룹이라
**파일을 추가해도 `project.pbxproj`를 건드릴 필요가 없다.** 폴더에 넣으면 해당 타겟에 자동으로 포함된다.

## 빌드 / 테스트

```bash
xcodebuild build \
  -project Dadari.xcodeproj -scheme Dadari \
  -destination 'platform=iOS Simulator,name=iPhone 16'

xcodebuild test \
  -project Dadari.xcodeproj -scheme Dadari \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

`Dadari` 스킴은 앱과 위젯 익스텐션을 함께 빌드하고 appex를 앱에 임베드한다.

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) — `main`/`develop` push와 `main` 대상 PR에서
앱·위젯 빌드와 유닛 테스트를 실행한다. 시뮬레이터는 러너 이미지 변경에 깨지지 않도록
이름이 아니라 UDID로 동적으로 찾는다.

## 작업 흐름

1인 프로젝트지만 feature 브랜치 → PR → `main` 머지 흐름을 쓴다 (PRD 7.2).
