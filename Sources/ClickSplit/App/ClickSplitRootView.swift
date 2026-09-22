import SwiftUI
import AuthenticationServices

/// Root view of Click Split handling session routing and root environment injection.
public struct ClickSplitRootView: View {
    @State private var environment: AppEnvironment
    @State private var router = AppRouter()

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
        .environment(\.appRouter, router)
        .onOpenURL { url in
            router.handleIncomingURL(url)
        }
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

            // Official Click Split Website Brand Mark
            ClickBrandLogo(size: 64, style: .authMark)

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
                // Primary: Continue with Google Button (matches web app)
                Button {
                    SplitHaptics.impact(.medium)
                    isAuthenticating = true
                    errorMessage = nil
                    Task {
                        await environment.sessionStore.signInWithGoogle()
                        isAuthenticating = false
                        if case .error(let msg) = environment.sessionStore.state {
                            errorMessage = msg
                        }
                    }
                } label: {
                    HStack(spacing: SplitSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                            Text("G")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
                        }

                        Text("Continue with Google")
                            .font(SplitTypography.button)
                            .foregroundColor(SplitColors.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(SplitColors.ink)
                    .overlay(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .fill(SplitColors.ink)
                            .offset(x: SplitSpacing.shadowOffsetSmall, y: SplitSpacing.shadowOffsetSmall)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)

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

                // Footnote matching web sign-in
                HStack(spacing: 6) {
                    Circle()
                        .fill(SplitColors.green)
                        .frame(width: 6, height: 6)
                    Text("Uses your Click identity: same login, same profile")
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.grey)
                }
                .padding(.top, SplitSpacing.xs)
            }
            .padding(.horizontal, SplitSpacing.lg)
            .padding(.bottom, SplitSpacing.xl)
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
                    if case .error(let msg) = environment.sessionStore.state {
                        errorMessage = msg
                    }
                }
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == "com.apple.AuthenticationServices.AuthorizationError" && nsError.code == 1000 {
                self.errorMessage = "Sign in with Apple is not active in this simulator. Please use 'Continue with Google' or 'Demo Account Sign In'."
            } else {
                self.errorMessage = error.localizedDescription
            }
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
