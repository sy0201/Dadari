# 다달이 (Dadari)

생리주기 관리 iOS 앱. 잠금화면에서 탭 한 번으로 생리 시작일/종료일을 기록하는 것이 핵심이다.

- 기획: [PRD.md](PRD.md)
- UX 설계: [UX-설계.md](UX-설계.md)
- 1주차 위젯 기술 스파이크: [SPIKE.md](SPIKE.md)

## 현재 상태

PRD 10번 일정 **2~4.5주차 진행 중.**

- **1주차 완료**: 레포/CI 셋업, 위젯 기술 스파이크. 잠금화면에서 앱을 열지 않고 기록하는
  핵심 동선이 실기기에서 검증됐다 ([SPIKE.md](SPIKE.md)).
- **2주차 완료**: CloudKit 대응 데이터 모델, 기록/예측 로직, XCTest, HealthKit 쓰기 연동.
  스파이크용 UserDefaults 저장소를 App Group 컨테이너의 SwiftData로 교체했다.
- **5~8주차 진행 중**: 목업(`ui-mockup.html`) 기준으로 홈 화면과 위젯 UI 구현.

개발용 대시보드(`DevDashboardView`)는 워드마크를 길게 누르면 열린다. 실기기 확인용이다.

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
Dadari/                    앱 타겟 전용 소스
  Design/                    폰트
  Views/                     홈 화면 구성 요소
  Resources/Fonts/           고운바탕 서브셋 (OFL-1.1)
DadariWidget/              위젯 익스텐션 전용 소스
DadariShared/              앱 + 위젯이 함께 컴파일하는 공유 소스
  Models/                    SwiftData 모델 + 값 타입 스냅샷
  Persistence/               ModelContainer, 기록 저장소
  Design/                    색상 팔레트, 문페이즈 뷰
  Prediction/                CyclePredictionService, CycleCalendar
  Health/                    HealthKit 쓰기
DadariTests/               유닛 테스트
Config/                    엔타이틀먼트, 위젯 Info.plist
Scripts/                   CI 보조 스크립트
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

## 설계 메모

- **CloudKit 대응**: 지금은 CloudKit을 켜지 않지만 모든 SwiftData 속성이 옵셔널이거나
  기본값을 갖고, `@Attribute(.unique)`를 쓰지 않는다. v1.1에서 `cloudKitDatabase`만
  바꾸면 마이그레이션 없이 동기화를 켤 수 있다 (PRD 6.3).
- **예측 로직 분리**: `CyclePredictionService`는 저장소와 UI를 모르고 값 타입만 받는다.
  컨테이너를 띄우지 않고 케이스별로 검증한다.
- **폰트 서브셋**: 고운바탕 원본은 두 벌 합쳐 16MB라 앱에서 실제로 쓰는 글자만 남겨
  26KB로 줄여 번들에 넣는다(`Scripts/subset_fonts.py`). 고운바탕으로 새 문구를 표시하려면
  스크립트의 글자 목록을 갱신해야 한다.
- **HealthKit은 지연 동기화**: 잠금화면 기록은 위젯 익스텐션 프로세스에서 일어나는데
  거기서 HealthKit을 쓰려면 별도 권한과 잠금 상태 처리가 필요하다. 위젯은 저장만 하고,
  앱이 앞으로 나올 때 `HealthKitSyncCoordinator`가 밀린 기록을 내보낸다.

## 작업 흐름

1인 프로젝트지만 feature 브랜치 → PR → `main` 머지 흐름을 쓴다 (PRD 7.2).
