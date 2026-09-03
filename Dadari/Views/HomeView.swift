import SwiftUI
import WidgetKit

/// 홈 화면. 목업(ui-mockup.html)의 구성을 그대로 옮겼다.
///
/// 위에서부터 워드마크 → 주간 스트립 → 문페이즈 히어로 → 오늘 기록하기 카드
/// → 라인아트 스탯 3개 → 최근 기록 순으로 쌓는다(PRD 3.5).
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = HomeViewModel()
    @State private var isDevDashboardPresented = false
    @State private var editingRecord: PeriodRecordSnapshot?

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
        .onAppear { model.reload() }
        .onChange(of: scenePhase) { _, phase in
            // 잠금화면 위젯에서 기록하고 앱으로 돌아왔을 때 최신 상태를 다시 읽는다.
            guard phase == .active else { return }
            model.reload()
            // 위젯이 옛 타임라인을 들고 있는 경우를 줄인다. 앱을 새로 설치한 직후에는
            // 위젯이 이전 빌드 기준으로 남아 있을 수 있어서, 앱이 앞으로 나올 때마다
            // 갱신을 요청한다. 익스텐션 자체가 옛 바이너리에 물린 경우는 이걸로도
            // 풀리지 않으므로, 그때는 위젯을 지웠다 다시 추가해야 한다(SPIKE.md).
            WidgetCenter.shared.reloadAllTimelines()
            Task { await DadariEnvironment.makeHealthKitCoordinator().syncPending() }
        }
        .alert("알림", isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button("확인") { model.message = nil }
        } message: {
            Text(model.message ?? "")
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
        .sheet(isPresented: $isDevDashboardPresented) {
            // 대시보드에서 기록을 지우고 돌아오면 홈이 옛 데이터를 그대로 들고 있게 된다.
            // 시트를 닫는 것만으로는 onAppear도 scenePhase도 걸리지 않는다.
            model.reload()
        } content: {
            DevDashboardView()
        }
    }

    // MARK: - 조각

    private var wordmark: some View {
        Text("다달이")
            .font(DadariFont.wordmark())
            .foregroundStyle(DadariColor.ink)
            // 정식 화면에는 개발용 대시보드로 가는 입구를 두지 않는다.
            // 실기기 확인이 잦은 단계라 길게 눌러서만 열리게 해뒀다.
            .onLongPressGesture(minimumDuration: 1.0) {
                isDevDashboardPresented = true
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

    private func dismissPhaseGuide() {
        withAnimation(.easeOut(duration: 0.18)) {
            model.isPhaseGuidePresented = false
        }
    }
}

#Preview {
    HomeView()
}
