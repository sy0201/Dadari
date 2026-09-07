import SwiftUI

/// 최초 실행 흐름. 앱 소개 → 주기 입력 → 알림 프리퍼미션 → HealthKit 프리퍼미션.
///
/// 시스템 권한 팝업만 띄우면 왜 필요한지 몰라 거부율이 높아지므로,
/// 각 권한마다 먼저 이유를 설명하는 화면을 둔다(UX-설계 6번).
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var model = OnboardingViewModel()

    var body: some View {
        ZStack {
            DadariColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                ScrollView {
                    stepContent
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                }

                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .task { await model.refreshPermissionStatuses() }
        .alert("알림", isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button("확인") { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
    }

    // MARK: - 진행 표시

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= model.step.rawValue
                          ? DadariColor.accent
                          : DadariColor.line)
                    .frame(height: 3)
            }
        }
        .accessibilityLabel("\(model.step.rawValue + 1)단계 / \(OnboardingStep.allCases.count)단계")
    }

    // MARK: - 단계별 본문

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .intro:
            introStep
        case .cycleInput:
            cycleInputStep
        case .notificationPermission:
            notificationStep
        case .healthKitPermission:
            healthKitStep
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            MoonPhaseView(fullness: 0.72, diameter: 96)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 36)

            Text("다달이")
                .font(DadariFont.wordmark(size: 30))
                .foregroundStyle(DadariColor.ink)
                .padding(.bottom, 12)

            Text("잠금화면에서 탭 한 번으로\n생리 시작일과 종료일을 기록해요.")
                .font(.system(size: 17))
                .foregroundStyle(DadariColor.ink)
                .lineSpacing(6)
                .padding(.bottom, 20)

            Text("앱을 찾아 열고 캘린더까지 들어갈 필요 없어요. 기록이 쌓이면 다음 예정일과 가임기를 예측해 드려요.")
                .font(.system(size: 14))
                .foregroundStyle(DadariColor.inkSoft)
                .lineSpacing(5)
        }
    }

    private var cycleInputStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle("마지막 생리 시작일을\n알려주세요")
            stepDescription("첫 예측의 기준이 돼요. 정확하지 않아도 괜찮고, 나중에 설정에서 바꿀 수 있어요.")

            DatePicker(
                "마지막 생리 시작일",
                selection: $model.lastPeriodStartDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(DadariColor.accent)
            .padding(.bottom, 24)

            stepperRow(
                title: "평균 주기",
                value: $model.cycleLength,
                range: model.cycleLengthRange,
                unit: "일"
            )
            stepperRow(
                title: "생리 기간",
                value: $model.periodLength,
                range: model.periodLengthRange,
                unit: "일"
            )

            Text("잘 모르겠으면 그대로 두세요. 기록이 두 번 쌓이면 실제 간격으로 예측해요.")
                .font(.system(size: 13))
                .foregroundStyle(DadariColor.inkSoft)
                .padding(.top, 12)
        }
    }

    private var notificationStep: some View {
        permissionStep(
            title: "예정일 전에\n미리 알려드릴까요?",
            description: "예정일 3일 전과 1일 전에 알림을 보내요. 서버 없이 기기 안에서만 처리되고, 알림 내용에 생리라는 말은 쓰지 않아요.",
            isGranted: model.notificationStatus.isAuthorized,
            grantedText: "알림을 받아요",
            deniedText: model.notificationStatus == .denied
                ? "설정 > 알림 > 다달이에서 다시 켤 수 있어요"
                : nil,
            action: { await model.requestNotificationPermission() }
        )
    }

    private var healthKitStep: some View {
        permissionStep(
            title: "건강 앱에도\n기록을 남길까요?",
            description: "기록한 주기를 건강 앱의 주기 추적에 저장해요. 다른 건강 기록과 함께 볼 수 있고, 앱 데이터가 잘못돼도 기록이 남아요. 읽기 권한은 요청하지 않아요.",
            isGranted: model.healthKitStatus == .authorized,
            grantedText: "건강 앱에 저장해요",
            deniedText: model.healthKitStatus == .denied
                ? "건강 앱 > 프로필 > 앱 및 서비스 > 다달이에서 다시 켤 수 있어요"
                : nil,
            action: { await model.requestHealthKitPermission() }
        )
    }

    // MARK: - 공통 조각

    private func permissionStep(
        title: String,
        description: String,
        isGranted: Bool,
        grantedText: String,
        deniedText: String?,
        action: @escaping () async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle(title)
            stepDescription(description)

            if isGranted {
                Label(grantedText, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DadariColor.accentDeep)
                    .padding(.top, 8)
            } else {
                Button("허용하기") {
                    Task { await action() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.isRequestingPermission)
                .padding(.top, 8)

                if let deniedText {
                    Text(deniedText)
                        .font(.system(size: 13))
                        .foregroundStyle(DadariColor.accent2Deep)
                        .padding(.top, 12)
                }
            }
        }
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(DadariColor.ink)
            .lineSpacing(4)
            .padding(.bottom, 12)
    }

    private func stepDescription(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(DadariColor.inkSoft)
            .lineSpacing(5)
            .padding(.bottom, 24)
    }

    private func stepperRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String
    ) -> some View {
        // 수치는 스테퍼로 받는다. 자유 텍스트 입력은 쓰지 않는다(CLAUDE.md 원칙 3).
        Stepper(value: value, in: range) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(DadariColor.ink)
                Spacer()
                Text("\(value.wrappedValue)\(unit)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DadariColor.accentDeep)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(DadariColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.bottom, 10)
    }

    // MARK: - 하단

    private var footer: some View {
        VStack(spacing: 0) {
            Button(primaryTitle) { handlePrimary() }
                .buttonStyle(PrimaryButtonStyle(isEnabled: isPrimaryEnabled))
                .disabled(!isPrimaryEnabled)

            if isPermissionStep {
                Button("나중에 할게요") { handlePrimary() }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var isPermissionStep: Bool {
        model.step == .notificationPermission || model.step == .healthKitPermission
    }

    private var primaryTitle: String {
        model.isLastStep ? "시작하기" : "다음"
    }

    private var isPrimaryEnabled: Bool {
        model.step == .cycleInput ? model.isLastPeriodStartDateValid() : true
    }

    private func handlePrimary() {
        guard model.isLastStep else {
            model.advance()
            return
        }
        if model.complete() {
            onFinish()
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
