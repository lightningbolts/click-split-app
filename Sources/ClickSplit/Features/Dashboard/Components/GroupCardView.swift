import SwiftUI

/// High-contrast neo-brutalist row/card displaying a Split Group on the dashboard.
public struct GroupCardView: View {
    public var group: SplitGroup
    public var balance: Decimal

    public init(group: SplitGroup, balance: Decimal) {
        self.group = group
        self.balance = balance
    }

    private var balanceColor: Color {
        if balance > 0 { return SplitColors.green }
        if balance < 0 { return SplitColors.red }
        return SplitColors.grey
    }

    private var balanceSubtitle: String {
        if balance > 0 { return "owed to you" }
        if balance < 0 { return "you owe" }
        return "settled"
    }

    public var body: some View {
        HStack(spacing: SplitSpacing.md) {
            // Group Icon / Emoji Box
            ZStack {
                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                    .fill(SplitColors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                    )

                Text(group.icon ?? "👥")
                    .font(.system(size: 24))
            }
            .frame(width: 48, height: 48)

            // Group Info
            VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                Text(group.name)
                    .font(SplitTypography.button)
                    .foregroundColor(SplitColors.ink)
                    .lineLimit(1)

                Text("Active group")
                    .font(SplitTypography.caption)
                    .foregroundColor(SplitColors.inkSoft)
            }

            Spacer()

            // Balance Summary
            VStack(alignment: .trailing, spacing: SplitSpacing.xxs) {
                SplitAmount(balance, style: .medium, showSign: true, color: balanceColor)

                Text(balanceSubtitle)
                    .font(SplitTypography.caption)
                    .foregroundColor(balanceColor)
                    .textCase(.lowercase)
            }
        }
        .padding(SplitSpacing.lg)
        .splitCardStyle(
            surfaceColor: SplitColors.paperDim,
            borderColor: SplitColors.ink,
            shadowOffset: SplitSpacing.shadowOffsetSmall
        )
    }
}
