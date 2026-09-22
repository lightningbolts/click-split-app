import SwiftUI
import Observation

/// Global container for shared app dependencies and repositories.
@Observable
public final class AppEnvironment: @unchecked Sendable {
    public let sessionStore: SessionStore
    public let groupRepository: GroupRepositoryProtocol
    public let expenseRepository: ExpenseRepositoryProtocol
    public let settlementRepository: SettlementRepositoryProtocol

    public init(
        sessionStore: SessionStore = SessionStore(),
        groupRepository: GroupRepositoryProtocol = MockGroupRepository(),
        expenseRepository: ExpenseRepositoryProtocol = MockExpenseRepository(),
        settlementRepository: SettlementRepositoryProtocol = MockSettlementRepository()
    ) {
        self.sessionStore = sessionStore
        self.groupRepository = groupRepository
        self.expenseRepository = expenseRepository
        self.settlementRepository = settlementRepository
    }

    /// Production environment connecting to live Supabase backend.
    public static func live(
        sessionStore: SessionStore = SessionStore(),
        client: SupabaseClient = SupabaseClient()
    ) -> AppEnvironment {
        let groupRepo = SupabaseGroupRepository(client: client, sessionStore: sessionStore)
        let expenseRepo = SupabaseExpenseRepository(client: client, sessionStore: sessionStore)
        let settlementRepo = SupabaseSettlementRepository(client: client, sessionStore: sessionStore)

        return AppEnvironment(
            sessionStore: sessionStore,
            groupRepository: groupRepo,
            expenseRepository: expenseRepo,
            settlementRepository: settlementRepo
        )
    }

    /// Development and SwiftUI preview environment with mock repositories.
    public static func preview() -> AppEnvironment {
        let store = SessionStore.preview()
        return AppEnvironment(
            sessionStore: store,
            groupRepository: MockGroupRepository(sampleData: true),
            expenseRepository: MockExpenseRepository(sampleData: true),
            settlementRepository: MockSettlementRepository()
        )
    }
}

// SwiftUI Environment Key
private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = AppEnvironment()
}

public extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
