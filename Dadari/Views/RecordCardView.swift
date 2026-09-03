import SwiftUI

/// 컬러 팝 카드. 화면 전체를 색으로 덮지 않고 이 카드 하나에만 포인트 컬러를 채워
/// 시선을 모은다(PRD 3.2).
struct RecordCardView: View {
    /// 카드가 대상으로 삼는 날짜. 캘린더에서 고른 날짜다.
    let selectedDate: Date
    let isToday: Bool
    let isFuture: Bool
    /// 진행 중인 주기가 있으면 종료를, 없으면 시작을 기록한다.
    let hasOngoingPeriod: Bool
    /// 그 날짜에 이미 기록이 있으면 새로 남기는 대신 수정으로 보낸다.
    let existingRecord: PeriodRecordSnapshot?
    let onRecord: () -> Void
    let onEdit: (PeriodRecordSnapshot) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(headline)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button(action: primaryAction) {
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DadariColor.accentDeep)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(DadariColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isFuture)
            .opacity(isFuture ? 0.5 : 1)
            .accessibilityLabel(accessibilityLabel)
        }
        .padding(18)
        .background(DadariColor.accent)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// 오늘이 아니면 어떤 날짜에 기록되는지 분명히 보여준다.
    private var title: String {
        if isFuture { return "아직 오지 않은 날짜" }
        return isToday ? "오늘 기록하기" : "\(selectedDate.formatted(.dateTime.month().day())) 기록하기"
    }

    private var headline: String {
        if isFuture { return "기록할 수 없어요" }
        if existingRecord != nil { return "기록됨" }
        return isToday ? "탭 한 번" : "탭 한 번"
    }

    private var buttonTitle: String {
        if existingRecord != nil { return "수정" }
        return hasOngoingPeriod ? "종료" : "기록"
    }

    private func primaryAction() {
        if let existingRecord {
            onEdit(existingRecord)
        } else {
            onRecord()
        }
    }

    private var accessibilityLabel: String {
        let dateText = selectedDate.formatted(.dateTime.month().day())
        if existingRecord != nil { return "\(dateText) 기록 수정" }
        return hasOngoingPeriod ? "\(dateText)로 생리 종료일 기록" : "\(dateText)로 생리 시작일 기록"
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
