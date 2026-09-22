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
                fullName: response.user.user_metadata?["full_name"] ?? response.user.user_metadata?["name"]
            )
            self.signIn(user: user, token: response.access_token)
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }
}
