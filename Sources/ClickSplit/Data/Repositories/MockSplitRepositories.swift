import Foundation

/// In-memory repository implementing GroupRepositoryProtocol for tests and previews.
public actor MockGroupRepository: GroupRepositoryProtocol {
    private var groups: [SplitGroup] = []
    private var members: [UUID: [SplitGroupMember]] = [:]
    private var balances: [String: Decimal] = [:]

    public init(sampleData: Bool = true) {
        if sampleData {
            let currentUserId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            let alexId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
            let noahId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
            let claireId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

            let g1 = SplitGroup(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                name: "Vancouver Trip",
                icon: "🌲",
                createdBy: currentUserId
            )
            let g2 = SplitGroup(
                id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                name: "Seattle Food",
                icon: "🍜",
                createdBy: alexId
            )

            self.groups = [g1, g2]

            self.members = [
                g1.id: [
                    SplitGroupMember(groupId: g1.id, userId: currentUserId, profile: SplitUserProfile(id: currentUserId, fullName: "You")),
                    SplitGroupMember(groupId: g1.id, userId: alexId, profile: SplitUserProfile(id: alexId, fullName: "Alex")),
                    SplitGroupMember(groupId: g1.id, userId: noahId, profile: SplitUserProfile(id: noahId, fullName: "Noah")),
                ],
                g2.id: [
                    SplitGroupMember(groupId: g2.id, userId: currentUserId, profile: SplitUserProfile(id: currentUserId, fullName: "You")),
                    SplitGroupMember(groupId: g2.id, userId: alexId, profile: SplitUserProfile(id: alexId, fullName: "Alex")),
                    SplitGroupMember(groupId: g2.id, userId: claireId, profile: SplitUserProfile(id: claireId, fullName: "Claire")),
                ]
            ]

            self.balances = [
                "\(g1.id)-\(currentUserId)": Decimal(string: "42.08")!,
                "\(g2.id)-\(currentUserId)": Decimal(string: "84.20")!
            ]
        } else {
            self.groups = []
            self.members = [:]
            self.balances = [:]
        }
    }

    public func fetchUserGroups(userId: UUID) async throws -> [SplitGroup] {
        return groups
    }

    public func fetchGroup(id: UUID) async throws -> SplitGroup? {
        return groups.first { $0.id == id }
    }

    public func fetchGroupMembers(groupId: UUID) async throws -> [SplitGroupMember] {
        return members[groupId] ?? []
    }

    public func createGroup(name: String, icon: String?, createdBy: UUID) async throws -> SplitGroup {
        let newGroup = SplitGroup(name: name, icon: icon, createdBy: createdBy)
        groups.append(newGroup)
        let member = SplitGroupMember(groupId: newGroup.id, userId: createdBy)
        members[newGroup.id] = [member]
        balances["\(newGroup.id)-\(createdBy)"] = 0
        return newGroup
    }

    public func joinGroup(groupId: UUID, userId: UUID) async throws {
        guard groups.contains(where: { $0.id == groupId }) else { return }
        var list = members[groupId] ?? []
        if !list.contains(where: { $0.userId == userId }) {
            list.append(SplitGroupMember(groupId: groupId, userId: userId))
            members[groupId] = list
        }
    }

    public func leaveGroup(groupId: UUID, userId: UUID) async throws {
        members[groupId]?.removeAll { $0.userId == userId }
    }

    public func deleteGroup(groupId: UUID) async throws {
        groups.removeAll { $0.id == groupId }
        members.removeValue(forKey: groupId)
    }

    public func fetchGroupBalance(groupId: UUID, userId: UUID) async throws -> Decimal {
        return balances["\(groupId)-\(userId)"] ?? Decimal.zero
    }
}

/// In-memory repository implementing ExpenseRepositoryProtocol.
public actor MockExpenseRepository: ExpenseRepositoryProtocol {
    private var expenses: [SplitExpense] = []
    private var items: [UUID: [SplitExpenseItem]] = [:]
    private var shares: [UUID: [SplitExpenseShare]] = [:]

    public init(sampleData: Bool = true) {
        if sampleData {
            let g1 = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
            let g2 = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
            let currentUserId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            let alexId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
            let noahId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
            let claireId = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

            let e0 = SplitExpense(
                groupId: g1,
                description: "Campsite Rental",
                totalAmount: 126.24,
                paidBy: currentUserId,
                splitMethod: .even
            )
            let e1 = SplitExpense(
                groupId: g2,
                description: "Dinner",
                totalAmount: 120,
                paidBy: alexId,
                splitMethod: .even
            )
            let e2 = SplitExpense(
                groupId: g2,
                description: "Coffee",
                totalAmount: 18,
                paidBy: currentUserId,
                splitMethod: .even
            )

            self.expenses = [e0, e1, e2]
            self.items = [:]
            self.shares = [
                e0.id: [
                    SplitExpenseShare(expenseId: e0.id, userId: currentUserId, shareAmount: Decimal(string: "42.08")!),
                    SplitExpenseShare(expenseId: e0.id, userId: alexId, shareAmount: Decimal(string: "42.08")!),
                    SplitExpenseShare(expenseId: e0.id, userId: noahId, shareAmount: Decimal(string: "42.08")!)
                ],
                e1.id: [
                    SplitExpenseShare(expenseId: e1.id, userId: currentUserId, shareAmount: 40),
                    SplitExpenseShare(expenseId: e1.id, userId: alexId, shareAmount: 40),
                    SplitExpenseShare(expenseId: e1.id, userId: claireId, shareAmount: 40)
                ],
                e2.id: [
                    SplitExpenseShare(expenseId: e2.id, userId: currentUserId, shareAmount: 6),
                    SplitExpenseShare(expenseId: e2.id, userId: alexId, shareAmount: 6),
                    SplitExpenseShare(expenseId: e2.id, userId: claireId, shareAmount: 6)
                ]
            ]
        } else {
            self.expenses = []
            self.items = [:]
            self.shares = [:]
        }
    }

    public func fetchExpenses(groupId: UUID) async throws -> [SplitExpense] {
        return expenses.filter { $0.groupId == groupId }
    }

    public func fetchExpenseItems(expenseId: UUID) async throws -> [SplitExpenseItem] {
        return items[expenseId] ?? []
    }

    public func fetchExpenseShares(expenseId: UUID) async throws -> [SplitExpenseShare] {
        return shares[expenseId] ?? []
    }

    public func createExpense(draft: ExpenseDraft, groupId: UUID) async throws -> SplitExpense {
        let expense = SplitExpense(
            groupId: groupId,
            description: draft.description,
            totalAmount: draft.total,
            paidBy: draft.payerID,
            splitMethod: draft.splitMethod,
            source: draft.receipt != nil ? .receiptScan : .manual
        )
        expenses.insert(expense, at: 0)
        items[expense.id] = draft.items.map {
            SplitExpenseItem(expenseId: expense.id, label: $0.label, price: $0.price, assignedTo: $0.assignedTo)
        }
        return expense
    }

    public func updateExpense(draft: ExpenseDraft, groupId: UUID, expenseId: UUID) async throws -> SplitExpense {
        guard let existing = expenses.first(where: { $0.id == expenseId }) else {
            throw NSError(domain: "ClickSplit.MockExpenseRepository", code: 404)
        }

        let updated = SplitExpense(
            id: existing.id,
            groupId: groupId,
            description: draft.description,
            totalAmount: draft.total,
            paidBy: draft.payerID,
            splitMethod: draft.splitMethod,
            source: existing.source,
            receiptImageUrl: existing.receiptImageUrl,
            createdAt: existing.createdAt
        )

        if let index = expenses.firstIndex(where: { $0.id == expenseId }) {
            expenses[index] = updated
        }
        items[expenseId] = draft.items.map {
            SplitExpenseItem(expenseId: expenseId, label: $0.label, price: $0.price, assignedTo: $0.assignedTo)
        }
        return updated
    }

    public func deleteExpense(expenseId: UUID) async throws {
        expenses.removeAll { $0.id == expenseId }
        items.removeValue(forKey: expenseId)
        shares.removeValue(forKey: expenseId)
    }
}

/// In-memory repository implementing SettlementRepositoryProtocol.
public actor MockSettlementRepository: SettlementRepositoryProtocol {
    private var settlements: [SplitSettlement] = []

    public init() {}

    public func fetchSettlements(groupId: UUID) async throws -> [SplitSettlement] {
        return settlements.filter { $0.groupId == groupId }
    }

    public func recordSettlement(
        groupId: UUID,
        fromUser: UUID,
        toUser: UUID,
        amount: Decimal,
        method: SettlementMethod?
    ) async throws -> SplitSettlement {
        let settlement = SplitSettlement(
            groupId: groupId,
            fromUser: fromUser,
            toUser: toUser,
            amount: amount,
            method: method
        )
        settlements.append(settlement)
        return settlement
    }
}
