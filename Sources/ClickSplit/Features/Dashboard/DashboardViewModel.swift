import SwiftUI
import Observation

/// Observable presentation model for the Dashboard screen.
@Observable
public final class DashboardViewModel: @unchecked Sendable {
    public var groups: [SplitGroup] = []
    public var groupBalances: [UUID: Decimal] = [:]
    public var totalOwedToYou: Decimal = 0
    public var totalYouOwe: Decimal = 0
    public var isLoading: Bool = false
    public var errorMessage: String?

    public var netOverallBalance: Decimal {
        totalOwedToYou - totalYouOwe
    }

    public init() {}

    @MainActor
    public func loadData(environment: AppEnvironment) async {
        guard let userId = environment.sessionStore.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil

        do {
            let fetchedGroups = try await environment.groupRepository.fetchUserGroups(userId: userId)
            self.groups = fetchedGroups

            var owedToYou: Decimal = 0
            var youOwe: Decimal = 0
            var balances: [UUID: Decimal] = [:]

            for group in fetchedGroups {
                let balance = try await environment.groupRepository.fetchGroupBalance(groupId: group.id, userId: userId)
                balances[group.id] = balance
                if balance > 0 {
                    owedToYou += balance
                } else if balance < 0 {
                    youOwe += abs(balance)
                }
            }

            self.groupBalances = balances
            self.totalOwedToYou = owedToYou
            self.totalYouOwe = youOwe
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
