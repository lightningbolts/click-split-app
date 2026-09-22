import Foundation
import Observation

/// Authentication and session status for the current Click user.
public enum SessionState: Equatable, Sendable {
    case unauthenticated
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

    public init(
        state: SessionState = .unauthenticated,
        currentUser: SplitUserProfile? = nil,
        authToken: String? = nil,
        restoreFromKeychain: Bool = true
    ) {
        self.state = state
        self.currentUser = currentUser
        self.authToken = authToken

        if restoreFromKeychain && state == .unauthenticated {
            self.restoreSavedSession()
        }
    }

    /// Sets mock session for preview and testing purposes.
    public static func preview(userId: UUID = UUID()) -> SessionStore {
        let mockUser = SplitUserProfile(
            id: userId,
            email: "kairui@example.com",
            fullName: "Kairui Song",
            avatarUrl: nil
        )
        return SessionStore(
            state: .authenticated,
            currentUser: mockUser,
            authToken: "preview-token",
            restoreFromKeychain: false
        )
    }

    /// Restores previously persisted session from Keychain.
    public func restoreSavedSession() {
        if let token = KeychainHelper.loadToken(),
           let userId = KeychainHelper.loadUserId() {
            self.authToken = token
            self.currentUser = SplitUserProfile(id: userId, email: nil, fullName: "Signed In User")
            self.state = .authenticated
        } else {
            self.state = .unauthenticated
        }
    }

    public func signIn(user: SplitUserProfile, token: String) {
        self.currentUser = user
        self.authToken = token
        self.state = .authenticated
        KeychainHelper.saveToken(token)
        KeychainHelper.saveUserId(user.id)
    }

    public func signOut() {
        self.currentUser = nil
        self.authToken = nil
        self.state = .unauthenticated
        KeychainHelper.clear()
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
            self.signIn(user: user, token: response.access_token)
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }

    /// Initiates Supabase Google OAuth via ASWebAuthenticationSession.
    @MainActor
    public func signInWithGoogle(
        client: SupabaseClient = SupabaseClient(),
        callbackScheme: String = "clicksplit"
    ) async {
        guard let oauthURL = client.makeOAuthURL(provider: "google", redirectTo: "\(callbackScheme)://auth-callback") else {
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

            // Extract tokens from the callback URL:
            // Callback format: clicksplit://auth-callback#access_token=...&refresh_token=...
            var tokenString: String?

            if let fragment = callbackURL.fragment {
                let params = fragment.components(separatedBy: "&")
                for param in params {
                    let pair = param.components(separatedBy: "=")
                    if pair.count == 2 && pair[0] == "access_token" {
                        tokenString = pair[1].removingPercentEncoding ?? pair[1]
                        break
                    }
                }
            }

            if tokenString == nil, let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
               let items = components.queryItems {
                tokenString = items.first(where: { $0.name == "access_token" })?.value
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

            self.signIn(user: user, token: accessToken)
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

