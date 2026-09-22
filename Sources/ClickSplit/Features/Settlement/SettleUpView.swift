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
    @State private var selectedMethod: SettlementMethod = .venmo
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

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                // Recipient selector
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

                // Amount
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

                // Payment Rail
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

                if let errorMessage {
                    Text(errorMessage)
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.red)
                }

                Spacer()

                // Confirm and Record Settlement
                SplitButton("Record Settlement", icon: "checkmark.circle", variant: .primary, isLoading: isLoading) {
                    recordSettlement()
                }
                .disabled(amountDecimal <= 0)
            }
            .padding(SplitSpacing.xl)
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Settle Up")
            .splitInlineTitleDisplayMode()
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
