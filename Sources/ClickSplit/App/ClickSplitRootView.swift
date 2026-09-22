import SwiftUI
import AuthenticationServices

/// Root view of Click Split handling session routing and root environment injection.
public struct ClickSplitRootView: View {
    @State private var environment: AppEnvironment

    public init(environment: AppEnvironment = AppEnvironment.live()) {
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

/// Native Authentication View supporting Apple Sign-In and developer quick sign-in.
public struct AuthenticationView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

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

            if let errorMessage {
                Text(errorMessage)
                    .font(SplitTypography.caption)
                    .foregroundColor(SplitColors.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SplitSpacing.lg)
            }

            Spacer()

            VStack(spacing: SplitSpacing.md) {
                // Native Sign in with Apple Button
                SignInWithAppleButton(
                    .continue,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        handleAppleAuth(result: result)
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                        .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                )
                .background(
                    RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                        .fill(SplitColors.ink)
                        .offset(x: SplitSpacing.shadowOffsetSmall, y: SplitSpacing.shadowOffsetSmall)
                )

                // Quick / Demo Sign In for local preview & testing
                SplitButton("Demo Account Sign In", icon: "person.crop.circle.badge.checkmark", variant: .secondary, isLoading: isAuthenticating) {
                    signInDemoAccount()
                }
            }
            .padding(.horizontal, SplitSpacing.lg)
            .padding(.bottom, SplitSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplitColors.paper.ignoresSafeArea())
    }

    private func handleAppleAuth(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let identityTokenData = appleIDCredential.identityToken,
               let idTokenString = String(data: identityTokenData, encoding: .utf8) {

                isAuthenticating = true
                Task {
                    await environment.sessionStore.exchangeIdToken(
                        provider: "apple",
                        idToken: idTokenString
                    )
                    isAuthenticating = false
                }
            }
        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }

    private func signInDemoAccount() {
        // Shared test identity matching Click dev user
        let demoUserId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let user = SplitUserProfile(
            id: demoUserId,
            email: "kairui@clickplatforms.com",
            fullName: "Kairui Song"
        )
        environment.sessionStore.signIn(user: user, token: SupabaseConfig.defaultAnonKey)
    }
}
