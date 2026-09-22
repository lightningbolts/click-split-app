import SwiftUI

/// Modal workflow for recording peer-to-peer settlements and external rail launches.
public struct SettleUpView: View {
    public var group: SplitGroup
    public var members: [SplitGroupMember]
    public var onSettled: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var selectedRecipientId: UUID
    @State private var amountString: String = ""
    @State private var recipientHandle: String = ""
    @State private var selectedMethod: SettlementMethod = .venmo
    @State private var hasLaunchedPaymentApp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(
        group: SplitGroup,
        members: [SplitGroupMember],
        onSettled: @escaping () -> Void
    ) {
        self.group = group
        self.members = members
        self.onSettled = onSettled
        let recipient = members.first?.userId ?? UUID()
        self._selectedRecipientId = State(initialValue: recipient)
    }

    private var currentUserId: UUID {
        environment.sessionStore.currentUser?.id ?? UUID()
    }

    private var amountDecimal: Decimal {
        Decimal(string: amountString) ?? 0
    }

    private var recipientName: String {
        members.first { $0.userId == selectedRecipientId }?.profile?.displayName ?? "Member"
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                    // Recipient Selector
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        Text("SETTLE WITH")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)

                        Picker("Recipient", selection: $selectedRecipientId) {
                            ForEach(members.filter { $0.userId != currentUserId }) { member in
                                Text(member.profile?.displayName ?? "Member").tag(member.userId)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(SplitSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SplitColors.paperDim)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.ink, lineWidth: 1)
                        )
                    }

                    // Amount Hero
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        Text("AMOUNT")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)

                        HStack(spacing: SplitSpacing.xxs) {
                            Text("$")
                                .font(SplitTypography.amountLarge)
                                .foregroundColor(SplitColors.ink)

                            TextField("0.00", text: $amountString)
                                .font(SplitTypography.amountLarge)
                                .foregroundColor(SplitColors.ink)
                                .splitMonospacedDigits()
                                #if canImport(UIKit)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                        .padding(SplitSpacing.md)
                        .background(SplitColors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                        )
                    }

                    // Payment Rail Selector
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        Text("PAYMENT METHOD")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)

                        Picker("Method", selection: $selectedMethod) {
                            ForEach(SettlementMethod.allCases, id: \.self) { method in
                                Text(method.description).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // External Handle Input (if external app selected)
                    if selectedMethod == .venmo || selectedMethod == .cashApp || selectedMethod == .paypal {
                        VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                            Text("\(selectedMethod.description.uppercased()) USERNAME / HANDLE")
                                .font(SplitTypography.badge)
                                .foregroundColor(SplitColors.inkSoft)

                            TextField(handlePlaceholder, text: $recipientHandle)
                                .font(SplitTypography.body)
                                .padding(SplitSpacing.md)
                                .background(SplitColors.paper)
                                .overlay(
                                    RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                        .stroke(SplitColors.ink, lineWidth: 1.5)
                                )

                            // Launch External App Button
                            SplitButton("Open \(selectedMethod.description) ↗", icon: "arrow.up.forward.app", variant: .secondary) {
                                PaymentRailLauncher.openPaymentRail(
                                    method: selectedMethod,
                                    recipientHandle: recipientHandle,
                                    amount: amountDecimal,
                                    note: "Click Split — \(group.name)"
                                )
                                hasLaunchedPaymentApp = true
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.red)
                    }

                    // Confirm & Record Settlement Button
                    VStack(spacing: SplitSpacing.xs) {
                        SplitButton("Record Settlement", icon: "checkmark.circle", variant: .primary, isLoading: isLoading) {
                            recordSettlement()
                        }
                        .disabled(amountDecimal <= 0)

                        Text("Records the payment in Click Split to update all group balances.")
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(SplitSpacing.xl)
            }
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Settle Up")
            .splitInlineTitleDisplayMode()
            .splitKeyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(SplitColors.ink)
                }
            }
        }
    }

    private var handlePlaceholder: String {
        switch selectedMethod {
        case .venmo: return "@username"
        case .cashApp: return "$cashtag"
        case .paypal: return "paypal.me username"
        default: return ""
        }
    }

    private func recordSettlement() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await environment.settlementRepository.recordSettlement(
                    groupId: group.id,
                    fromUser: currentUserId,
                    toUser: selectedRecipientId,
                    amount: amountDecimal,
                    method: selectedMethod
                )
                isLoading = false
                SplitHaptics.notify(.success)
                onSettled()
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }
}
