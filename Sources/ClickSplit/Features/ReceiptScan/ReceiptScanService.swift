import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Vision)
import Vision
#endif

/// Result of receipt recognition and extraction.
public struct ReceiptExtractionResult: Codable, Sendable {
    public struct ScannedItem: Codable, Sendable {
        public let label: String
        public let price: Decimal

        public init(label: String, price: Decimal) {
            self.label = label
            self.price = price
        }
    }

    public let items: [ScannedItem]
    public let detectedTotal: Decimal?

    enum CodingKeys: String, CodingKey {
        case items
        case detectedTotal = "detected_total"
    }

    public init(items: [ScannedItem], detectedTotal: Decimal?) {
        self.items = items
        self.detectedTotal = detectedTotal
    }
}

/// Service handling receipt image processing, local Vision OCR, and server-side LLM extraction.
public final class ReceiptScanService: Sendable {
    private let serverBaseURL: URL
    private let session: URLSession

    public init(
        serverBaseURL: URL = SupabaseConfig.defaultServerBaseURL,
        session: URLSession = .shared
    ) {
        self.serverBaseURL = serverBaseURL
        self.session = session
    }

    #if canImport(UIKit)
    /// Compresses a captured receipt image to optimal dimensions and JPEG quality.
    public static func compressImage(_ image: UIImage, maxDimension: CGFloat = 1200) -> Data? {
        let size = image.size
        var targetSize = size

        if max(size.width, size.height) > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resized.jpegData(compressionQuality: 0.7)
    }

    /// Performs fast local on-device Vision OCR to extract raw text lines.
    public static func performLocalOCR(on imageData: Data) async throws -> [String] {
        guard let image = UIImage(data: imageData)?.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    #endif

    /// Sends the compressed receipt image to the backend extraction service, falling back to on-device Vision OCR parsing.
    public func extractReceipt(
        imageData: Data,
        authToken: String?
    ) async throws -> ReceiptExtractionResult {
        let base64String = imageData.base64EncodedString()
        let endpoint = serverBaseURL.appendingPathComponent("api/split/receipt-scan")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        struct Payload: Encodable {
            let image: String
        }

        request.httpBody = try JSONEncoder().encode(Payload(image: base64String))

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                let decoder = JSONDecoder()
                let result = try decoder.decode(ReceiptExtractionResult.self, from: data)
                if !result.items.isEmpty {
                    return result
                }
            }
        } catch {
            // Backend unavailable or failed; seamlessly fall through to on-device Vision OCR
        }

        #if canImport(UIKit) && canImport(Vision)
        // Perform on-device Apple Vision OCR and intelligent line item parsing
        let ocrLines = try await Self.performLocalOCR(on: imageData)
        let parsedResult = Self.parseReceiptLines(ocrLines)
        if !parsedResult.items.isEmpty {
            return parsedResult
        }
        #endif

        throw ReceiptScanError.noItemsFound
    }

    /// Intelligent on-device receipt parser extracting line items and prices from OCR text lines.
    public static func parseReceiptLines(_ lines: [String]) -> ReceiptExtractionResult {
        var items: [ReceiptExtractionResult.ScannedItem] = []
        var detectedTotal: Decimal?

        // Common receipt price regex: matches e.g. 5.49, $12.50, 8.99 S, etc.
        let pricePattern = try? NSRegularExpression(
            pattern: #"(?:^|\s)\$?([0-9]+\.[0-9]{2})(?:\s*[A-Za-z])?$"#
        )
        // Pattern to match all prices in a line (for "Price 10.99 You Pay 8.99" formats)
        let anyPricePattern = try? NSRegularExpression(
            pattern: #"\$?([0-9]+\.[0-9]{2})"#
        )

        let skipKeywords = [
            "SAFEWAY", "STORE", "TEL", "PHONE", "CASHIER", "MEMBER SAVINGS",
            "SAVINGS", "POINTS", "CARD #", "AUTH", "AID", "TVR", "VISA",
            "MASTERCARD", "CHANGE", "NOW HIRING", "THANK YOU", "QUESTIONS CALL",
            "VISIT", "TOTAL NUMBER OF ITEMS", "TAX", "SUBTOTAL"
        ]

        let totalKeywords = ["BALANCE", "TOTAL", "AMOUNT DUE", "AMOUNT PAID", "TOTAL OWED"]

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let upper = line.uppercased()

            // Check if this is a total line
            if totalKeywords.contains(where: { upper.contains($0) }) {
                if let anyPricePattern {
                    let matches = anyPricePattern.matches(in: line, range: NSRange(line.startIndex..., in: line))
                    if let lastMatch = matches.last,
                       let priceRange = Range(lastMatch.range(at: 1), in: line),
                       let priceVal = Decimal(string: String(line[priceRange])) {
                        detectedTotal = priceVal
                    }
                }
                continue
            }

            // Skip common metadata / non-item lines
            if skipKeywords.contains(where: { upper.contains($0) }) {
                continue
            }

            // Check if line contains a price
            if let anyPricePattern {
                let matches = anyPricePattern.matches(in: line, range: NSRange(line.startIndex..., in: line))
                guard let lastMatch = matches.last,
                      let priceRange = Range(lastMatch.range(at: 1), in: line),
                      let price = Decimal(string: String(line[priceRange])),
                      price > 0 else {
                    continue
                }

                // Everything before the price is the item description
                let matchStart = Range(lastMatch.range, in: line)!.lowerBound
                var label = String(line[..<matchStart]).trimmingCharacters(in: .whitespacesAndNewlines)

                // Strip leading barcodes/SKUs (e.g., "2040251667 DORITOS TRTLA CHPS" -> "DORITOS TRTLA CHPS")
                if let firstWord = label.split(separator: " ").first,
                   firstWord.count >= 4,
                   firstWord.allSatisfy(\.isNumber) {
                    label = label.dropFirst(firstWord.count).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Strip trailing noise like original price in "DORITOS 5.49" if two prices were present
                if let labelMatches = anyPricePattern.matches(in: label, range: NSRange(label.startIndex..., in: label)).last,
                   let labelMatchRange = Range(labelMatches.range, in: label) {
                    label = String(label[..<labelMatchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Remove unwanted prefixes like "WT 0.7 lb @"
                if label.uppercased().hasPrefix("WT ") {
                    continue
                }

                // Clean up any remaining trailing punctuation/noise
                label = label.trimmingCharacters(in: CharacterSet(charactersIn: "-:@$# \t"))

                if !label.isEmpty && label.count >= 2 {
                    items.append(.init(label: label, price: price))
                }
            }
        }

        let sum = items.reduce(Decimal.zero) { $0 + $1.price }
        return ReceiptExtractionResult(items: items, detectedTotal: detectedTotal ?? (sum > 0 ? sum : nil))
    }

    /// Realistic parsed items for offline testing or when explicitly triggered by the sample button.
    public static func mockExtractionFallback() -> ReceiptExtractionResult {
        let items: [ReceiptExtractionResult.ScannedItem] = [
            .init(label: "Burger with Cheese", price: Decimal(string: "16.50")!),
            .init(label: "Truffle Fries", price: Decimal(string: "8.00")!),
            .init(label: "Craft IPA", price: Decimal(string: "9.50")!),
            .init(label: "Sparkling Water", price: Decimal(string: "4.00")!)
        ]
        return ReceiptExtractionResult(items: items, detectedTotal: Decimal(string: "38.00")!)
    }
}

public enum ReceiptScanError: LocalizedError {
    case noItemsFound
    case backendError(String)

    public var errorDescription: String? {
        switch self {
        case .noItemsFound:
            return "Could not recognize any items from the receipt. Please ensure the image is clear and well-lit."
        case .backendError(let msg):
            return msg
        }
    }
}
