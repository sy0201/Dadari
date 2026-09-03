import SwiftUI

/// 홈 화면. 목업(ui-mockup.html)의 구성을 그대로 옮겼다.
///
/// 위에서부터 워드마크 → 주간 스트립 → 문페이즈 히어로 → 오늘 기록하기 카드
/// → 라인아트 스탯 3개 → 최근 기록 순으로 쌓는다(PRD 3.5).
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = HomeViewModel()
    @State private var isDevDashboardPresented = false

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

                    RecordCardView(hasOngoingPeriod: model.hasOngoingPeriod) {
                        model.recordToday()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                    StatRowView(
                        averageCycleLength: model.prediction?.cycleLengthUsed,
                        periodLength: model.periodLength,
                        confidence: model.prediction?.confidence
                    )
                    .padding(.bottom, 20)

                    RecentRecordsView(records: model.records) { _ in
                        // 기록 수정/삭제 화면은 10~11주차 작업이다(PRD 10번).
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
        .sheet(isPresented: $isDevDashboardPresented) {
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
