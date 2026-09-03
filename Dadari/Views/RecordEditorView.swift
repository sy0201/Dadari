import SwiftUI

/// 기록 수정/삭제 화면. PRD 4.1의 MVP 항목이다.
///
/// 잠금화면이 주 입력 경로라 오탭 가능성이 높아서, 되돌릴 수 있는 경로가 반드시 필요하다.
/// 날짜는 캘린더 탭으로 고르고 생리량은 세그먼트로 받는다. 자유 텍스트 입력은 쓰지 않는다
/// (CLAUDE.md 원칙 3).
struct RecordEditorView: View {
    let record: PeriodRecordSnapshot
    let onSave: (Date, Date?, FlowLevel?) -> Bool
    let onDelete: () async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var flow: FlowLevel?
    @State private var isDeleteConfirmPresented = false
    @State private var isDeleting = false

    init(
        record: PeriodRecordSnapshot,
        onSave: @escaping (Date, Date?, FlowLevel?) -> Bool,
        onDelete: @escaping () async -> Bool
    ) {
        self.record = record
        self.onSave = onSave
        self.onDelete = onDelete
        _startDate = State(initialValue: record.startDate)
        _hasEndDate = State(initialValue: record.endDate != nil)
        _endDate = State(initialValue: record.endDate ?? record.startDate)
        _flow = State(initialValue: record.flow)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("시작일") {
                    DatePicker(
                        "시작일",
                        selection: $startDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(DadariColor.accent)
                }

                Section("종료일") {
                    Toggle("종료일 기록됨", isOn: $hasEndDate)
                        .tint(DadariColor.accent)
                    if hasEndDate {
                        DatePicker(
                            "종료일",
                            selection: $endDate,
                            in: startDate...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(DadariColor.accent)
                    }
                }

                Section("생리량") {
                    Picker("생리량", selection: $flow) {
                        Text("선택 안 함").tag(FlowLevel?.none)
                        ForEach(FlowLevel.allCases, id: \.self) { level in
                            Text(level.label).tag(FlowLevel?.some(level))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(role: .destructive) {
                        isDeleteConfirmPresented = true
                    } label: {
                        Text("이 기록 삭제")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isDeleting)
                }
            }
            .navigationTitle("기록 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                }
            }
            .confirmationDialog(
                "이 기록을 삭제할까요?",
                isPresented: $isDeleteConfirmPresented,
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) { delete() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("건강 앱에 내보낸 기록이면 거기서도 함께 지워져요.")
            }
        }
    }

    private func save() {
        // 저장에 실패하면(미래 날짜 등) 화면을 닫지 않고 남겨 사용자가 고칠 수 있게 한다.
        if onSave(startDate, hasEndDate ? endDate : nil, flow) {
            dismiss()
        }
    }

    private func delete() {
        isDeleting = true
        Task {
            let deleted = await onDelete()
            isDeleting = false
            if deleted { dismiss() }
        }
    }
}
