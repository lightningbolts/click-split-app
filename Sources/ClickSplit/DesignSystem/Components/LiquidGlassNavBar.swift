import SwiftUI

/// Tab selection enum for Click Split primary navigation.
public enum SplitTab: String, CaseIterable, Sendable {
    case groups = "Groups"
    case activity = "Activity"
}

/// Floating Liquid Glass bottom navigation bar.
/// Styled with ultra-thin translucent material, subtle neo-brutalist border, and tactile Click interaction.
public struct LiquidGlassNavBar: View {
    @Binding public var selectedTab: SplitTab
    public var onAddGroup: () -> Void
    public var onScanReceipt: () -> Void
    public var onOpenProfile: () -> Void
    public var avatarUrl: String?
    public var userName: String?

    public init(
        selectedTab: Binding<SplitTab>,
        avatarUrl: String? = nil,
        userName: String? = nil,
        onAddGroup: @escaping () -> Void,
        onScanReceipt: @escaping () -> Void,
        onOpenProfile: @escaping () -> Void
    ) {
        self._selectedTab = selectedTab
        self.avatarUrl = avatarUrl
        self.userName = userName
        self.onAddGroup = onAddGroup
        self.onScanReceipt = onScanReceipt
        self.onOpenProfile = onOpenProfile
    }

    public var body: some View {
        HStack(spacing: SplitSpacing.sm) {
            // Groups Tab
            navItem(
                title: "Groups",
                icon: "rectangle.stack.fill",
                isSelected: selectedTab == .groups
            ) {
                if selectedTab != .groups {
                    SplitHaptics.selection()
                    selectedTab = .groups
                }
            }

            // Activity Tab
            navItem(
                title: "Activity",
                icon: "chart.line.uptrend.xyaxis",
                isSelected: selectedTab == .activity
            ) {
                if selectedTab != .activity {
                    SplitHaptics.selection()
                    selectedTab = .activity
                }
            }

            // Center Prominent Action Button (+)
            Button {
                SplitHaptics.impact(.medium)
                onAddGroup()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(SplitColors.green)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(SplitColors.ink, lineWidth: 2)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(SplitColors.ink)
                                .offset(x: 2, y: 2)
                        )

                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(SplitColors.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)

            // Scan Receipt Action
            actionItem(
                title: "Scan",
                icon: "camera.viewfinder"
            ) {
                SplitHaptics.impact(.light)
                onScanReceipt()
            }

            // Profile Action
            Button {
                SplitHaptics.impact(.light)
                onOpenProfile()
            } label: {
                VStack(spacing: 3) {
                    if let avatarUrl, !avatarUrl.isEmpty {
                        UserAvatarView(
                            avatarUrl: avatarUrl,
                            name: userName,
                            size: 20,
                            shape: .circle,
                            showBorder: true,
                            showShadow: false
                        )
                        .frame(height: 22)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(SplitColors.inkSoft)
                            .frame(height: 22)
                    }

                    Text("Profile")
                        .font(SplitTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(SplitColors.grey)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            // Liquid Glass Frosted Surface
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 30)
                    .fill(SplitColors.paper.opacity(0.70))

                RoundedRectangle(cornerRadius: 30)
                    .stroke(SplitColors.ink.opacity(0.85), lineWidth: 1.5)
            }
        )
        .shadow(color: SplitColors.ink.opacity(0.16), radius: 14, x: 0, y: 6)
        .padding(.horizontal, SplitSpacing.lg)
    }

    private func navItem(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? SplitColors.green : SplitColors.inkSoft)
                    .frame(height: 22)

                Text(title)
                    .font(SplitTypography.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? SplitColors.ink : SplitColors.grey)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 16)
                        .fill(SplitColors.greenDim.opacity(0.8))
                    : nil
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
    }

    private func actionItem(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(SplitColors.inkSoft)
                    .frame(height: 22)

                Text(title)
                    .font(SplitTypography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(SplitColors.grey)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
