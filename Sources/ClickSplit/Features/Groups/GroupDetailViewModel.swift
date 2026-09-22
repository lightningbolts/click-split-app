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

    public init(group: SplitGroup, initialSnapshot: GroupDetailSnapshot? = nil) {
        self.group = group

        if let initialSnapshot {
            self.members = initialSnapshot.members
            self.expenses = initialSnapshot.expenses
            self.userBalance = initialSnapshot.userBalance
        }
    }

    /// Refreshes the group without clearing data that is already on screen.
    ///
    /// Core group content is intentionally fault-tolerant: a failure to load
    /// settlements or one secondary balance must not collapse the entire detail
    /// screen back to an empty state.
    @MainActor
    public func loadGroupData(environment: AppEnvironment) async {
        guard let currentUserId = environment.sessionStore.currentUser?.id else { return }

        isLoading = true
        errorMessage = nil

        async let fetchedMembers: [SplitGroupMember]? = try? await environment.groupRepository.fetchGroupMembers(groupId: group.id)
        async let fetchedExpenses: [SplitExpense]? = try? await environment.expenseRepository.fetchExpenses(groupId: group.id)
        async let fetchedSettlements: [SplitSettlement]? = try? await environment.settlementRepository.fetchSettlements(groupId: group.id)
        async let fetchedBalance: Decimal? = try? await environment.groupRepository.fetchGroupBalance(
            groupId: group.id,
            userId: currentUserId
        )

        // Apply the data that drives visible components first. Each result is
        // independent so one backend/RLS failure cannot hide members or expenses.
        let membersResult = await fetchedMembers
        if let membersResult {
            members = membersResult
        }

        let expensesResult = await fetchedExpenses
        if let expensesResult {
            expenses = expensesResult
        }

        let balanceResult = await fetchedBalance
        if let balanceResult {
            userBalance = balanceResult
        }

        let settlementsResult = await fetchedSettlements
        if let settlementsResult {
            settlements = settlementsResult
        }

        // Expense shares enrich rows and detail sheets, but should never gate the
        // basic expense feed. Fetch them concurrently and preserve prior values
        // for any individual request that fails.
        let expensesToHydrate = expenses
        var sharesMap = memberShares
        await withTaskGroup(of: (UUID, [SplitExpenseShare]?).self) { taskGroup in
            for expense in expensesToHydrate {
                taskGroup.addTask {
                    let shares = try? await environment.expenseRepository.fetchExpenseShares(expenseId: expense.id)
                    return (expense.id, shares)
                }
            }

            for await (expenseId, shares) in taskGroup {
                if let shares {
                    sharesMap[expenseId] = shares
                }
            }
        }
        memberShares = sharesMap

        // Member balances come from the same authoritative RPC used for the hero
        // balance. Load them in parallel so the member list appears immediately
        // while exact amounts settle in without rebuilding the screen.
        var balances = memberBalances
        balances[currentUserId] = userBalance
        let membersToHydrate = members.filter { $0.userId != currentUserId }

        await withTaskGroup(of: (UUID, Decimal?).self) { taskGroup in
            for member in membersToHydrate {
                taskGroup.addTask {
                    let balance = try? await environment.groupRepository.fetchGroupBalance(
                        groupId: self.group.id,
                        userId: member.userId
                    )
                    return (member.userId, balance)
                }
            }

            for await (userId, balance) in taskGroup {
                if let balance {
                    balances[userId] = balance
                }
            }
        }
        memberBalances = balances

        if membersResult == nil && expensesResult == nil && balanceResult == nil {
            errorMessage = "Unable to refresh group data."
        }

        isLoading = false
    }
}
