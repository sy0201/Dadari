import SwiftUI

/// 컬러 팝 카드. 화면 전체를 색으로 덮지 않고 이 카드 하나에만 포인트 컬러를 채워
/// 시선을 모은다(PRD 3.2).
struct RecordCardView: View {
    /// 진행 중인 주기가 있으면 종료를, 없으면 시작을 기록한다.
    let hasOngoingPeriod: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("오늘 기록하기")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("탭 한 번")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DadariColor.accentDeep)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(DadariColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasOngoingPeriod ? "오늘 날짜로 생리 종료일 기록" : "오늘 날짜로 생리 시작일 기록")
        }
        .padding(18)
        .background(DadariColor.accent)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// 목업 버튼은 "기록"이지만, 시작과 종료 중 무엇이 일어날지 누르기 전에 알 수 있어야 한다.
    private var buttonTitle: String {
        hasOngoingPeriod ? "종료" : "기록"
    }
}

/// 최근 기록 리스트. 목업의 `.group` / `.row`.
struct RecentRecordsView: View {
    let records: [PeriodRecordSnapshot]
    let onSelect: (PeriodRecordSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("최근 기록")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DadariColor.inkMuted)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                if records.isEmpty {
                    Text("아직 기록이 없어요. 잠금화면 위젯에서 탭 한 번으로 남길 수 있어요.")
                        .font(.system(size: 13))
                        .foregroundStyle(DadariColor.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                } else {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        Button {
                            onSelect(record)
                        } label: {
                            HStack {
                                Text(rangeText(record))
                                    .font(.system(size: 14))
                                    .foregroundStyle(DadariColor.ink)
                                Spacer()
                                Text(durationText(record))
                                    .font(.system(size: 13))
                                    .foregroundStyle(DadariColor.inkMuted)
                            }
                            .padding(.vertical, 13)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < records.count - 1 {
                            DadariColor.background.frame(height: 1)
                        }
                    }
                }
            }
            .background(DadariColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func rangeText(_ record: PeriodRecordSnapshot) -> String {
        let start = record.startDate.formatted(.dateTime.month().day())
        guard let end = record.endDate else { return "\(start) – 진행 중" }
        return "\(start) – \(end.formatted(.dateTime.month().day()))"
    }

    private func durationText(_ record: PeriodRecordSnapshot) -> String {
        guard let end = record.endDate else { return "기록 중" }
        let days = Calendar.current.dateComponents([.day], from: record.startDate, to: end).day ?? 0
        return "\(days + 1)일"
    }
}
