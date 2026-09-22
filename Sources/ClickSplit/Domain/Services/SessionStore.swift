import Foundation
import Observation

/// Authentication and session status for the current Click user.
public enum SessionState: Equatable, Sendable {
    case unauthenticated
    case authenticating
    case authenticated
    case error(String)
}

/// Root session store managing the active Click user and authentication lifecycle.
@Observable
public final class SessionStore: @unchecked Sendable {
    public var state: SessionState = .unauthenticated
    public var currentUser: SplitUserProfile?
    public var authToken: String?

    public init(
        state: SessionState = .unauthenticated,
        currentUser: SplitUserProfile? = nil,
        authToken: String? = nil
    ) {
        self.state = state
        self.currentUser = currentUser
        self.authToken = authToken
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
            authToken: "preview-token"
        )
    }

    public func signIn(user: SplitUserProfile, token: String) {
        self.currentUser = user
        self.authToken = token
        self.state = .authenticated
    }

    public func signOut() {
        self.currentUser = nil
        self.authToken = nil
        self.state = .unauthenticated
    }
}
