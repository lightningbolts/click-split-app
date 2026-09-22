import SwiftUI

/// Root view of Click Split handling session routing and root environment injection.
public struct ClickSplitRootView: View {
    @State private var environment: AppEnvironment

    public init(environment: AppEnvironment = AppEnvironment.preview()) {
        self._environment = State(initialValue: environment)
    }

    public var body: some View {
        Group {
            switch environment.sessionStore.state {
            case .authenticated:
                DashboardView()
            case .unauthenticated, .authenticating, .error:
                AuthenticationView()
            }
        }
        .environment(\.appEnvironment, environment)
        .tint(SplitColors.ink)
    }
}

/// Fallback / Initial Authentication View.
public struct AuthenticationView: View {
    @Environment(\.appEnvironment) private var environment

    public init() {}

    public var body: some View {
        VStack(spacing: SplitSpacing.xl) {
            Spacer()

            // Brand Logo Box
            ZStack {
                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                    .fill(SplitColors.green)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .fill(SplitColors.ink)
                            .offset(x: SplitSpacing.shadowOffset, y: SplitSpacing.shadowOffset)
                    )

                Text("⚡️")
                    .font(.system(size: 44))
            }

            VStack(spacing: SplitSpacing.xs) {
                Text("Click Split")
                    .font(SplitTypography.amountLarge)
                    .foregroundColor(SplitColors.ink)

                Text("Shared expenses made effortless.")
                    .font(SplitTypography.body)
                    .foregroundColor(SplitColors.inkSoft)
            }

            Spacer()

            VStack(spacing: SplitSpacing.md) {
                SplitButton("Continue with Apple", icon: "apple.logo", variant: .secondary) {
                    signInMock()
                }

                SplitButton("Continue with Google", icon: "g.circle", variant: .secondary) {
                    signInMock()
                }
            }
            .padding(.horizontal, SplitSpacing.lg)
            .padding(.bottom, SplitSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplitColors.paper.ignoresSafeArea())
    }

    private func signInMock() {
        let user = SplitUserProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            email: "kairui@clickplatforms.com",
            fullName: "Kairui Song"
        )
        environment.sessionStore.signIn(user: user, token: "mock-session-token")
    }
}
