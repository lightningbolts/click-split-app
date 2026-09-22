import XCTest
@testable import ClickSplit

final class SupabaseClientTests: XCTestCase {
    func testKeychainSaveAndLoadToken() {
        let testToken = "test-jwt-token-12345"
        let testUserId = UUID()

        let testRefreshToken = "refresh-token-67890"
        KeychainHelper.saveToken(testToken)
        KeychainHelper.saveRefreshToken(testRefreshToken)
        KeychainHelper.saveUserId(testUserId)

        let loadedToken = KeychainHelper.loadToken()
        let loadedRefreshToken = KeychainHelper.loadRefreshToken()
        let loadedUserId = KeychainHelper.loadUserId()

        XCTAssertEqual(loadedToken, testToken)
        XCTAssertEqual(loadedRefreshToken, testRefreshToken)
        XCTAssertEqual(loadedUserId, testUserId)

        KeychainHelper.clear()
        XCTAssertNil(KeychainHelper.loadToken())
        XCTAssertNil(KeychainHelper.loadRefreshToken())
        XCTAssertNil(KeychainHelper.loadUserId())
    }

    func testSessionStorePersistsRefreshTokenAndClearsOnSignOut() {
        let testToken = "restored-token-abc"
        let testRefreshToken = "refresh-token-def"
        let testUserId = UUID()
        let user = SplitUserProfile(id: testUserId, email: "test@example.com", fullName: "Test User")

        KeychainHelper.clear()
        let store = SessionStore(restoreFromKeychain: false)
        store.signIn(user: user, token: testToken, refreshToken: testRefreshToken)

        XCTAssertEqual(store.state, .authenticated)
        XCTAssertEqual(store.authToken, testToken)
        XCTAssertEqual(store.refreshToken, testRefreshToken)
        XCTAssertEqual(store.currentUser?.id, testUserId)
        XCTAssertEqual(KeychainHelper.loadToken(), testToken)
        XCTAssertEqual(KeychainHelper.loadRefreshToken(), testRefreshToken)
        XCTAssertEqual(KeychainHelper.loadUserId(), testUserId)

        store.signOut()
        XCTAssertEqual(store.state, .unauthenticated)
        XCTAssertNil(store.authToken)
        XCTAssertNil(store.refreshToken)
        XCTAssertNil(store.currentUser)
        XCTAssertNil(KeychainHelper.loadToken())
        XCTAssertNil(KeychainHelper.loadRefreshToken())
        XCTAssertNil(KeychainHelper.loadUserId())
    }

    func testSupabaseClientConfiguration() {
        let client = SupabaseClient()
        XCTAssertEqual(client.supabaseURL.absoluteString, "https://lrgcwnmcscimkmslihxp.supabase.co")
        XCTAssertFalse(client.anonKey.isEmpty)
    }
}
