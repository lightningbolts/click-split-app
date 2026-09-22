import SwiftUI

/// High-contrast neo-brutalist card displaying a Split Group on the dashboard,
/// matching the website's high information density and layout 1:1.
public struct GroupCardView: View {
    public var group: SplitGroup
    public var balance: Decimal
    public var memberSummary: String
    public var memberCount: Int
    public var expenseCount: Int
    public var totalSpend: Decimal
    public var latestExpenseDesc: String?
    public var latestExpenseAmount: Decimal?
    public var onAddExpense: (() -> Void)?

    public init(
        group: SplitGroup,
        balance: Decimal,
        memberSummary: String? = nil,
        memberCount: Int = 1,
        expenseCount: Int = 0,
        totalSpend: Decimal = 0,
        latestExpenseDesc: String? = nil,
        latestExpenseAmount: Decimal? = nil,
        onAddExpense: (() -> Void)? = nil
    ) {
        self.group = group
        self.balance = balance
        self.memberSummary = memberSummary ?? "1 member · 0 expenses"
        self.memberCount = memberCount
        self.expenseCount = expenseCount
        self.totalSpend = totalSpend
        self.latestExpenseDesc = latestExpenseDesc
        self.latestExpenseAmount = latestExpenseAmount
        self.onAddExpense = onAddExpense
    }

    private var balanceColor: Color {
        if balance > 0 { return SplitColors.green }
        if balance < 0 { return SplitColors.red }
        return SplitColors.ink
    }

    private var balanceSubtitle: String {
        if balance > 0 { return "owed to you" }
        if balance < 0 { return "you owe" }
        return "settled up"
    }

    public var body: some View {
        VStack(spacing: SplitSpacing.md) {
            // Header: Icon + Title/Members + Net Balance
            HStack(spacing: 12) {
                // Group Icon / Emoji Box (42x42 square, subtle border, paperDim background)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(SplitColors.paperDim)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(SplitColors.border, lineWidth: 1.0)
                        )

                    Text(group.icon ?? "👥")
                        .font(.system(size: 20))
                }
                .frame(width: 42, height: 42)

                // Group Info (Name + member preview)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(SplitTypography.button)
                        .foregroundColor(SplitColors.ink)
                        .lineLimit(1)

                    Text(memberSummary)
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.grey)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                // Balance Summary (Tabular figure + "settled up" / "owed to you" / "you owe")
                VStack(alignment: .trailing, spacing: 2) {
                    SplitAmount(
                        balance,
                        style: .small,
                        showSign: true,
                        color: balanceColor
                    )

                    Text(balanceSubtitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SplitColors.grey)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            // Key Metrics Strip: TOTAL SPENT | EXPENSES | MEMBERS
            HStack(spacing: 0) {
                metricColumn(label: "TOTAL SPENT", value: formatMoney(totalSpend))

                Rectangle()
                    .fill(SplitColors.border)
                    .frame(width: 1, height: 20)

                metricColumn(label: "EXPENSES", value: "\(expenseCount)")

                Rectangle()
                    .fill(SplitColors.border)
                    .frame(width: 1, height: 20)

                metricColumn(label: "MEMBERS", value: "\(memberCount)")
            }
            .padding(.vertical, 8)
            .background(SplitColors.paperDim)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Recent Activity Micro-row
            HStack(spacing: 6) {
                if let desc = latestExpenseDesc, let amount = latestExpenseAmount {
                    Text("LATEST")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(SplitColors.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(SplitColors.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    Text(desc)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SplitColors.ink)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    SplitAmount(amount, style: .small, color: SplitColors.ink)
                        .font(.system(size: 11, weight: .bold))
                } else {
                    Text("No expenses yet · Ready to split")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(SplitColors.grey)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SplitColors.paperDim)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Quick Actions Footer
            HStack(spacing: SplitSpacing.sm) {
                if let onAddExpense {
                    Button(action: onAddExpense) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .heavy))
                            Text("Add expense")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(SplitColors.green)
                        .foregroundColor(SplitColors.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 4) {
                    Text("Open group")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(SplitColors.ink)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(SplitColors.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(SplitColors.paperDim)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(SplitColors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(14)
        .splitCardStyle(
            surfaceColor: SplitColors.white,
            borderColor: SplitColors.border,
            borderWidth: 1.0,
            shadowOffset: 0
        )
    }

    private func metricColumn(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(SplitColors.inkSoft)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(SplitColors.ink)
                .splitMonospacedDigits()
        }
        .frame(maxWidth: .infinity)
    }

    private func formatMoney(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$\(amount)"
    }
}


