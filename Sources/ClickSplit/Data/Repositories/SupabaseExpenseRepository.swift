import Foundation

/// Live Supabase implementation of ExpenseRepositoryProtocol.
public final class SupabaseExpenseRepository: ExpenseRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient
    private let sessionStore: SessionStore

    public init(client: SupabaseClient = SupabaseClient(), sessionStore: SessionStore) {
        self.client = client
        self.sessionStore = sessionStore
    }

    private var token: String? {
        sessionStore.authToken
    }

    public func fetchExpenses(groupId: UUID) async throws -> [SplitExpense] {
        return try await client.fetch(
            table: "split_expenses",
            filters: [
                URLQueryItem(name: "group_id", value: "eq.\(groupId.uuidString)"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ],
            authToken: token
        )
    }

    public func fetchExpenseItems(expenseId: UUID) async throws -> [SplitExpenseItem] {
        return try await client.fetch(
            table: "split_expense_items",
            filters: [URLQueryItem(name: "expense_id", value: "eq.\(expenseId.uuidString)")],
            authToken: token
        )
    }

    public func fetchExpenseShares(expenseId: UUID) async throws -> [SplitExpenseShare] {
        return try await client.fetch(
            table: "split_expense_shares",
            filters: [URLQueryItem(name: "expense_id", value: "eq.\(expenseId.uuidString)")],
            authToken: token
        )
    }

    public func createExpense(draft: ExpenseDraft, groupId: UUID) async throws -> SplitExpense {
        // 1. Insert parent expense
        struct InsertExpensePayload: Encodable {
            let group_id: UUID
            let description: String
            let total_amount: Decimal
            let paid_by: UUID
            let split_method: String
            let source: String
        }

        let expensePayload = InsertExpensePayload(
            group_id: groupId,
            description: draft.description,
            total_amount: draft.total,
            paid_by: draft.payerID,
            split_method: draft.splitMethod.rawValue,
            source: draft.receipt != nil ? "receipt_scan" : "manual"
        )

        let insertedExpenses: [SplitExpense] = try await client.insert(
            table: "split_expenses",
            value: expensePayload,
            authToken: token
        )

        guard let expense = insertedExpenses.first else {
            throw SupabaseClient.SupabaseError.httpError(statusCode: 500, message: "Expense insert failed")
        }

        // 2. Fetch group members to calculate shares
        let members: [SplitGroupMember] = try await client.fetch(
            table: "split_group_members",
            filters: [URLQueryItem(name: "group_id", value: "eq.\(groupId.uuidString)")],
            authToken: token
        )
        let participantIds = members.map { $0.userId }

        // 3. Compute shares using SplitCalculator
        let calculatedShares: [UUID: Decimal]
        switch draft.splitMethod {
        case .even:
            calculatedShares = try SplitCalculator.calculateEvenSplit(total: draft.total, participantUserIds: participantIds)
        case .customPercent:
            var percentMap: [UUID: Decimal] = [:]
            for s in draft.customShares {
                percentMap[s.userId] = s.percentage
            }
            calculatedShares = try SplitCalculator.calculateCustomPercentageSplit(total: draft.total, percentages: percentMap)
        case .byItem:
            let domainItems = draft.items.map {
                SplitExpenseItem(expenseId: expense.id, label: $0.label, price: $0.price, assignedTo: $0.assignedTo)
            }
            calculatedShares = try SplitCalculator.calculateByItemSplit(items: domainItems, allParticipantUserIds: participantIds)
        }

        // 4. Insert shares
        struct InsertSharePayload: Encodable {
            let expense_id: UUID
            let user_id: UUID
            let share_amount: Decimal
        }

        let sharePayloads = calculatedShares.map { userId, amount in
            InsertSharePayload(expense_id: expense.id, user_id: userId, share_amount: amount)
        }

        let _: [SplitExpenseShare] = try await client.insert(
            table: "split_expense_shares",
            value: sharePayloads,
            authToken: token
        )

        return expense
    }

    public func deleteExpense(expenseId: UUID) async throws {
        try await client.delete(
            table: "split_expenses",
            filters: [URLQueryItem(name: "id", value: "eq.\(expenseId.uuidString)")],
            authToken: token
        )
    }
}
