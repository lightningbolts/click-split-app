import SwiftUI

/// Badge component representing positive ("OWED"), negative ("YOU OWE"), or zero ("SETTLED") balances.
public struct SplitBalanceBadge: View {
    public enum BalanceType {
        case owed(Decimal)
        case youOwe(Decimal)
        case settled
    }

    public var type: BalanceType

    public init(_ type: BalanceType) {
        self.type = type
    }

    private var label: String {
        switch type {
        case .owed: return "OWED TO YOU"
        case .youOwe: return "YOU OWE"
        case .settled: return "SETTLED"
        }
    }

    private var amount: Decimal {
        switch type {
        case .owed(let val): return val
        case .youOwe(let val): return val
        case .settled: return 0
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .owed: return SplitColors.greenDim
        case .youOwe: return SplitColors.redDim
        case .settled: return SplitColors.paperDim
        }
    }

    private var accentColor: Color {
        switch type {
        case .owed: return SplitColors.green
        case .youOwe: return SplitColors.red
        case .settled: return SplitColors.grey
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
            Text(label)
                .font(SplitTypography.badge)
                .foregroundColor(accentColor)
                .textCase(.uppercase)

            SplitAmount(amount, style: .medium, color: accentColor)
        }
        .padding(.horizontal, SplitSpacing.md)
        .padding(.vertical, SplitSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                .stroke(accentColor.opacity(0.22), lineWidth: 1.0)
        )
    }
}
