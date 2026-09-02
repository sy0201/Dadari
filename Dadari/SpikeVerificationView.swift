import SwiftUI
import WidgetKit

/// 1주차 스파이크 검증용 화면. 디자인은 5~8주차 이후 작업이라 여기서는 의도적으로 꾸미지 않는다.
/// 확인하려는 것은 딱 두 가지다.
/// 1. 잠금화면 위젯 버튼이 앱을 열지 않고 기록을 남기는가
/// 2. 그 기록이 App Group을 통해 앱 프로세스에서 그대로 보이는가
struct SpikeVerificationView: View {
    private let store = SpikeRecordStore.shared

    @Environment(\.scenePhase) private var scenePhase
    @State private var entries: [SpikeEntry] = []

    var body: some View {
        NavigationStack {
            List {
                Section("App Group") {
                    LabeledContent("컨테이너") {
                        Text(store.isUsingSharedContainer ? "공유됨" : "실패 (로컬 폴백)")
                            .foregroundStyle(store.isUsingSharedContainer ? .green : .red)
                    }
                    LabeledContent("식별자", value: AppGroup.identifier)
                        .font(.caption)
                }

                Section("앱에서 기록 (source: app)") {
                    Button("시작일 기록") { record(.start) }
                    Button("종료일 기록") { record(.end) }
                }

                Section("기록 \(entries.count)건") {
                    if entries.isEmpty {
                        Text("기록 없음. 잠금화면 위젯에서 눌러보세요.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            row(for: entry)
                        }
                    }
                }

                Section {
                    Button("전체 삭제", role: .destructive) {
                        store.removeAll()
                        WidgetCenter.shared.reloadAllTimelines()
                        reload()
                    }
                }
            }
            .navigationTitle("다달이 스파이크")
            .toolbar {
                Button("새로고침", systemImage: "arrow.clockwise") { reload() }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            // 위젯에서 기록하고 앱으로 돌아왔을 때 최신 상태를 다시 읽는다.
            if phase == .active { reload() }
        }
    }

    private func row(for entry: SpikeEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.kind.label) · \(entry.day.formatted(date: .abbreviated, time: .omitted))")
            Text("\(entry.source.rawValue) · \(entry.recordedAt.formatted(date: .omitted, time: .standard))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func record(_ kind: SpikeEntryKind) {
        store.record(kind, source: .app)
        WidgetCenter.shared.reloadAllTimelines()
        reload()
    }

    private func reload() {
        entries = store.entries()
    }
}

#Preview {
    SpikeVerificationView()
}
