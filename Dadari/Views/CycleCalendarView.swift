import SwiftUI

/// 홈 상단의 주간 스트립. 탭하면 월간 그리드로 펼쳐진다(PRD 3.2).
///
/// 주간은 **선택한 날짜가 속한 달력 주(일~토)**를 보여주고, 좌우로 밀어 주를 옮긴다.
/// 애플 건강 앱과 같은 방식이다.
///
/// 처음에는 "탭한 날짜를 시작점으로 하는 일주일"로 잡았지만, 그렇게 하면 고른 날짜가
/// 늘 맨 왼쪽으로 오면서 요일 열이 매번 어긋난다. 같은 주 안에서 날짜를 옮길 때마다
/// 격자가 흔들려 위치를 가늠하기 어려웠다. 실제로 써 본 뒤 달력 주 고정으로 바꿨고,
/// PRD 3.2와 목업(ui-mockup.html)도 그에 맞춰 갱신했다.
///
/// 이동 범위: 과거는 제한이 없고, 미래는 **오늘이 속한 달의 다음 달 말일까지**만 본다.
/// 지난 기록을 되짚어 보는 건 필요하지만, 아주 먼 미래의 예측은 의미가 없기 때문이다.
/// 월간 보기에서는 헤더의 화살표로 달을 넘기고, 주간 보기는 좌우 스와이프로 주를 넘긴다.
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
                    .contentShape(Rectangle())
                    .gesture(weekSwipeGesture)
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
        .overlay(alignment: .trailing) {
            // 헤더 전체가 펼침 토글이라, 화살표는 겹쳐 올려 각자 탭을 받게 한다.
            if isExpanded {
                monthArrows
                    .padding(.trailing, 24)
                    .padding(.bottom, 8)
            }
        }
        .accessibilityLabel("\(monthLabel), \(isExpanded ? "월간 보기" : "주간 보기")")
        .accessibilityHint("탭하면 \(isExpanded ? "주간" : "월간")으로 바뀝니다")
    }

    private var monthArrows: some View {
        HStack(spacing: 4) {
            monthArrow(systemName: "chevron.left", months: -1, label: "이전 달")
            monthArrow(systemName: "chevron.right", months: 1, label: "다음 달")
        }
    }

    private func monthArrow(systemName: String, months: Int, label: String) -> some View {
        let target = Self.shifted(startOfSelectedDay, byMonths: months, calendar: calendar)
        return Button {
            guard let target else { return }
            withAnimation(.easeInOut(duration: 0.2)) { selectedDate = target }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(target == nil ? DadariColor.inkMuted : DadariColor.inkSoft)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .accessibilityLabel(label)
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

    /// 선택한 날짜가 속한 달력 주. 요일 열이 늘 같은 자리에 오도록 주 시작일부터 7일을 만든다.
    private var weekDates: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: startOfSelectedDay) else {
            return [startOfSelectedDay]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    /// 좌우로 밀어 주를 옮긴다. 선택한 요일은 그대로 두고 주만 이동한다.
    private var weekSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let offset = value.translation.width < 0 ? 7 : -7
                guard let moved = calendar.date(byAdding: .day, value: offset, to: startOfSelectedDay),
                      Self.isWithinViewableRange(moved, calendar: calendar)
                else {
                    return
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = moved
                }
            }
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

    // MARK: - 이동 범위

    /// 볼 수 있는 가장 먼 날짜. 오늘이 속한 달의 다음 달 말일이다.
    static func latestViewableDate(now: Date = Date(), calendar: Calendar) -> Date? {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now),
              let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: thisMonth.start),
              let nextMonth = calendar.dateInterval(of: .month, for: nextMonthStart),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth.end)
        else { return nil }
        return calendar.startOfDay(for: lastDay)
    }

    /// 과거는 끝없이 허용하고, 미래는 `latestViewableDate`까지만 허용한다.
    static func isWithinViewableRange(_ date: Date, now: Date = Date(), calendar: Calendar) -> Bool {
        guard let latest = latestViewableDate(now: now, calendar: calendar) else { return true }
        return calendar.startOfDay(for: date) <= latest
    }

    /// 한 달씩 옮긴 날짜. 범위를 벗어나면 nil이다(그때는 화살표를 비활성으로 보인다).
    static func shifted(
        _ date: Date, byMonths months: Int, now: Date = Date(), calendar: Calendar
    ) -> Date? {
        guard let moved = calendar.date(byAdding: .month, value: months, to: date),
              isWithinViewableRange(moved, now: now, calendar: calendar)
        else { return nil }
        return moved
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
