import XCTest
@testable import ClickSplit

final class SplitCalculatorTests: XCTestCase {
    func testEvenSplitThreePeoplePennyPrecision() throws {
        let u1 = UUID()
        let u2 = UUID()
        let u3 = UUID()
        let total = Decimal(string: "10.00")!

        let shares = try SplitCalculator.calculateEvenSplit(total: total, participantUserIds: [u1, u2, u3])

        XCTAssertEqual(shares.count, 3)
        // 1000 cents / 3 = 333 cents + 1 remainder cent
        XCTAssertEqual(shares[u1], Decimal(string: "3.34")!)
        XCTAssertEqual(shares[u2], Decimal(string: "3.33")!)
        XCTAssertEqual(shares[u3], Decimal(string: "3.33")!)

        let sum = shares.values.reduce(Decimal.zero, +)
        XCTAssertEqual(sum, total)
    }

    func testCustomPercentageSplit() throws {
        let u1 = UUID()
        let u2 = UUID()
        let total = Decimal(string: "150.00")!
        let percentages: [UUID: Decimal] = [
            u1: 60,
            u2: 40
        ]

        let shares = try SplitCalculator.calculateCustomPercentageSplit(total: total, percentages: percentages)

        XCTAssertEqual(shares[u1], Decimal(string: "90.00")!)
        XCTAssertEqual(shares[u2], Decimal(string: "60.00")!)

        let sum = shares.values.reduce(Decimal.zero, +)
        XCTAssertEqual(sum, total)
    }

    func testCustomPercentageMismatchThrows() {
        let u1 = UUID()
        let u2 = UUID()
        let total = Decimal(string: "100.00")!
        let percentages: [UUID: Decimal] = [
            u1: 50,
            u2: 40 // Sums to 90%, should throw
        ]

        XCTAssertThrowsError(try SplitCalculator.calculateCustomPercentageSplit(total: total, percentages: percentages))
    }

    func testByItemSplit() throws {
        let u1 = UUID()
        let u2 = UUID()
        let sharedItemExpenseId = UUID()

        let item1 = SplitExpenseItem(expenseId: sharedItemExpenseId, label: "Burger", price: 15, assignedTo: u1)
        let item2 = SplitExpenseItem(expenseId: sharedItemExpenseId, label: "Pizza", price: 20, assignedTo: u2)
        let item3 = SplitExpenseItem(expenseId: sharedItemExpenseId, label: "Shared Fries", price: 6, assignedTo: nil)

        let shares = try SplitCalculator.calculateByItemSplit(
            items: [item1, item2, item3],
            allParticipantUserIds: [u1, u2]
        )

        // u1: 15 + 3 = 18
        // u2: 20 + 3 = 23
        XCTAssertEqual(shares[u1], Decimal(18))
        XCTAssertEqual(shares[u2], Decimal(23))
    }

    func testByItemSplitReconcilesTaxAndTipToExpenseTotal() throws {
        let u1 = UUID()
        let u2 = UUID()
        let expenseId = UUID()

        let item1 = SplitExpenseItem(expenseId: expenseId, label: "Entree", price: 10, assignedTo: u1)
        let item2 = SplitExpenseItem(expenseId: expenseId, label: "Drink", price: 10, assignedTo: u2)

        let shares = try SplitCalculator.calculateByItemSplit(
            items: [item1, item2],
            allParticipantUserIds: [u1, u2],
            total: Decimal(string: "24.00")!
        )

        XCTAssertEqual(shares[u1], Decimal(string: "12.00")!)
        XCTAssertEqual(shares[u2], Decimal(string: "12.00")!)
        XCTAssertEqual(shares.values.reduce(Decimal.zero, +), Decimal(string: "24.00")!)
    }

    func testNetBalanceComputation() {
        let currentUserId = UUID()
        let otherUserId = UUID()
        let expenseId = UUID()

        // Expense of $100 paid by currentUserId, other owes $50
        let expense = SplitExpense(
            id: expenseId,
            groupId: UUID(),
            description: "Groceries",
            totalAmount: 100,
            paidBy: currentUserId,
            splitMethod: .even
        )

        let shares = [
            SplitExpenseShare(expenseId: expenseId, userId: currentUserId, shareAmount: 50),
            SplitExpenseShare(expenseId: expenseId, userId: otherUserId, shareAmount: 50)
        ]

        // Other pays $20 settlement to current user
        let settlement = SplitSettlement(
            groupId: expense.groupId,
            fromUser: otherUserId,
            toUser: currentUserId,
            amount: 20
        )

        let net = SplitCalculator.computeNetBalance(
            for: currentUserId,
            expenses: [expense],
            shares: shares,
            settlements: [settlement]
        )

        // Net should be +50 (owed) - 20 (received) = +30
        XCTAssertEqual(net, Decimal(30))
    }
}
