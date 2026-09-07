import SwiftUI

/// 설정 화면. PRD 5.4의 세 가지(평균 주기 수동 조정, 알림, HealthKit 토글)를 담는다.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var model = SettingsViewModel()
    @State private var isDevDashboardPresented = false

    var body: some View {
        NavigationStack {
            Form {
                cycleSection
                notificationSection
                healthKitSection
                aboutSection
            }
            .tint(DadariColor.accent)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .task { await model.reload() }
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
    }

    // MARK: - 주기

    private var cycleSection: some View {
        Section {
            DatePicker(
                "마지막 생리 시작일",
                selection: Binding(
                    get: { model.settings.lastPeriodStartDate ?? Date() },
                    set: { model.updateLastPeriodStartDate($0) }
                ),
                in: ...Date(),
                displayedComponents: .date
            )

            Stepper(value: Binding(
                get: { model.settings.estimatedCycleLength },
                set: { model.updateCycleLength($0) }
            ), in: model.cycleLengthRange) {
                LabeledContent("평균 주기", value: "\(model.settings.estimatedCycleLength)일")
            }

            Stepper(value: Binding(
                get: { model.settings.estimatedPeriodLength },
                set: { model.updatePeriodLength($0) }
            ), in: model.periodLengthRange) {
                LabeledContent("생리 기간", value: "\(model.settings.estimatedPeriodLength)일")
            }
        } header: {
            Text("주기")
        } footer: {
            Text("기록이 두 번 이상 쌓이면 이 값 대신 실제 기록 간격으로 예측해요.")
        }
    }

    // MARK: - 알림

    private var notificationSection: some View {
        Section {
            Toggle("예정일 알림", isOn: Binding(
                get: { model.settings.notificationEnabled },
                set: { enabled in Task { await model.setNotificationEnabled(enabled) } }
            ))

            if model.settings.notificationEnabled {
                ForEach(model.selectableDaysBefore, id: \.self) { days in
                    Toggle("D-\(days) 알림", isOn: Binding(
                        get: { model.isDayBeforeSelected(days) },
                        set: { _ in model.toggleDayBefore(days) }
                    ))
                }
            }

            if model.notificationStatus == .denied {
                Text("시스템 알림 권한이 꺼져 있어요. 설정 > 알림 > 다달이에서 켜주세요.")
                    .font(.footnote)
                    .foregroundStyle(DadariColor.accent2Deep)
            }
        } header: {
            Text("알림")
        } footer: {
            Text("예정일 기준으로 오전 9시에 보내요. 서버 없이 기기 안에서만 처리돼요.")
        }
    }

    // MARK: - 건강 앱

    private var healthKitSection: some View {
        Section {
            Toggle("건강 앱에 기록 저장", isOn: Binding(
                get: { model.settings.healthKitSyncEnabled },
                set: { enabled in Task { await model.setHealthKitEnabled(enabled) } }
            ))
            .disabled(!model.isHealthKitAvailable)

            LabeledContent("쓰기 권한") {
                Text(healthKitStatusText)
                    .foregroundStyle(model.healthKitStatus == .authorized ? .green : DadariColor.inkSoft)
            }

            if model.healthKitStatus == .denied {
                Button("건강 앱 열기") {
                    if let url = URL(string: "x-apple-health://") { openURL(url) }
                }
            }
        } header: {
            Text("건강 앱")
        } footer: {
            Text("읽기 권한은 요청하지 않아요. 기록을 내보내기만 해요.")
        }
    }

    private var healthKitStatusText: String {
        guard model.isHealthKitAvailable else { return "사용 불가" }
        switch model.healthKitStatus {
        case .authorized: return "허용됨"
        case .denied: return "거부됨"
        case .notDetermined: return "미결정"
        }
    }

    // MARK: - 정보

    private var aboutSection: some View {
        Section("정보") {
            LabeledContent("버전", value: appVersion)
            #if DEBUG
            Button("개발용 대시보드") { isDevDashboardPresented = true }
            #endif
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
