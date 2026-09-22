import SwiftUI
import Observation

/// Observable state model for Group Detail.
@Observable
public final class GroupDetailViewModel: @unchecked Sendable {
    public let group: SplitGroup
    public var members: [SplitGroupMember] = []
    public var expenses: [SplitExpense] = []
    public var memberShares: [UUID: [SplitExpenseShare]] = [:]
    public var settlements: [SplitSettlement] = []
    public var userBalance: Decimal = 0
    public var memberBalances: [UUID: Decimal] = [:]
    public var isLoading: Bool = false
    public var errorMessage: String?

    public init(group: SplitGroup) {
        self.group = group
    }

    @MainActor
    public func loadGroupData(environment: AppEnvironment) async {
        guard let currentUserId = environment.sessionStore.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let fetchedMembers = environment.groupRepository.fetchGroupMembers(groupId: group.id)
            async let fetchedExpenses = environment.expenseRepository.fetchExpenses(groupId: group.id)
            async let fetchedSettlements = environment.settlementRepository.fetchSettlements(groupId: group.id)
            async let fetchedBalance = environment.groupRepository.fetchGroupBalance(groupId: group.id, userId: currentUserId)

            let (mem, exp, set, bal) = try await (fetchedMembers, fetchedExpenses, fetchedSettlements, fetchedBalance)
            self.members = mem
            self.expenses = exp
            self.settlements = set
            self.userBalance = bal

            // Preload shares
            var sharesMap: [UUID: [SplitExpenseShare]] = [:]
            for expense in exp {
                let s = try await environment.expenseRepository.fetchExpenseShares(expenseId: expense.id)
                sharesMap[expense.id] = s
            }
            self.memberShares = sharesMap

            // Compute member balances
            var balances: [UUID: Decimal] = [:]
            let allShares = sharesMap.values.flatMap { $0 }
            for member in mem {
                balances[member.userId] = SplitCalculator.computeNetBalance(
                    for: member.userId,
                    expenses: exp,
                    shares: allShares,
                    settlements: set
                )
            }
            self.memberBalances = balances
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
