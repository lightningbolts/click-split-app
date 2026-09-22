import Foundation

/// Mathematical and financial allocation engine for Click Split.
/// Operates strictly on integer cents and Decimal arithmetic to prevent floating-point rounding errors.
public enum SplitCalculator {
    public enum SplitError: LocalizedError, Equatable {
        case emptyParticipants
        case invalidTotal
        case percentageSumMismatch(actual: Decimal)
        case negativeShare

        public var errorDescription: String? {
            switch self {
            case .emptyParticipants:
                return "Cannot calculate split with no participants."
            case .invalidTotal:
                return "Total amount must be greater than or equal to zero."
            case .percentageSumMismatch(let actual):
                return "Custom percentages must sum to 100%. Current sum: \(actual)%."
            case .negativeShare:
                return "Calculated share cannot be negative."
            }
        }
    }

    /// Calculates deterministic even split across participants down to the exact cent.
    /// Distributes remainder pennies to the first N participants so `sum(shares) == total`.
    public static func calculateEvenSplit(
        total: Decimal,
        participantUserIds: [UUID]
    ) throws -> [UUID: Decimal] {
        guard !participantUserIds.isEmpty else {
            throw SplitError.emptyParticipants
        }
        guard total >= 0 else {
            throw SplitError.invalidTotal
        }

        let totalCents = (total * 100 as NSDecimalNumber).intValue
        let count = participantUserIds.count
        let baseCents = totalCents / count
        let remainderCents = totalCents % count

        var result: [UUID: Decimal] = [:]
        for (index, userId) in participantUserIds.enumerated() {
            let userCents = baseCents + (index < remainderCents ? 1 : 0)
            result[userId] = Decimal(userCents) / 100
        }

        return result
    }

    /// Calculates shares from custom percentages, ensuring they sum to 100%.
    public static func calculateCustomPercentageSplit(
        total: Decimal,
        percentages: [UUID: Decimal]
    ) throws -> [UUID: Decimal] {
        guard !percentages.isEmpty else {
            throw SplitError.emptyParticipants
        }
        guard total >= 0 else {
            throw SplitError.invalidTotal
        }

        let sumPercentage = percentages.values.reduce(Decimal.zero, +)
        // Allow tiny delta for fractional inputs
        if abs(sumPercentage - 100) > Decimal(string: "0.01")! {
            throw SplitError.percentageSumMismatch(actual: sumPercentage)
        }

        let totalCents = (total * 100 as NSDecimalNumber).intValue
        var allocatedCents = 0
        var result: [UUID: Decimal] = [:]

        // Sort keys for deterministic order
        let sortedUserIds = percentages.keys.sorted { $0.uuidString < $1.uuidString }

        for (index, userId) in sortedUserIds.enumerated() {
            let percent = percentages[userId] ?? 0
            if index == sortedUserIds.count - 1 {
                // Last user gets the exact difference to guarantee sum matches total
                let remainingCents = max(0, totalCents - allocatedCents)
                result[userId] = Decimal(remainingCents) / 100
            } else {
                let userCents = ((Decimal(totalCents) * percent) / 100 as NSDecimalNumber).intValue
                allocatedCents += userCents
                result[userId] = Decimal(userCents) / 100
            }
        }

        return result
    }

    /// Calculates shares based on itemized receipts.
    /// Items assigned to nil are split evenly across all participants.
    public static func calculateByItemSplit(
        items: [SplitExpenseItem],
        allParticipantUserIds: [UUID]
    ) throws -> [UUID: Decimal] {
        guard !allParticipantUserIds.isEmpty else {
            throw SplitError.emptyParticipants
        }

        var userCents: [UUID: Int] = [:]
        for uid in allParticipantUserIds {
            userCents[uid] = 0
        }

        for item in items {
            let itemCents = (item.price * 100 as NSDecimalNumber).intValue
            if let assigned = item.assignedTo, allParticipantUserIds.contains(assigned) {
                userCents[assigned, default: 0] += itemCents
            } else {
                // Split evenly across all participants
                let count = allParticipantUserIds.count
                let base = itemCents / count
                let rem = itemCents % count
                for (idx, uid) in allParticipantUserIds.enumerated() {
                    userCents[uid, default: 0] += base + (idx < rem ? 1 : 0)
                }
            }
        }

        return userCents.mapValues { Decimal($0) / 100 }
    }

    /// Computes net balance from expenses and settlements for a group.
    /// Positive = user is owed money. Negative = user owes money.
    public static func computeNetBalance(
        for userId: UUID,
        expenses: [SplitExpense],
        shares: [SplitExpenseShare],
        settlements: [SplitSettlement]
    ) -> Decimal {
        var netCents: Int = 0

        // Expenses paid by this user: others owe their shares
        let expenseMap = Dictionary(uniqueKeysWithValues: expenses.map { ($0.id, $0) })

        for share in shares {
            guard let expense = expenseMap[share.expenseId] else { continue }
            let shareCents = (share.shareAmount * 100 as NSDecimalNumber).intValue

            if expense.paidBy == userId && share.userId != userId {
                netCents += shareCents
            } else if expense.paidBy != userId && share.userId == userId {
                netCents -= shareCents
            }
        }

        // Settlements
        for settlement in settlements {
            let settlementCents = (settlement.amount * 100 as NSDecimalNumber).intValue
            if settlement.fromUser == userId {
                // User paid someone -> reduces what they owe (adds to net)
                netCents += settlementCents
            } else if settlement.toUser == userId {
                // User received payment -> reduces what is owed to them (subtracts from net)
                netCents -= settlementCents
            }
        }

        return Decimal(netCents) / 100
    }
}
