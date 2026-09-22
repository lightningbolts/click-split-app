import SwiftUI

/// Profile sheet presenting active account information, credentials status, and sign-out action.
public struct UserProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @AppStorage("click_split_theme") private var theme: String = "system"
    @State private var showSignOutConfirmation = false

    public init() {}

    private var currentUser: SplitUserProfile? {
        environment.sessionStore.currentUser
    }

    private var initials: String {
        guard let name = currentUser?.fullName, !name.isEmpty else {
            return "CS"
        }
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: SplitSpacing.xl) {
                // User Avatar and Name
                VStack(spacing: SplitSpacing.md) {
                    UserAvatarView(
                        avatarUrl: currentUser?.avatarUrl,
                        name: currentUser?.fullName,
                        size: 88,
                        shape: .circle,
                        showBorder: true,
                        showShadow: true
                    )

                    VStack(spacing: SplitSpacing.xxs) {
                        Text(currentUser?.displayName ?? "Click User")
                            .font(SplitTypography.title)
                            .foregroundColor(SplitColors.ink)

                        if let email = currentUser?.email {
                            Text(email)
                                .font(SplitTypography.body)
                                .foregroundColor(SplitColors.inkSoft)
                        }
                    }
                }
                .padding(.top, SplitSpacing.lg)

                // Appearance Setting Card
                VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                    Text("APPEARANCE")
                        .font(SplitTypography.badge)
                        .foregroundColor(SplitColors.inkSoft)
                        .tracking(1)

                    HStack(spacing: SplitSpacing.xs) {
                        themeButton(title: "System", mode: "system", icon: "circle.righthalf.filled")
                        themeButton(title: "Light", mode: "light", icon: "sun.max.fill")
                        themeButton(title: "Dark", mode: "dark", icon: "moon.fill")
                    }
                    .padding(SplitSpacing.xs)
                    .background(SplitColors.paperDim)
                    .overlay(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .stroke(SplitColors.ink, lineWidth: 1.5)
                    )
                }

                // Account Information Card
                VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                    Text("ACCOUNT DETAILS")
                        .font(SplitTypography.badge)
                        .foregroundColor(SplitColors.inkSoft)
                        .tracking(1)

                    VStack(spacing: SplitSpacing.xs) {
                        HStack {
                            Text("Account ID")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.inkSoft)

                            Spacer()

                            Text(currentUser?.id.uuidString.prefix(8) ?? "—")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.ink)
                                .splitMonospacedDigits()
                        }

                        Divider()
                            .background(SplitColors.grey.opacity(0.3))

                        HStack {
                            Text("App Version")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.inkSoft)

                            Spacer()

                            Text("1.0.0 (Native)")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.ink)
                        }

                        Divider()
                            .background(SplitColors.grey.opacity(0.3))

                        HStack {
                            Text("Platform")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.inkSoft)

                            Spacer()

                            Text("Click Split iOS")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.ink)
                        }
                    }
                    .padding(SplitSpacing.md)
                    .splitCardStyle(surfaceColor: SplitColors.paperDim)
                }

                // Legal & Support Card
                VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                    Text("LEGAL & SUPPORT")
                        .font(SplitTypography.badge)
                        .foregroundColor(SplitColors.inkSoft)
                        .tracking(1)

                    VStack(spacing: SplitSpacing.xs) {
                        Link(destination: URL(string: "https://split.joinclick.co/privacy")!) {
                            HStack {
                                Text("Privacy Policy")
                                    .font(SplitTypography.caption)
                                    .foregroundColor(SplitColors.ink)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(SplitColors.grey)
                            }
                        }

                        Divider()
                            .background(SplitColors.grey.opacity(0.3))

                        Link(destination: URL(string: "https://split.joinclick.co/terms")!) {
                            HStack {
                                Text("Terms of Service")
                                    .font(SplitTypography.caption)
                                    .foregroundColor(SplitColors.ink)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(SplitColors.grey)
                            }
                        }

                        Divider()
                            .background(SplitColors.grey.opacity(0.3))

                        Link(destination: URL(string: "https://split.joinclick.co/support")!) {
                            HStack {
                                Text("Support & FAQ")
                                    .font(SplitTypography.caption)
                                    .foregroundColor(SplitColors.ink)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(SplitColors.grey)
                            }
                        }
                    }
                    .padding(SplitSpacing.md)
                    .splitCardStyle(surfaceColor: SplitColors.paperDim)
                }

                Spacer()

                // Sign Out Button
                VStack(spacing: SplitSpacing.xs) {
                    Button {
                        SplitHaptics.impact(.medium)
                        showSignOutConfirmation = true
                    } label: {
                        HStack(spacing: SplitSpacing.xs) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(SplitTypography.button)
                        .foregroundColor(SplitColors.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplitSpacing.md)
                        .background(SplitColors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.red, lineWidth: SplitSpacing.borderWidth)
                        )
                        .splitShadow(offset: SplitSpacing.shadowOffsetSmall)
                    }

                    Text("You can sign back in at any time with Apple ID.")
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, SplitSpacing.lg)
            }
            .padding(.horizontal, SplitSpacing.lg)
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Profile")
            .splitInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(SplitColors.ink)
                }
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    dismiss()
                    environment.sessionStore.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out of Click Split?")
            }
            .task {
                await environment.sessionStore.refreshUserProfile()
            }
        }
    }

    private func themeButton(title: String, mode: String, icon: String) -> some View {
        let isSelected = theme == mode
        return Button {
            SplitHaptics.selection()
            theme = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(SplitTypography.buttonSmall)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SplitSpacing.xs)
            .background(isSelected ? SplitColors.paper : Color.clear)
            .foregroundColor(isSelected ? SplitColors.ink : SplitColors.inkSoft)
            .overlay(
                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius - 1)
                    .stroke(isSelected ? SplitColors.ink : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
