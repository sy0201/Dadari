import SwiftUI

/// 컨디션 기록 바텀시트. UX-설계 6번의 필수 화면이다.
///
/// 별도 화면이 아니라 바텀시트로 띄운다(PRD 3.5). 증상은 칩으로 고르고, 정도나 자유 입력은
/// 두지 않는다. PRD 12번이 "무거운 증상 분석은 지양"하라고 못박고 있어서, 고르고 끝나는
/// 수준으로 유지한다.
struct ConditionSheet: View {
    let date: Date
    let initialSymptoms: Set<Symptom>
    /// 저장 성공 여부를 돌려준다. 실패하면 시트를 닫지 않는다.
    let onSave: (Set<Symptom>) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Symptom>

    init(
        date: Date,
        initialSymptoms: Set<Symptom>,
        onSave: @escaping (Set<Symptom>) -> Bool
    ) {
        self.date = date
        self.initialSymptoms = initialSymptoms
        self.onSave = onSave
        _selected = State(initialValue: initialSymptoms)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DadariColor.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Text(dateText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DadariColor.inkSoft)
                        .padding(.bottom, 4)

                    Text("오늘 어땠나요?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DadariColor.ink)
                        .padding(.bottom, 20)

                    FlowLayout(spacing: 8, lineSpacing: 10) {
                        ForEach(Symptom.allCases) { symptom in
                            chip(for: symptom)
                        }
                    }

                    Spacer(minLength: 20)

                    Text(selected.isEmpty
                         ? "아무것도 고르지 않고 저장하면 그날 기록이 지워져요."
                         : "\(selected.count)개 선택")
                        .font(.system(size: 12))
                        .foregroundStyle(DadariColor.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .navigationTitle("컨디션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if onSave(selected) { dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var dateText: String {
        date.formatted(.dateTime.month().day().weekday(.wide))
    }

    /// 증상 칩. 보조 포인트 컬러를 쓴다. 기록이 두 번째 액션이기 때문이다(PRD 3.3).
    private func chip(for symptom: Symptom) -> some View {
        let isOn = selected.contains(symptom)
        return Button {
            if isOn {
                selected.remove(symptom)
            } else {
                selected.insert(symptom)
            }
        } label: {
            Text(symptom.label)
                .font(.system(size: 14, weight: isOn ? .bold : .regular))
                .foregroundStyle(isOn ? DadariColor.accent2Deep : DadariColor.ink)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(isOn ? DadariColor.accent2Soft : DadariColor.card)
                .overlay(
                    Capsule().strokeBorder(
                        isOn ? DadariColor.accent2 : .clear,
                        lineWidth: 1.5
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symptom.label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

#Preview {
    ConditionSheet(date: Date(), initialSymptoms: [.cramps, .fatigue]) { _ in true }
}
