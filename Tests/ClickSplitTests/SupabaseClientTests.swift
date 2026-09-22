import XCTest
@testable import ClickSplit

final class SupabaseClientTests: XCTestCase {
    func testKeychainSaveAndLoadToken() {
        let testToken = "test-jwt-token-12345"
        let testUserId = UUID()

        KeychainHelper.saveToken(testToken)
        KeychainHelper.saveUserId(testUserId)

        let loadedToken = KeychainHelper.loadToken()
        let loadedUserId = KeychainHelper.loadUserId()

        XCTAssertEqual(loadedToken, testToken)
        XCTAssertEqual(loadedUserId, testUserId)

        KeychainHelper.clear()
        XCTAssertNil(KeychainHelper.loadToken())
        XCTAssertNil(KeychainHelper.loadUserId())
    }

    func testSessionStoreRestoration() {
        let testToken = "restored-token-abc"
        let testUserId = UUID()

        KeychainHelper.saveToken(testToken)
        KeychainHelper.saveUserId(testUserId)

        let store = SessionStore(restoreFromKeychain: true)
        XCTAssertEqual(store.state, .authenticated)
        XCTAssertEqual(store.authToken, testToken)
        XCTAssertEqual(store.currentUser?.id, testUserId)

        store.signOut()
        XCTAssertEqual(store.state, .unauthenticated)
        XCTAssertNil(store.authToken)
        XCTAssertNil(store.currentUser)
    }

    func testSupabaseClientConfiguration() {
        let client = SupabaseClient()
        XCTAssertEqual(client.supabaseURL.absoluteString, "https://lrgcwnmcscimkmslihxp.supabase.co")
        XCTAssertFalse(client.anonKey.isEmpty)
    }
}
