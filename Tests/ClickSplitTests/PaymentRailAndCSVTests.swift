import XCTest
@testable import ClickSplit

final class PaymentRailAndCSVTests: XCTestCase {
    func testCSVExportFormatting() {
        let u1 = UUID()
        let member = SplitGroupMember(
            groupId: UUID(),
            userId: u1,
            profile: SplitUserProfile(id: u1, fullName: "Alice Smith")
        )

        let expense = SplitExpense(
            groupId: member.groupId,
            description: "Dinner, Drinks & Tips",
            totalAmount: Decimal(string: "78.50")!,
            paidBy: u1,
            splitMethod: .even,
            source: .manual
        )

        let csv = CSVExporter.generateCSV(
            groupName: "Tahoe Trip",
            expenses: [expense],
            members: [member]
        )

        XCTAssertTrue(csv.contains("Date,Description,Total Amount,Paid By,Split Method"))
        XCTAssertTrue(csv.contains("Dinner  Drinks & Tips"))
        XCTAssertTrue(csv.contains("78.5"))
        XCTAssertTrue(csv.contains("Alice Smith"))
        XCTAssertTrue(csv.contains("Even"))
    }

    func testSettlementMethodDecodesWebAndLegacyValues() throws {
        let decoder = JSONDecoder()

        func decode(_ value: String) throws -> SettlementMethod {
            try decoder.decode(SettlementMethod.self, from: Data("\"\(value)\"".utf8))
        }

        XCTAssertEqual(try decode("cashapp"), .cashApp)
        XCTAssertEqual(try decode("cash_app"), .cashApp)
        XCTAssertEqual(try decode("applepay"), .other)
        XCTAssertEqual(try decode("googlepay"), .other)
        XCTAssertEqual(try decode("manual"), .other)
        XCTAssertEqual(try decode("future_payment_rail"), .other)
        XCTAssertEqual(SettlementMethod.cashApp.rawValue, "cashapp")
    }

    func testPaymentRailURLGeneration() {
        // Venmo
        let venmoURL = PaymentRailLauncher.generatePaymentURL(
            method: .venmo,
            recipientHandle: "@alice",
            amount: Decimal(string: "42.50")!,
            note: "Split lunch"
        )
        XCTAssertEqual(venmoURL?.scheme, "venmo")
        XCTAssertTrue(venmoURL?.absoluteString.contains("recipients=alice") == true)
        XCTAssertTrue(venmoURL?.absoluteString.contains("amount=42.5") == true)

        // Cash App
        let cashAppURL = PaymentRailLauncher.generatePaymentURL(
            method: .cashApp,
            recipientHandle: "$bob",
            amount: Decimal(string: "15.00")!
        )
        XCTAssertEqual(cashAppURL?.absoluteString, "https://cash.app/$bob/15")

        // PayPal
        let paypalURL = PaymentRailLauncher.generatePaymentURL(
            method: .paypal,
            recipientHandle: "charlie",
            amount: Decimal(string: "25.00")!
        )
        XCTAssertEqual(paypalURL?.absoluteString, "https://paypal.me/charlie/25")

        // Zelle / Cash / Other returns nil (requires in-person / manual bank flow)
        let zelleURL = PaymentRailLauncher.generatePaymentURL(
            method: .zelle,
            recipientHandle: "user@bank.com",
            amount: Decimal(10)
        )
        XCTAssertNil(zelleURL)
    }
    func testPaymentRailWebFallbackPreservesRecipientAndAmount() {
        let venmoFallback = PaymentRailLauncher.generateWebFallbackURL(
            method: .venmo,
            recipientHandle: "@alice",
            amount: Decimal(string: "42.50")!,
            note: "Split lunch"
        )
        XCTAssertTrue(venmoFallback?.absoluteString.contains("recipients=alice") == true)
        XCTAssertTrue(venmoFallback?.absoluteString.contains("amount=42.5") == true)

        let paypalFallback = PaymentRailLauncher.generateWebFallbackURL(
            method: .paypal,
            recipientHandle: "charlie",
            amount: Decimal(string: "25.00")!
        )
        XCTAssertEqual(paypalFallback?.absoluteString, "https://paypal.me/charlie/25")
    }

}
