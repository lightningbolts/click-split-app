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
        // Fetch group members to calculate shares
        let members: [SplitGroupMember] = try await client.fetch(
            table: "split_group_members",
            filters: [URLQueryItem(name: "group_id", value: "eq.\(groupId.uuidString)")],
            authToken: token
        )
        let participantIds = members.map { $0.userId }

        // Compute shares using SplitCalculator
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
                SplitExpenseItem(expenseId: UUID(), label: $0.label, price: $0.price, assignedTo: $0.assignedTo)
            }
            calculatedShares = try SplitCalculator.calculateByItemSplit(items: domainItems, allParticipantUserIds: participantIds)
        }

        struct RPCItem: Encodable {
            let label: String
            let price: Decimal
            let assigned_to: UUID?
        }

        struct RPCShare: Encodable {
            let user_id: UUID
            let share_amount: Decimal
        }

        struct RPCParams: Encodable {
            let p_group_id: UUID
            let p_description: String
            let p_total_amount: Decimal
            let p_paid_by: UUID
            let p_split_method: String
            let p_source: String
            let p_receipt_image_url: String?
            let p_items: [RPCItem]
            let p_shares: [RPCShare]
        }

        let rpcItems = draft.items.map {
            RPCItem(label: $0.label, price: $0.price, assigned_to: $0.assignedTo)
        }
        let rpcShares = calculatedShares.map { userId, amount in
            RPCShare(user_id: userId, share_amount: amount)
        }

        let params = RPCParams(
            p_group_id: groupId,
            p_description: draft.description,
            p_total_amount: draft.total,
            p_paid_by: draft.payerID,
            p_split_method: draft.splitMethod.rawValue,
            p_source: draft.receipt != nil ? "receipt_scan" : "manual",
            p_receipt_image_url: nil,
            p_items: rpcItems,
            p_shares: rpcShares
        )

        do {
            // Call atomic transactional RPC
            let expenseId: UUID = try await client.rpc(
                name: "create_split_expense_transaction",
                params: params,
                authToken: token
            )

            return SplitExpense(
                id: expenseId,
                groupId: groupId,
                description: draft.description,
                totalAmount: draft.total,
                paidBy: draft.payerID,
                splitMethod: draft.splitMethod,
                source: draft.receipt != nil ? .receiptScan : .manual,
                receiptImageUrl: nil,
                createdAt: Date()
            )
        } catch {
            // Fallback to table inserts if RPC is not yet migrated on backend
            return try await fallbackSequentialCreate(
                draft: draft,
                groupId: groupId,
                calculatedShares: calculatedShares
            )
        }
    }

    private func fallbackSequentialCreate(
        draft: ExpenseDraft,
        groupId: UUID,
        calculatedShares: [UUID: Decimal]
    ) async throws -> SplitExpense {
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
