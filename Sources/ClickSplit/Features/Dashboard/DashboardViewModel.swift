import SwiftUI
import Observation

/// Metadata for group previews on the dashboard.
public struct GroupPreviewMeta: Sendable {
    public let balance: Decimal
    public let memberSummary: String
    public let memberCount: Int
    public let expenseCount: Int
    public let totalSpend: Decimal
    public let latestExpenseDesc: String?
    public let latestExpenseAmount: Decimal?

    public init(
        balance: Decimal = 0,
        memberSummary: String = "1 member · 0 expenses",
        memberCount: Int = 1,
        expenseCount: Int = 0,
        totalSpend: Decimal = 0,
        latestExpenseDesc: String? = nil,
        latestExpenseAmount: Decimal? = nil
    ) {
        self.balance = balance
        self.memberSummary = memberSummary
        self.memberCount = memberCount
        self.expenseCount = expenseCount
        self.totalSpend = totalSpend
        self.latestExpenseDesc = latestExpenseDesc
        self.latestExpenseAmount = latestExpenseAmount
    }
}

/// Data already fetched for a dashboard group card that can seed the detail screen immediately.
public struct GroupDetailSnapshot: Sendable {
    public let members: [SplitGroupMember]
    public let expenses: [SplitExpense]
    public let userBalance: Decimal

    public init(
        members: [SplitGroupMember],
        expenses: [SplitExpense],
        userBalance: Decimal
    ) {
        self.members = members
        self.expenses = expenses
        self.userBalance = userBalance
    }
}

/// Observable presentation model for the Dashboard screen.
@Observable
public final class DashboardViewModel: @unchecked Sendable {
    public var groups: [SplitGroup] = []
    public var groupBalances: [UUID: Decimal] = [:]
    public var memberSummaries: [UUID: String] = [:]
    public var groupMeta: [UUID: GroupPreviewMeta] = [:]
    public var groupDetailSnapshots: [UUID: GroupDetailSnapshot] = [:]
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
            var summaries: [UUID: String] = [:]
            var metas: [UUID: GroupPreviewMeta] = [:]
            var snapshots: [UUID: GroupDetailSnapshot] = [:]

            await withTaskGroup(of: (UUID, Decimal, String, GroupPreviewMeta, GroupDetailSnapshot).self) { taskGroup in
                for splitGroup in fetchedGroups {
                    taskGroup.addTask {
                        let bal = (try? await environment.groupRepository.fetchGroupBalance(groupId: splitGroup.id, userId: userId)) ?? Decimal.zero
                        let members = (try? await environment.groupRepository.fetchGroupMembers(groupId: splitGroup.id)) ?? []
                        let expenses = (try? await environment.expenseRepository.fetchExpenses(groupId: splitGroup.id)) ?? []

                        let memberNames = members.compactMap { member -> String? in
                            let name = member.profile?.displayName
                            if let name = name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                                return name
                            }
                            return nil
                        }

                        let count = max(1, members.count)
                        let namesString: String
                        if memberNames.isEmpty {
                            namesString = "\(count) member\(count == 1 ? "" : "s")"
                        } else {
                            namesString = memberNames.joined(separator: ", ")
                        }

                        let expenseCount = expenses.count
                        let expenseString = "\(expenseCount) expense\(expenseCount == 1 ? "" : "s")"
                        let summary = "\(namesString) · \(expenseString)"

                        let totalSpend = expenses.reduce(Decimal.zero) { $0 + $1.totalAmount }
                        let sortedExpenses = expenses.sorted { $0.createdAt > $1.createdAt }
                        let latest = sortedExpenses.first

                        let meta = GroupPreviewMeta(
                            balance: bal,
                            memberSummary: summary,
                            memberCount: count,
                            expenseCount: expenseCount,
                            totalSpend: totalSpend,
                            latestExpenseDesc: latest?.description,
                            latestExpenseAmount: latest?.totalAmount
                        )

                        let snapshot = GroupDetailSnapshot(
                            members: members,
                            expenses: sortedExpenses,
                            userBalance: bal
                        )

                        return (splitGroup.id, bal, summary, meta, snapshot)
                    }
                }

                for await (groupId, bal, summary, meta, snapshot) in taskGroup {
                    balances[groupId] = bal
                    summaries[groupId] = summary
                    metas[groupId] = meta
                    snapshots[groupId] = snapshot
                    if bal > 0 {
                        owedToYou += bal
                    } else if bal < 0 {
                        youOwe += abs(bal)
                    }
                }
            }

            self.groupBalances = balances
            self.memberSummaries = summaries
            self.groupMeta = metas
            self.groupDetailSnapshots = snapshots
            self.totalOwedToYou = owedToYou
            self.totalYouOwe = youOwe
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}


