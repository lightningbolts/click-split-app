import Foundation

/// Repository protocol for Group queries and mutations.
public protocol GroupRepositoryProtocol: Sendable {
    func fetchUserGroups(userId: UUID) async throws -> [SplitGroup]
    func fetchGroup(id: UUID) async throws -> SplitGroup?
    func fetchGroupMembers(groupId: UUID) async throws -> [SplitGroupMember]
    func createGroup(name: String, icon: String?, createdBy: UUID) async throws -> SplitGroup
    func joinGroup(groupId: UUID, userId: UUID) async throws
    func leaveGroup(groupId: UUID, userId: UUID) async throws
    func deleteGroup(groupId: UUID) async throws
    func fetchGroupBalance(groupId: UUID, userId: UUID) async throws -> Decimal
}

/// Repository protocol for Expense queries and mutations.
public protocol ExpenseRepositoryProtocol: Sendable {
    func fetchExpenses(groupId: UUID) async throws -> [SplitExpense]
    func fetchExpenseItems(expenseId: UUID) async throws -> [SplitExpenseItem]
    func fetchExpenseShares(expenseId: UUID) async throws -> [SplitExpenseShare]
    func createExpense(draft: ExpenseDraft, groupId: UUID) async throws -> SplitExpense
    func deleteExpense(expenseId: UUID) async throws
}

/// Repository protocol for Settlements and balance clearances.
public protocol SettlementRepositoryProtocol: Sendable {
    func fetchSettlements(groupId: UUID) async throws -> [SplitSettlement]
    func recordSettlement(
        groupId: UUID,
        fromUser: UUID,
        toUser: UUID,
        amount: Decimal,
        method: SettlementMethod?
    ) async throws -> SplitSettlement
}
