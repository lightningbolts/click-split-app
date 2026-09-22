import Foundation
import Observation

/// Authentication and session status for the current Click user.
public enum SessionState: Equatable, Sendable {
    case unauthenticated
    case restoring
    case authenticating
    case authenticated
    case error(String)
}

/// Root session store managing the active Click user, token persistence, and authentication lifecycle.
@Observable
public final class SessionStore: @unchecked Sendable {
    public var state: SessionState = .unauthenticated
    public var currentUser: SplitUserProfile?
    public var authToken: String?
    public var refreshToken: String?

    public init(
        state: SessionState = .unauthenticated,
        currentUser: SplitUserProfile? = nil,
        authToken: String? = nil,
        refreshToken: String? = nil,
        restoreFromKeychain: Bool = true
    ) {
        self.state = state
        self.currentUser = currentUser
        self.authToken = authToken
        self.refreshToken = refreshToken

        if restoreFromKeychain && state == .unauthenticated {
            self.restoreSavedSession()
        }
    }

    /// Sets mock session for preview and testing purposes.
    public static func preview(userId: UUID = UUID(uuidString: "aa3c293c-4066-4fae-8639-30b7fcd1a5c9")!) -> SessionStore {
        let mockUser = SplitUserProfile(
            id: userId,
            email: "timberlake2025@gmail.com",
            fullName: "Kairui Cheng",
            avatarUrl: "https://lrgcwnmcscimkmslihxp.supabase.co/storage/v1/object/public/avatars/aa3c293c-4066-4fae-8639-30b7fcd1a5c9/1776481280174.jpg"
        )
        return SessionStore(
            state: .authenticated,
            currentUser: mockUser,
            authToken: "preview-token",
            restoreFromKeychain: false
        )
    }

    /// Restores a persisted Supabase session. Refresh tokens are preferred so an
    /// expired access token never leaves the app in a fake authenticated state.
    public func restoreSavedSession(client: SupabaseClient = SupabaseClient()) {
        guard let token = KeychainHelper.loadToken(),
              let userId = KeychainHelper.loadUserId() else {
            self.state = .unauthenticated
            return
        }

        self.state = .restoring
        self.authToken = token
        self.refreshToken = KeychainHelper.loadRefreshToken()

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                if let persistedRefreshToken = self.refreshToken, !persistedRefreshToken.isEmpty {
                    let response = try await client.refreshSession(refreshToken: persistedRefreshToken)
                    guard let accessToken = response.access_token, !accessToken.isEmpty else {
                        throw SupabaseClient.SupabaseError.unauthenticated
                    }

                    let user = SplitUserProfile(
                        id: response.user.id,
                        email: response.user.email,
                        fullName: response.user.fullName,
                        avatarUrl: response.user.avatarUrl
                    )
                    self.persistSession(
                        user: user,
                        accessToken: accessToken,
                        refreshToken: response.refresh_token ?? persistedRefreshToken
                    )
                } else {
                    // Migration path for installs created before refresh tokens were persisted.
                    // Keep the session only if the old access token is still valid.
                    let authUser = try await client.getUser(authToken: token)
                    guard authUser.id == userId else {
                        throw SupabaseClient.SupabaseError.unauthenticated
                    }

                    let user = SplitUserProfile(
                        id: authUser.id,
                        email: authUser.email,
                        fullName: authUser.fullName,
                        avatarUrl: authUser.avatarUrl
                    )
                    self.persistSession(user: user, accessToken: token, refreshToken: nil)
                }

                await self.refreshUserProfile(client: client)
            } catch {
                self.clearSession()
            }
        }
    }

    public func signIn(user: SplitUserProfile, token: String, refreshToken: String? = nil) {
        persistSession(user: user, accessToken: token, refreshToken: refreshToken)
        Task { @MainActor in
            await self.refreshUserProfile()
        }
    }

    private func persistSession(user: SplitUserProfile, accessToken: String, refreshToken: String?) {
        self.currentUser = user
        self.authToken = accessToken
        self.refreshToken = refreshToken
        self.state = .authenticated

        KeychainHelper.saveToken(accessToken)
        KeychainHelper.saveUserId(user.id)
        if let refreshToken, !refreshToken.isEmpty {
            KeychainHelper.saveRefreshToken(refreshToken)
        }
    }

    private func clearSession() {
        self.currentUser = nil
        self.authToken = nil
        self.refreshToken = nil
        self.state = .unauthenticated
        KeychainHelper.clear()
    }

    /// Refreshes the active user's profile from the Click `public.users` table or Supabase auth,
    /// ensuring the authentic Click avatar and display name are displayed across the app.
    @MainActor
    public func refreshUserProfile(client: SupabaseClient = SupabaseClient()) async {
        guard let userId = currentUser?.id ?? KeychainHelper.loadUserId() else { return }
        let token = authToken ?? KeychainHelper.loadToken()

        // 1. Fetch from shared Click public.users table
        if let row = await client.fetchPublicProfile(userId: userId, authToken: token) {
            var updated = currentUser ?? SplitUserProfile(id: userId, email: row.email, fullName: row.name)
            if let img = row.image, !img.isEmpty {
                updated.avatarUrl = img
            }
            if let name = row.name, !name.isEmpty {
                updated.fullName = name
            }
            if let email = row.email, !email.isEmpty {
                updated.email = email
            }
            self.currentUser = updated
            return
        }

        // 2. Fall back to auth user metadata if users table row was not found
        if let token, !token.isEmpty {
            do {
                let authUser = try await client.getUser(authToken: token)
                var updated = currentUser ?? SplitUserProfile(id: userId, email: authUser.email, fullName: authUser.fullName)
                if let avatar = authUser.avatarUrl, !avatar.isEmpty {
                    updated.avatarUrl = avatar
                }
                if let name = authUser.fullName, !name.isEmpty {
                    updated.fullName = name
                }
                if let email = authUser.email, !email.isEmpty {
                    updated.email = email
                }
                self.currentUser = updated
            } catch {
                // Non-fatal
            }
        }
    }

    public func signOut() {
        clearSession()
    }

    /// Exchanges an Apple / Google identity token with Supabase Auth.
    @MainActor
    public func exchangeIdToken(
        provider: String,
        idToken: String,
        nonce: String? = nil,
        client: SupabaseClient = SupabaseClient()
    ) async {
        self.state = .authenticating
        do {
            let response = try await client.signInWithIdToken(provider: provider, idToken: idToken, nonce: nonce)
            let user = SplitUserProfile(
                id: response.user.id,
                email: response.user.email,
                fullName: response.user.fullName,
                avatarUrl: response.user.avatarUrl
            )
            guard let accessToken = response.access_token, !accessToken.isEmpty else {
                throw SupabaseClient.SupabaseError.unauthenticated
            }
            self.signIn(user: user, token: accessToken, refreshToken: response.refresh_token)
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }

    /// Authenticates using email and password against Supabase Auth.
    @MainActor
    public func signInWithPassword(
        email: String,
        password: String,
        client: SupabaseClient = SupabaseClient()
    ) async {
        self.state = .authenticating
        do {
            let response = try await client.signInWithPassword(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            guard let token = response.access_token else {
                self.state = .error("Authentication succeeded but no access token was returned.")
                return
            }
            let user = SplitUserProfile(
                id: response.user.id,
                email: response.user.email,
                fullName: response.user.fullName,
                avatarUrl: response.user.avatarUrl
            )
            self.signIn(user: user, token: token, refreshToken: response.refresh_token)
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }

    /// Registers a new user with email, password, and full name.
    /// Returns true if an immediate session was established, or false if email confirmation is required.
    @MainActor
    public func signUpWithPassword(
        email: String,
        password: String,
        fullName: String,
        client: SupabaseClient = SupabaseClient()
    ) async throws -> Bool {
        self.state = .authenticating
        do {
            let response = try await client.signUpWithPassword(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if let token = response.access_token {
                let user = SplitUserProfile(
                    id: response.user.id,
                    email: response.user.email,
                    fullName: fullName,
                    avatarUrl: response.user.avatarUrl
                )
                self.signIn(user: user, token: token, refreshToken: response.refresh_token)
                return true
            } else {
                self.state = .unauthenticated
                return false
            }
        } catch {
            self.state = .error(error.localizedDescription)
            throw error
        }
    }

    /// Initiates Supabase Google OAuth via ASWebAuthenticationSession.
    @MainActor
    public func signInWithGoogle(
        client: SupabaseClient = SupabaseClient(),
        callbackScheme: String = "click",
        redirectTo: String = "click://login"
    ) async {
        guard let oauthURL = client.makeOAuthURL(provider: "google", redirectTo: redirectTo) else {
            self.state = .error("Failed to construct Google OAuth URL.")
            return
        }

        self.state = .authenticating

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: oauthURL,
                    callbackURLScheme: callbackScheme
                ) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: SupabaseClient.SupabaseError.unauthenticated)
                    }
                }
                session.presentationContextProvider = WebAuthContextProvider.shared
                session.prefersEphemeralWebBrowserSession = false

                if !session.start() {
                    continuation.resume(throwing: SupabaseClient.SupabaseError.invalidURL)
                }
            }

            // Extract tokens from the callback URL (supports implicit fragment, query, or PKCE code).
            var tokenString: String?
            var refreshTokenString: String?

            if let fragment = callbackURL.fragment {
                let items = fragment.split(separator: "&").compactMap { item -> (String, String)? in
                    let pair = item.split(separator: "=", maxSplits: 1).map(String.init)
                    guard pair.count == 2 else { return nil }
                    return (pair[0], pair[1].removingPercentEncoding ?? pair[1])
                }
                tokenString = items.first(where: { $0.0 == "access_token" })?.1
                refreshTokenString = items.first(where: { $0.0 == "refresh_token" })?.1
            }

            if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
               let items = components.queryItems {
                tokenString = tokenString ?? items.first(where: { $0.name == "access_token" })?.value
                refreshTokenString = refreshTokenString ?? items.first(where: { $0.name == "refresh_token" })?.value
            }

            // If an authorization code is returned, exchange it for a complete session.
            if tokenString == nil, let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                let authResponse = try await client.exchangeCodeForSession(code: code)
                tokenString = authResponse.access_token
                refreshTokenString = authResponse.refresh_token
            }

            guard let accessToken = tokenString, !accessToken.isEmpty else {
                throw SupabaseClient.SupabaseError.httpError(
                    statusCode: 400,
                    message: "No access token found in OAuth redirect callback: \(callbackURL.absoluteString)"
                )
            }

            // Fetch user profile from Supabase with the access token
            let authUser = try await client.getUser(authToken: accessToken)
            let user = SplitUserProfile(
                id: authUser.id,
                email: authUser.email,
                fullName: authUser.fullName,
                avatarUrl: authUser.avatarUrl
            )

            self.signIn(user: user, token: accessToken, refreshToken: refreshTokenString)
        } catch let asError as ASAuthorizationError where asError.code == .canceled {
            self.state = .unauthenticated
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }
}

#if canImport(AuthenticationServices)
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        return UIWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
#endif

