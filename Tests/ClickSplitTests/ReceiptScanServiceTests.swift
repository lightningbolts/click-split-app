import XCTest
@testable import ClickSplit

final class ReceiptScanServiceTests: XCTestCase {
    func testMergeOCRPagesRemovesOnlyBoundaryOverlap() {
        let pages = [
            ["Cafe Example", "Latte 5.50", "Sandwich 9.25", "Cookie 3.00"],
            ["Sandwich 9.25", "Cookie 3.00", "Sparkling Water 4.00", "Subtotal 21.75"],
            ["Subtotal 21.75", "Tax 2.18", "TOTAL 23.93"],
        ]

        XCTAssertEqual(
            ReceiptScanService.mergeOCRPages(pages),
            [
                "Cafe Example",
                "Latte 5.50",
                "Sandwich 9.25",
                "Cookie 3.00",
                "Sparkling Water 4.00",
                "Subtotal 21.75",
                "Tax 2.18",
                "TOTAL 23.93",
            ]
        )
    }

    func testMergeOCRPagesPreservesLegitimateRepeatedItems() {
        let pages = [
            ["Coffee 4.00", "Coffee 4.00", "Bagel 5.00"],
            ["Bagel 5.00", "Juice 3.00"],
        ]

        XCTAssertEqual(
            ReceiptScanService.mergeOCRPages(pages),
            ["Coffee 4.00", "Coffee 4.00", "Bagel 5.00", "Juice 3.00"]
        )
    }

    func testMergeOCRPagesNormalizesWhitespaceForOverlapMatching() {
        let pages = [
            ["Item A 2.00", "Item    B   3.00"],
            [" item b 3.00 ", "Item C 4.00"],
        ]

        XCTAssertEqual(
            ReceiptScanService.mergeOCRPages(pages),
            ["Item A 2.00", "Item    B   3.00", "Item C 4.00"]
        )
    }
}
