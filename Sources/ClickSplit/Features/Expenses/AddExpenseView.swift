import SwiftUI

/// Signature Add Expense workflow designed around one-handed iOS use.
public struct AddExpenseView: View {
    public var group: SplitGroup
    public var members: [SplitGroupMember]
    public var onExpenseCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var amountString: String = ""
    @State private var descriptionText: String = ""
    @State private var selectedPayerId: UUID
    @State private var splitMethod: SplitMethod = .even
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(
        group: SplitGroup,
        members: [SplitGroupMember],
        onExpenseCreated: @escaping () -> Void
    ) {
        self.group = group
        self.members = members
        self.onExpenseCreated = onExpenseCreated
        let defaultPayer = members.first?.userId ?? UUID()
        self._selectedPayerId = State(initialValue: defaultPayer)
    }

    private var totalDecimal: Decimal {
        Decimal(string: amountString) ?? 0
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                    // Amount Hero Input
                    VStack(alignment: .center, spacing: SplitSpacing.xs) {
                        Text("AMOUNT")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)
                            .tracking(1)

                        HStack(alignment: .firstTextBaseline, spacing: SplitSpacing.xxs) {
                            Text("$")
                                .font(SplitTypography.amountHero)
                                .foregroundColor(SplitColors.ink)

                            TextField("0.00", text: $amountString)
                                .font(SplitTypography.amountHero)
                                .foregroundColor(SplitColors.ink)
                                .splitMonospacedDigits()
                                #if canImport(UIKit)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(SplitSpacing.xl)
                    .splitCardStyle(surfaceColor: SplitColors.paperDim)

                    // Description Field
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        Text("DESCRIPTION")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)

                        TextField("What was this for? (e.g. Dinner, Groceries)", text: $descriptionText)
                            .font(SplitTypography.body)
                            .padding(SplitSpacing.md)
                            .background(SplitColors.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                    .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                            )
                    }

                    // Payer Picker
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        Text("PAID BY")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)

                        Picker("Paid by", selection: $selectedPayerId) {
                            ForEach(members) { member in
                                Text(member.profile?.displayName ?? "Member").tag(member.userId)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Split Method Segmented Control
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        Text("SPLIT METHOD")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)

                        SplitSegmentedControl(
                            options: SplitMethod.allCases,
                            selection: $splitMethod
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.red)
                    }

                    // Submit Button
                    SplitButton("Save expense", icon: "checkmark", variant: .primary, isLoading: isLoading) {
                        saveExpense()
                    }
                    .disabled(descriptionText.trimmingCharacters(in: .whitespaces).isEmpty || totalDecimal <= 0)
                }
                .padding(SplitSpacing.lg)
            }
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Add Expense")
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

    private func saveExpense() {
        isLoading = true
        errorMessage = nil

        let draft = ExpenseDraft(
            description: descriptionText.trimmingCharacters(in: .whitespaces),
            total: totalDecimal,
            payerID: selectedPayerId,
            splitMethod: splitMethod
        )

        Task {
            do {
                _ = try await environment.expenseRepository.createExpense(draft: draft, groupId: group.id)
                isLoading = false
                SplitHaptics.notify(.success)
                onExpenseCreated()
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }
}
