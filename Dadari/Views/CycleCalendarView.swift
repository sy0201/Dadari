import SwiftUI

/// 홈 상단의 주간 스트립. 탭하면 월간 그리드로 펼쳐진다(PRD 3.2).
///
/// 주간은 "이번 주"가 아니라 **선택한 날짜부터 시작하는 7일**이다.
/// 월간에서 날짜를 탭하면 그 날짜를 시작점으로 하는 새 일주일로 다시 접힌다.
/// 애플 캘린더/건강 앱과 같은 패턴이라 학습 비용이 낮다.
struct CycleCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var isExpanded: Bool

    let kindProvider: (Date) -> CycleDayKind

    private var calendar: Calendar { .current }
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                monthPanel
            } else {
                weekRow
            }
        }
    }

    // MARK: - 헤더

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
        } label: {
            HStack {
                Text(monthLabel)
                    .font(DadariFont.serif(size: 13.5))
                    .foregroundStyle(DadariColor.ink)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DadariColor.inkSoft)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.bottom, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(monthLabel), \(isExpanded ? "월간 보기" : "주간 보기")")
        .accessibilityHint("탭하면 \(isExpanded ? "주간" : "월간")으로 바뀝니다")
    }

    private var monthLabel: String {
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        return "\(components.year ?? 0)년 \(components.month ?? 0)월"
    }

    // MARK: - 주간

    private var weekRow: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                let weekday = calendar.component(.weekday, from: date) - 1
                Button {
                    select(date)
                } label: {
                    VStack(spacing: 5) {
                        Text(weekdaySymbols[weekday])
                            .font(.system(size: 9))
                            .foregroundStyle(DadariColor.inkSoft)
                        DayMarker(
                            date: date,
                            kind: kindProvider(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            shape: .circle
                        )
                        .frame(width: 27, height: 27)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: date))
            }
        }
        .padding(.bottom, 6)
    }

    /// 선택한 날짜부터 7일. 목업의 `addDays(selectedDate, i)`와 같다.
    private var weekDates: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfSelectedDay) }
    }

    // MARK: - 월간

    private var monthPanel: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 3) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 9.5))
                        .foregroundStyle(DadariColor.inkSoft)
                        .padding(.bottom, 6)
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button {
                            select(date)
                            withAnimation(.easeInOut(duration: 0.25)) { isExpanded = false }
                        } label: {
                            DayMarker(
                                date: date,
                                kind: kindProvider(date),
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                shape: .roundedRectangle
                            )
                            .aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(for: date))
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            legend
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    /// 앞쪽 빈칸을 nil로 채운 그 달의 날짜들.
    private var monthCells: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else { return [] }
        let first = monthInterval.start
        let leadingBlanks = calendar.component(.weekday, from: first) - 1
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 0

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: first))
        }
        return cells
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(.loggedPeriod, "실제 생리")
            legendItem(.predictedPeriod, "예측 생리")
            legendItem(.fertile, "가임기")
            legendItem(.pms, "PMS")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private func legendItem(_ kind: CycleDayKind, _ label: String) -> some View {
        HStack(spacing: 4) {
            LegendSwatch(kind: kind)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DadariColor.inkSoft)
        }
    }

    // MARK: - Helpers

    private var startOfSelectedDay: Date {
        calendar.startOfDay(for: selectedDate)
    }

    private func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    private func accessibilityLabel(for date: Date) -> String {
        let day = date.formatted(.dateTime.month().day())
        let kind = kindProvider(date)
        return kind == .ordinary ? day : "\(day), \(kind.label)"
    }
}

extension CycleDayKind {
    var label: String {
        switch self {
        case .loggedPeriod: return "실제 생리"
        case .predictedPeriod: return "예측 생리"
        case .fertile: return "가임기"
        case .pms: return "PMS"
        case .ordinary: return "평상시"
        }
    }
}
