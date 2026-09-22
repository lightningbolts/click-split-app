import Foundation

/// Method used to distribute an expense among group members.
public enum SplitMethod: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    case even = "even"
    case byItem = "by_item"
    case customPercent = "custom_percent"

    public var description: String {
        switch self {
        case .even: return "Even"
        case .byItem: return "By Item"
        case .customPercent: return "Custom %"
        }
    }
}

/// Source indicating how an expense was captured.
public enum ExpenseSource: String, Codable, Sendable {
    case manual = "manual"
    case receiptScan = "receipt_scan"
}

/// Peer-to-peer external settlement rails.
public enum SettlementMethod: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    case venmo = "venmo"
    case paypal = "paypal"
    case cashApp = "cash_app"
    case zelle = "zelle"
    case cash = "cash"
    case other = "other"

    public var description: String {
        switch self {
        case .venmo: return "Venmo"
        case .paypal: return "PayPal"
        case .cashApp: return "Cash App"
        case .zelle: return "Zelle"
        case .cash: return "Cash"
        case .other: return "Other"
        }
    }
}

/// Click Split Group representation matching `public.split_groups`.
public struct SplitGroup: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var icon: String?
    public let createdBy: UUID
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String? = nil,
        createdBy: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}

/// Membership in a Split Group matching `public.split_group_members`.
public struct SplitGroupMember: Identifiable, Codable, Sendable, Hashable {
    public var id: String { "\(groupId.uuidString)-\(userId.uuidString)" }
    public let groupId: UUID
    public let userId: UUID
    public let joinedAt: Date
    public var profile: SplitUserProfile?

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case profile
    }

    public init(
        groupId: UUID,
        userId: UUID,
        joinedAt: Date = Date(),
        profile: SplitUserProfile? = nil
    ) {
        self.groupId = groupId
        self.userId = userId
        self.joinedAt = joinedAt
        self.profile = profile
    }
}

/// User profile representation in the shared Click system.
public struct SplitUserProfile: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var email: String?
    public var fullName: String?
    public var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }

    public init(
        id: UUID,
        email: String? = nil,
        fullName: String? = nil,
        avatarUrl: String? = nil
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.avatarUrl = avatarUrl
    }

    public var displayName: String {
        if let fullName = fullName, !fullName.trimmingCharacters(in: .whitespaces).isEmpty {
            return fullName
        }
        if let email = email, !email.isEmpty {
            return email.components(separatedBy: "@").first ?? email
        }
        return "Member"
    }
}

/// Expense record matching `public.split_expenses`.
public struct SplitExpense: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let groupId: UUID
    public var description: String
    public var totalAmount: Decimal
    public let paidBy: UUID
    public var splitMethod: SplitMethod
    public var source: ExpenseSource
    public var receiptImageUrl: String?
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case description
        case totalAmount = "total_amount"
        case paidBy = "paid_by"
        case splitMethod = "split_method"
        case source
        case receiptImageUrl = "receipt_image_url"
        case createdAt = "created_at"
    }

    public init(
        id: UUID = UUID(),
        groupId: UUID,
        description: String,
        totalAmount: Decimal,
        paidBy: UUID,
        splitMethod: SplitMethod = .even,
        source: ExpenseSource = .manual,
        receiptImageUrl: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.description = description
        self.totalAmount = totalAmount
        self.paidBy = paidBy
        self.splitMethod = splitMethod
        self.source = source
        self.receiptImageUrl = receiptImageUrl
        self.createdAt = createdAt
    }
}

/// Individual item on an itemized expense matching `public.split_expense_items`.
public struct SplitExpenseItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let expenseId: UUID
    public var label: String
    public var price: Decimal
    public var assignedTo: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case expenseId = "expense_id"
        case label
        case price
        case assignedTo = "assigned_to"
    }

    public init(
        id: UUID = UUID(),
        expenseId: UUID,
        label: String,
        price: Decimal,
        assignedTo: UUID? = nil
    ) {
        self.id = id
        self.expenseId = expenseId
        self.label = label
        self.price = price
        self.assignedTo = assignedTo
    }
}

/// Share of an expense assigned to a user matching `public.split_expense_shares`.
public struct SplitExpenseShare: Codable, Sendable, Hashable {
    public let expenseId: UUID
    public let userId: UUID
    public var shareAmount: Decimal

    enum CodingKeys: String, CodingKey {
        case expenseId = "expense_id"
        case userId = "user_id"
        case shareAmount = "share_amount"
    }

    public init(
        expenseId: UUID,
        userId: UUID,
        shareAmount: Decimal
    ) {
        self.expenseId = expenseId
        self.userId = userId
        self.shareAmount = shareAmount
    }
}

/// Settlement record matching `public.split_settlements`.
public struct SplitSettlement: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let groupId: UUID
    public let fromUser: UUID
    public let toUser: UUID
    public var amount: Decimal
    public var method: SettlementMethod?
    public let settledAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case fromUser = "from_user"
        case toUser = "to_user"
        case amount
        case method
        case settledAt = "settled_at"
    }

    public init(
        id: UUID = UUID(),
        groupId: UUID,
        fromUser: UUID,
        toUser: UUID,
        amount: Decimal,
        method: SettlementMethod? = nil,
        settledAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.fromUser = fromUser
        self.toUser = toUser
        self.amount = amount
        self.method = method
        self.settledAt = settledAt
    }
}

// ────────────────── Value Drafts (Section 18) ──────────────────

/// In-progress item during expense creation.
public struct ExpenseItemDraft: Identifiable, Sendable, Hashable {
    public var id: UUID
    public var label: String
    public var price: Decimal
    public var assignedTo: UUID?

    public init(
        id: UUID = UUID(),
        label: String = "",
        price: Decimal = 0,
        assignedTo: UUID? = nil
    ) {
        self.id = id
        self.label = label
        self.price = price
        self.assignedTo = assignedTo
    }
}

/// In-progress custom percentage or dollar share per member.
public struct MemberShareDraft: Identifiable, Sendable, Hashable {
    public var id: UUID { userId }
    public var userId: UUID
    public var percentage: Decimal
    public var computedAmount: Decimal

    public init(
        userId: UUID,
        percentage: Decimal = 0,
        computedAmount: Decimal = 0
    ) {
        self.userId = userId
        self.percentage = percentage
        self.computedAmount = computedAmount
    }
}

/// Draft receipt attached to an expense.
public struct ReceiptDraft: Sendable, Hashable {
    public var localImageURL: URL?
    public var rawText: String?
    public var recognizedItems: [ExpenseItemDraft]

    public init(
        localImageURL: URL? = nil,
        rawText: String? = nil,
        recognizedItems: [ExpenseItemDraft] = []
    ) {
        self.localImageURL = localImageURL
        self.rawText = rawText
        self.recognizedItems = recognizedItems
    }
}

/// Explicit value model representing an in-flight expense draft.
public struct ExpenseDraft: Sendable {
    public var description: String
    public var total: Decimal
    public var payerID: UUID
    public var splitMethod: SplitMethod
    public var items: [ExpenseItemDraft]
    public var customShares: [MemberShareDraft]
    public var receipt: ReceiptDraft?

    public init(
        description: String = "",
        total: Decimal = 0,
        payerID: UUID,
        splitMethod: SplitMethod = .even,
        items: [ExpenseItemDraft] = [],
        customShares: [MemberShareDraft] = [],
        receipt: ReceiptDraft? = nil
    ) {
        self.description = description
        self.total = total
        self.payerID = payerID
        self.splitMethod = splitMethod
        self.items = items
        self.customShares = customShares
        self.receipt = receipt
    }
}
