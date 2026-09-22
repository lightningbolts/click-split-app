import SwiftUI

/// Feed row representing an expense inside a group.
public struct ExpenseRowView: View {
    public var expense: SplitExpense
    public var currentUserId: UUID?
    public var shares: [SplitExpenseShare]

    public init(
        expense: SplitExpense,
        currentUserId: UUID?,
        shares: [SplitExpenseShare]
    ) {
        self.expense = expense
        self.currentUserId = currentUserId
        self.shares = shares
    }

    private var isPayer: Bool {
        guard let currentUserId else { return false }
        return expense.paidBy == currentUserId
    }

    private var userShareAmount: Decimal {
        guard let currentUserId else { return 0 }
        return shares.first { $0.userId == currentUserId }?.shareAmount ?? 0
    }

    public var body: some View {
        HStack(alignment: .center, spacing: SplitSpacing.md) {
            // Source icon box
            ZStack {
                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                    .fill(SplitColors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .stroke(SplitColors.ink, lineWidth: 1.5)
                    )

                Image(systemName: expense.source == .receiptScan ? "doc.text.viewfinder" : "creditcard")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(SplitColors.ink)
            }
            .frame(width: 40, height: 40)

            // Description & Payer
            VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                Text(expense.description)
                    .font(SplitTypography.button)
                    .foregroundColor(SplitColors.ink)

                Text(isPayer ? "You paid" : "Paid by member")
                    .font(SplitTypography.caption)
                    .foregroundColor(SplitColors.inkSoft)
            }

            Spacer()

            // Financial Summary
            VStack(alignment: .trailing, spacing: SplitSpacing.xxs) {
                SplitAmount(expense.totalAmount, style: .small)

                if isPayer {
                    let lent = expense.totalAmount - userShareAmount
                    SplitAmount(lent, style: .small, showSign: true, color: SplitColors.green)
                } else if userShareAmount > 0 {
                    SplitAmount(userShareAmount, style: .small, showSign: true, color: SplitColors.red)
                }
            }
        }
        .padding(SplitSpacing.md)
        .splitCardStyle(
            surfaceColor: SplitColors.paperDim,
            borderColor: SplitColors.ink,
            borderWidth: 1.5,
            shadowOffset: SplitSpacing.shadowOffsetSmall
        )
    }
}
