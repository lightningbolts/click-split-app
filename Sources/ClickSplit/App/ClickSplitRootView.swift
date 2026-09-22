import SwiftUI
import AuthenticationServices

/// Root view of Click Split handling session routing and root environment injection.
public struct ClickSplitRootView: View {
    @AppStorage("click_split_theme") private var theme: String = "system"
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
        .preferredColorScheme(theme == "light" ? .light : (theme == "dark" ? .dark : nil))
        .onChange(of: environment.sessionStore.authToken) { _, authToken in
            if let authToken, !authToken.isEmpty {
                environment.realtimeClient?.reconnect(authToken: authToken)
            } else {
                environment.realtimeClient?.disconnect()
            }
        }
        .onOpenURL { url in
            router.handleIncomingURL(url)
        }
        .tint(SplitColors.ink)
    }
}

/// Authentication mode selector
public enum AuthMode: String, CaseIterable, Hashable, CustomStringConvertible {
    case signIn = "Sign In"
    case signUp = "Sign Up"

    public var description: String { rawValue }
}

/// Native Authentication View supporting Supabase Email/Password, Google OAuth, Apple Sign-In, and Demo mode.
public struct AuthenticationView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var authMode: AuthMode = .signIn
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SplitSpacing.lg) {
                Spacer(minLength: 20)

                // Official Click Split Website Brand Mark
                ClickBrandLogo(size: 60, style: .authMark)

                VStack(spacing: SplitSpacing.xxs) {
                    Text("Click Split")
                        .font(SplitTypography.amountLarge)
                        .foregroundColor(SplitColors.ink)

                    Text(authMode == .signIn ? "Sign in to track shared expenses." : "Create an account to get started.")
                        .font(SplitTypography.body)
                        .foregroundColor(SplitColors.inkSoft)
                }

                // Auth Mode Segmented Switcher
                SplitSegmentedControl(options: AuthMode.allCases, selection: $authMode)
                    .padding(.horizontal, SplitSpacing.lg)
                    .onChange(of: authMode) { _, _ in
                        errorMessage = nil
                        infoMessage = nil
                    }

                // Status Alerts
                if let errorMessage {
                    Text(errorMessage)
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SplitSpacing.lg)
                }

                if let infoMessage {
                    Text(infoMessage)
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SplitSpacing.lg)
                }

                // Email + Password Form Fields
                VStack(spacing: SplitSpacing.md) {
                    if authMode == .signUp {
                        VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                            Text("FULL NAME")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.inkSoft)

                            TextField("e.g. Alex Morgan", text: $fullName)
                                .font(SplitTypography.body)
                                .padding(SplitSpacing.sm)
                                .background(SplitColors.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                        .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                                )
                                .background(raidShadow())
                                .disabled(isAuthenticating)
                        }
                    }

                    VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                        Text("EMAIL ADDRESS")
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.inkSoft)

                        TextField("you@example.com", text: $email)
                            .font(SplitTypography.body)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(SplitSpacing.sm)
                            .background(SplitColors.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                    .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                            )
                            .background(raidShadow())
                            .disabled(isAuthenticating)
                    }

                    VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                        Text("PASSWORD")
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.inkSoft)

                        HStack {
                            if isPasswordVisible {
                                TextField("At least 6 characters", text: $password)
                                    .font(SplitTypography.body)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                            } else {
                                SecureField("At least 6 characters", text: $password)
                                    .font(SplitTypography.body)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                            }

                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundColor(SplitColors.grey)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(SplitSpacing.sm)
                        .background(SplitColors.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                        )
                        .background(raidShadow())
                        .disabled(isAuthenticating)
                    }

                    // Submit Button
                    SplitButton(
                        authMode == .signIn ? "Sign In with Email" : "Create Account",
                        icon: authMode == .signIn ? "envelope.fill" : "person.badge.plus",
                        variant: .primary,
                        isLoading: isAuthenticating
                    ) {
                        handleEmailPasswordAuth()
                    }
                }
                .padding(.horizontal, SplitSpacing.lg)

                // Neo-brutalist "OR" divider
                HStack(spacing: SplitSpacing.sm) {
                    Rectangle()
                        .fill(SplitColors.ink)
                        .frame(height: 2)

                    Text("OR")
                        .font(SplitTypography.buttonSmall)
                        .foregroundColor(SplitColors.grey)

                    Rectangle()
                        .fill(SplitColors.ink)
                        .frame(height: 2)
                }
                .padding(.horizontal, SplitSpacing.lg)
                .padding(.vertical, SplitSpacing.xs)

                // Social & Demo Logins
                VStack(spacing: SplitSpacing.md) {
                    // Google Button
                    Button {
                        SplitHaptics.impact(.medium)
                        isAuthenticating = true
                        errorMessage = nil
                        infoMessage = nil
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

                    // Apple Sign-In
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

                    // Quick Demo Sign In
                    SplitButton("Demo Account Sign In", icon: "person.crop.circle.badge.checkmark", variant: .secondary, isLoading: isAuthenticating) {
                        signInDemoAccount()
                    }

                    // Reassurance note
                    HStack(spacing: 6) {
                        Circle()
                            .fill(SplitColors.green)
                            .frame(width: 6, height: 6)
                        Text("Uses your Click identity: same login, same profile")
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.grey)
                    }
                    .padding(.top, SplitSpacing.xxs)
                }
                .padding(.horizontal, SplitSpacing.lg)
                .padding(.bottom, SplitSpacing.xl)
            }
        }
        .background(SplitColors.paper.ignoresSafeArea())
    }

    private func raidShadow() -> some View {
        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
            .fill(SplitColors.ink)
            .offset(x: SplitSpacing.shadowOffsetSmall, y: SplitSpacing.shadowOffsetSmall)
    }

    private func handleEmailPasswordAuth() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        if authMode == .signUp && fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter your full name."
            return
        }

        errorMessage = nil
        infoMessage = nil
        isAuthenticating = true

        Task {
            if authMode == .signIn {
                await environment.sessionStore.signInWithPassword(email: cleanEmail, password: password)
                isAuthenticating = false
                if case .error(let msg) = environment.sessionStore.state {
                    errorMessage = msg
                }
            } else {
                do {
                    let immediate = try await environment.sessionStore.signUpWithPassword(
                        email: cleanEmail,
                        password: password,
                        fullName: fullName
                    )
                    isAuthenticating = false
                    if !immediate {
                        infoMessage = "Account created! Please check your email to confirm your account, then sign in."
                        authMode = .signIn
                        password = ""
                    }
                } catch {
                    isAuthenticating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
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
        let demoUserId = UUID(uuidString: "aa3c293c-4066-4fae-8639-30b7fcd1a5c9")!
        let user = SplitUserProfile(
            id: demoUserId,
            email: "timberlake2025@gmail.com",
            fullName: "Kairui Cheng",
            avatarUrl: "https://lrgcwnmcscimkmslihxp.supabase.co/storage/v1/object/public/avatars/aa3c293c-4066-4fae-8639-30b7fcd1a5c9/1776481280174.jpg"
        )
        environment.sessionStore.signIn(user: user, token: SupabaseConfig.defaultAnonKey)
    }
}
