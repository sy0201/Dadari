import SwiftUI
import WidgetKit

/// 홈 화면. 목업(ui-mockup.html)의 구성을 그대로 옮겼다.
///
/// 위에서부터 워드마크 → 주간 스트립 → 문페이즈 히어로 → 오늘 기록하기 카드
/// → 라인아트 스탯 3개 → 최근 기록 순으로 쌓는다(PRD 3.5).
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = HomeViewModel()
    private var router: AppRouter { AppRouter.shared }
    // 시뮬레이터에서 탭 없이 상태별 스크린샷을 찍기 위한 실행 인자(SampleDataSeeder 참고).
    @State private var isSettingsPresented = {
        #if DEBUG
        return CommandLine.arguments.contains("-showSettings")
        #else
        return false
        #endif
    }()
    @State private var editingRecord: PeriodRecordSnapshot?
    // 시뮬레이터에서 탭 없이 스크린샷을 찍기 위한 실행 인자(SampleDataSeeder 참고).
    @State private var isConditionSheetPresented = {
        #if DEBUG
        return CommandLine.arguments.contains("-showCondition")
        #else
        return false
        #endif
    }()

    var body: some View {
        ZStack {
            DadariColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    wordmark

                    CycleCalendarView(
                        selectedDate: $model.selectedDate,
                        isExpanded: $model.isCalendarExpanded,
                        kindProvider: model.kind(for:)
                    )
                    .padding(.top, 14)

                    moonHero

                    RecordCardView(
                        selectedDate: model.selectedDate,
                        isToday: model.isSelectedDateToday,
                        isFuture: model.isSelectedDateInFuture(),
                        hasOngoingPeriod: model.hasOngoingPeriod,
                        existingRecord: model.recordForSelectedDate,
                        onRecord: { model.recordSelectedDate() },
                        onEdit: { editingRecord = $0 }
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                    ConditionCardView(
                        symptoms: model.condition?.orderedSymptoms ?? [],
                        isFuture: model.isSelectedDateInFuture()
                    ) {
                        isConditionSheetPresented = true
                    }
                    .padding(.bottom, 20)

                    StatRowView(
                        averageCycleLength: model.prediction?.cycleLengthUsed,
                        periodLength: model.periodLength,
                        confidence: model.prediction?.confidence
                    )
                    .padding(.bottom, 20)

                    RecentRecordsView(records: model.records) { record in
                        editingRecord = record
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }

            phaseGuideOverlay
        }
        .task {
            // scenePhase의 onChange는 초기값에는 불리지 않는다. 앱을 새로 켠 경우
            // 여기서 한 번 돌려주지 않으면 HealthKit 동기화도 알림 재예약도 일어나지 않는다.
            model.reload()
            await runForegroundWork()
        }
        .onChange(of: router.pendingRoute) { _, route in
            // 알림을 탭해 들어온 경우. 지금은 홈 하나뿐이라 오늘로 되돌리고 접는다.
            guard route != nil else { return }
            model.selectedDate = Calendar.current.startOfDay(for: Date())
            model.isCalendarExpanded = false
            model.reload()
            router.pendingRoute = nil
        }
        .onChange(of: scenePhase) { _, phase in
            // 잠금화면 위젯에서 기록하고 앱으로 돌아왔을 때 최신 상태를 다시 읽는다.
            guard phase == .active else { return }
            model.reload()
            Task { await runForegroundWork() }
        }
        .alert("알림", isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button("확인") { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
        .sheet(isPresented: $isConditionSheetPresented) {
            ConditionSheet(
                date: model.selectedDate,
                initialSymptoms: model.condition?.symptoms ?? []
            ) { symptoms in
                model.saveCondition(symptoms)
            }
        }
        .sheet(item: $editingRecord) { record in
            RecordEditorView(
                record: record,
                onSave: { start, end, flow in
                    model.update(record: record, startDate: start, endDate: end, flow: flow)
                },
                onDelete: { await model.delete(record: record) }
            )
        }
        .sheet(isPresented: $isSettingsPresented) {
            // 설정에서 주기 값을 바꾸면 예측이 달라진다. 시트를 닫는 것만으로는
            // onAppear도 scenePhase도 걸리지 않아 홈이 옛 값을 그대로 들고 있게 된다.
            model.reload()
        } content: {
            SettingsView()
        }
    }

    // MARK: - 조각

    /// 목업에는 워드마크만 있지만, 설정은 UX-설계 6번의 필수 화면이라 진입점이 필요하다.
    /// 여백을 해치지 않도록 워드마크 줄 오른쪽 끝에 작게 둔다.
    private var wordmark: some View {
        HStack {
            Text("다달이")
                .font(DadariFont.wordmark())
                .foregroundStyle(DadariColor.ink)
            Spacer()
            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(DadariColor.inkSoft)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("설정")
        }
    }

    private var moonHero: some View {
        VStack(spacing: 0) {
            MoonPhaseView(fullness: model.moonFullness, diameter: 120)
                .padding(.bottom, 12)

            HStack(spacing: 6) {
                Text(model.statusText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DadariColor.accentDeep)

                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        model.isPhaseGuidePresented = true
                    }
                } label: {
                    Text("?")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(DadariColor.inkSoft)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(DadariColor.inkSoft, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("주기 단계 안내")
            }

            Text(model.subtitleText)
                .font(.system(size: 12))
                .foregroundStyle(DadariColor.inkSoft)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var phaseGuideOverlay: some View {
        if model.isPhaseGuidePresented {
            ZStack(alignment: .top) {
                DadariColor.ink.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { dismissPhaseGuide() }

                PhaseGuidePopover()
                    .padding(.horizontal, 20)
                    .padding(.top, 150)
            }
            .transition(.opacity)
        }
    }

    /// 앱이 앞으로 나올 때마다 하는 일. 콜드 런치와 백그라운드 복귀 양쪽에서 부른다.
    private func runForegroundWork() async {
        // 위젯이 옛 타임라인을 들고 있는 경우를 줄인다. 앱을 새로 설치한 직후에는
        // 위젯이 이전 빌드 기준으로 남아 있을 수 있다. 익스텐션 자체가 옛 바이너리에
        // 물린 경우는 이걸로 풀리지 않으므로 위젯을 지웠다 다시 추가해야 한다(SPIKE.md).
        WidgetCenter.shared.reloadAllTimelines()

        // 잠금화면에서 쌓인 기록을 건강 앱으로 내보낸다.
        await DadariEnvironment.makeHealthKitCoordinator().syncPending()

        // 날짜가 지나면 예측도 바뀐다. 앱을 열 때마다 알림 날짜를 다시 맞춘다.
        await DadariEnvironment.rescheduleReminders()
    }

    private func dismissPhaseGuide() {
        withAnimation(.easeOut(duration: 0.18)) {
            model.isPhaseGuidePresented = false
        }
    }
}

#Preview {
    HomeView()
}
