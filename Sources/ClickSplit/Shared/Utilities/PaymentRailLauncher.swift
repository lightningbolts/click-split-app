import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Helper for launching external peer-to-peer payment rails (Venmo, Cash App, PayPal, Zelle).
public enum PaymentRailLauncher {
    /// Builds the deep link or web fallback URL for the given payment rail.
    public static func generatePaymentURL(
        method: SettlementMethod,
        recipientHandle: String? = nil,
        amount: Decimal,
        note: String = "Click Split Settlement"
    ) -> URL? {
        let cleanHandle = recipientHandle?.trimmingCharacters(in: CharacterSet(charactersIn: "@$ ")).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let amountString = String(describing: amount)

        switch method {
        case .venmo:
            if !cleanHandle.isEmpty {
                return URL(string: "venmo://paycharge?txn=pay&recipients=\(cleanHandle)&amount=\(amountString)&note=\(encodedNote)")
            }
            return URL(string: "https://venmo.com")

        case .cashApp:
            if !cleanHandle.isEmpty {
                return URL(string: "https://cash.app/$\(cleanHandle)/\(amountString)")
            }
            return URL(string: "https://cash.app")

        case .paypal:
            if !cleanHandle.isEmpty {
                return URL(string: "https://paypal.me/\(cleanHandle)/\(amountString)")
            }
            return URL(string: "https://paypal.com")

        case .zelle, .cash, .other:
            return nil
        }
    }

    /// Builds the browser fallback for payment rails that support a recipient-specific web flow.
    public static func generateWebFallbackURL(
        method: SettlementMethod,
        recipientHandle: String? = nil,
        amount: Decimal,
        note: String = "Click Split Settlement"
    ) -> URL? {
        let cleanHandle = recipientHandle?.trimmingCharacters(in: CharacterSet(charactersIn: "@$ ")).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let amountString = String(describing: amount)

        switch method {
        case .venmo:
            guard !cleanHandle.isEmpty else { return URL(string: "https://venmo.com") }
            return URL(string: "https://venmo.com/?txn=pay&recipients=\(cleanHandle)&amount=\(amountString)&note=\(encodedNote)")
        case .paypal:
            guard !cleanHandle.isEmpty else { return URL(string: "https://paypal.com") }
            return URL(string: "https://paypal.me/\(cleanHandle)/\(amountString)")
        case .cashApp:
            guard !cleanHandle.isEmpty else { return URL(string: "https://cash.app") }
            return URL(string: "https://cash.app/$\(cleanHandle)/\(amountString)")
        case .zelle, .cash, .other:
            return nil
        }
    }

    /// Launches the chosen external payment app or a recipient-specific web fallback.
    ///
    /// Do not preflight custom schemes with canOpenURL here. Without an
    /// LSApplicationQueriesSchemes entry, iOS reports false even when the app is installed,
    /// which previously caused Venmo to fall back to its generic landing page.
    @MainActor
    public static func openPaymentRail(
        method: SettlementMethod,
        recipientHandle: String? = nil,
        amount: Decimal,
        note: String = "Click Split Settlement"
    ) {
        #if canImport(UIKit)
        guard let primaryURL = generatePaymentURL(
            method: method,
            recipientHandle: recipientHandle,
            amount: amount,
            note: note
        ) else {
            return
        }

        if method == .venmo {
            UIApplication.shared.open(primaryURL, options: [:]) { opened in
                guard !opened,
                      let fallbackURL = generateWebFallbackURL(
                        method: method,
                        recipientHandle: recipientHandle,
                        amount: amount,
                        note: note
                      ) else {
                    return
                }

                Task { @MainActor in
                    UIApplication.shared.open(fallbackURL)
                }
            }
            return
        }

        // HTTPS payment links are also universal-link capable when the provider supports it,
        // while remaining usable in the browser if the provider app is unavailable.
        UIApplication.shared.open(primaryURL)
        #endif
    }
}
