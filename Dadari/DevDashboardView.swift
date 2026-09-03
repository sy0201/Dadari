import SwiftUI
import WidgetKit

/// 개발 중 상태를 눈으로 확인하는 화면.
///
/// 정식 홈 화면(PRD 3.5의 주간 스트립 → 문페이즈 히어로 → 기록 카드 → 스탯 → 리스트)은
/// 10~11주차 작업이다. 그때까지 이 화면이 저장소·예측·HealthKit 연동이 실제로
/// 동작하는지 확인하는 창구 역할을 한다.
struct DevDashboardView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var records: [PeriodRecordSnapshot] = []
    @State private var settings = CycleSettingsSnapshot()
    @State private var prediction: CyclePrediction?
    @State private var message: String?

    private var store: PeriodRecordStore { DadariEnvironment.recordStore }

    var body: some View {
        NavigationStack {
            List {
                appGroupSection
                predictionSection
                recordSection
                healthKitSection
                historySection
            }
            .navigationTitle("다달이 (개발용)")
            .toolbar {
                Button("새로고침", systemImage: "arrow.clockwise") { reload() }
            }
            .alert("알림", isPresented: .constant(message != nil)) {
                Button("확인") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            // 위젯에서 기록하고 앱으로 돌아왔을 때 최신 상태를 다시 읽고,
            // 잠금화면에서 쌓인 기록을 HealthKit으로 내보낸다.
            guard phase == .active else { return }
            reload()
            Task { await syncHealthKit() }
        }
    }

    // MARK: - Sections

    private var appGroupSection: some View {
        Section("App Group") {
            LabeledContent("공유 스토어") {
                Text(DadariEnvironment.isUsingSharedContainer ? "연결됨" : "실패 (인메모리 폴백)")
                    .foregroundStyle(DadariEnvironment.isUsingSharedContainer ? .green : .red)
            }
            if let path = AppGroup.containerURL?.path {
                VStack(alignment: .leading, spacing: 2) {
                    Text("컨테이너 경로").font(.caption).foregroundStyle(.secondary)
                    Text(path).font(.caption2).textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private var predictionSection: some View {
        Section("예측") {
            if let prediction {
                LabeledContent("상태", value: statusText(prediction.status))
                LabeledContent("다음 예정일", value: dateText(prediction.nextPeriodStartDate))
                LabeledContent("배란 예상일", value: dateText(prediction.ovulationDate))
                LabeledContent(
                    "가임기",
                    value: "\(dateText(prediction.fertileWindow.lowerBound)) ~ \(dateText(prediction.fertileWindow.upperBound))"
                )
                LabeledContent("주기 길이", value: "\(prediction.cycleLengthUsed)일")
                LabeledContent("근거", value: basisText(prediction.basis))
                LabeledContent("신뢰도", value: prediction.confidence == .high ? "높음" : "낮음")
            } else {
                Text("예측할 기준 날짜가 없습니다. 기록을 남기거나 온보딩 값을 넣어주세요.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recordSection: some View {
        Section("앱에서 기록 (source: app)") {
            Button("오늘 시작일 기록") { record(.start) }
            Button("오늘 종료일 기록") { record(.end) }
            Button("온보딩 값 채우기 (28일 전 시작)") { seedOnboarding() }
        }
    }

    private var healthKitSection: some View {
        Section("HealthKit") {
            LabeledContent("연동", value: settings.healthKitSyncEnabled ? "켜짐" : "꺼짐")
            Button(settings.healthKitSyncEnabled ? "지금 동기화" : "연동 켜고 동기화") {
                Task { await enableHealthKit() }
            }
        }
    }

    private var historySection: some View {
        Section("기록 \(records.count)건") {
            if records.isEmpty {
                Text("기록 없음. 잠금화면 위젯에서 눌러보세요.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rangeText(record))
                        Text("\(record.source.label) · HealthKit \(record.healthKitSyncedAt == nil ? "대기" : "동기화됨")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: delete)
                Button("전체 삭제", role: .destructive) {
                    perform { try store.deleteAll() }
                }
            }
        }
    }

    // MARK: - Actions

    private func record(_ kind: RecordPeriodIntentRunner.Kind) {
        perform {
            switch kind {
            case .start:
                try store.recordPeriodStart(on: Date(), source: .app)
            case .end:
                try store.recordPeriodEnd(on: Date(), source: .app)
            }
        }
    }

    private func seedOnboarding() {
        perform {
            let start = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
            try store.updateSettings { $0.lastPeriodStartDate = Calendar.current.startOfDay(for: start) }
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.map { records[$0].id }
        perform {
            for id in ids { try store.delete(id: id) }
        }
    }

    private func enableHealthKit() async {
        do {
            let summary = try await DadariEnvironment.makeHealthKitCoordinator().enableAndSync()
            message = summary.skipped
                ? "이 기기에서는 HealthKit을 쓸 수 없어요. 실기기에서 확인해 주세요."
                : "동기화 완료: \(summary.synced)건 성공, \(summary.failed)건 실패"
        } catch {
            message = error.localizedDescription
        }
        reload()
    }

    private func syncHealthKit() async {
        await DadariEnvironment.makeHealthKitCoordinator().syncPending()
        reload()
    }

    /// 저장소 호출을 한 곳에서 감싸 오류를 화면에 띄우고 위젯을 갱신한다.
    private func perform(_ body: () throws -> Void) {
        do {
            try body()
            WidgetCenter.shared.reloadAllTimelines()
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    private func reload() {
        records = (try? store.records()) ?? []
        settings = (try? store.settings()) ?? CycleSettingsSnapshot()
        prediction = DadariEnvironment.currentPrediction()
    }

    // MARK: - Formatting

    private func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func rangeText(_ record: PeriodRecordSnapshot) -> String {
        guard let end = record.endDate else {
            return "\(dateText(record.startDate)) ~ 진행 중"
        }
        return "\(dateText(record.startDate)) ~ \(dateText(end))"
    }

    private func statusText(_ status: CyclePrediction.Status) -> String {
        switch status {
        case .upcoming(let days):
            return days == 0 ? "오늘" : "D-\(days)"
        case .overdue(let days):
            return "예정일 +\(days)일"
        case .stale(let days):
            return "카운트다운 중단 (+\(days)일)"
        }
    }

    private func basisText(_ basis: CyclePrediction.Basis) -> String {
        switch basis {
        case .estimate:
            return "온보딩 추정값"
        case .history(let count):
            return "실제 기록 \(count)주기"
        }
    }
}

#Preview {
    DevDashboardView()
}
