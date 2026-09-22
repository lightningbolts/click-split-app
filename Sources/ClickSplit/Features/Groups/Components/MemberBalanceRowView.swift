import SwiftUI

/// Row displaying member name and their net balance within the group.
public struct MemberBalanceRowView: View {
    public var member: SplitGroupMember
    public var balance: Decimal
    public var isCurrentUser: Bool

    public init(member: SplitGroupMember, balance: Decimal, isCurrentUser: Bool = false) {
        self.member = member
        self.balance = balance
        self.isCurrentUser = isCurrentUser
    }

    private var balanceColor: Color {
        if balance > 0 { return SplitColors.green }
        if balance < 0 { return SplitColors.red }
        return SplitColors.grey
    }

    public var body: some View {
        HStack(spacing: SplitSpacing.md) {
            if let avatar = member.profile?.avatarUrl, !avatar.isEmpty {
                UserAvatarView(
                    avatarUrl: avatar,
                    name: member.profile?.displayName,
                    size: 28,
                    shape: .circle,
                    showBorder: true,
                    showShadow: false
                )
            } else {
                // Circle status avatar
                Circle()
                    .fill(balanceColor.opacity(0.15))
                    .overlay(
                        Circle()
                            .stroke(balanceColor, lineWidth: 2)
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(member.profile?.displayName.prefix(1) ?? "M"))
                            .font(SplitTypography.badge)
                            .foregroundColor(balanceColor)
                    )
            }

            Text(isCurrentUser ? "\(member.profile?.displayName ?? "You") (You)" : (member.profile?.displayName ?? "Member"))
                .font(SplitTypography.body)
                .foregroundColor(SplitColors.ink)

            Spacer()

            SplitAmount(balance, style: .small, showSign: true, color: balanceColor)
        }
        .padding(.vertical, SplitSpacing.xs)
    }
}
