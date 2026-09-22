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
    @State private var scannedItems: [ExpenseItemDraft] = []
    @State private var hasScannedReceipt = false
    @State private var customPercentages: [UUID: Decimal] = [:]
    @State private var showReceiptScanner = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(
        group: SplitGroup,
        members: [SplitGroupMember],
        prefilledItems: [ExpenseItemDraft]? = nil,
        prefilledTotal: Decimal? = nil,
        prefilledDescription: String? = nil,
        onExpenseCreated: @escaping () -> Void
    ) {
        self.group = group
        self.members = members
        self.onExpenseCreated = onExpenseCreated
        let defaultPayer = members.first?.userId ?? UUID()
        self._selectedPayerId = State(initialValue: defaultPayer)

        if prefilledItems != nil {
            self._hasScannedReceipt = State(initialValue: true)
        }

        if let items = prefilledItems, !items.isEmpty {
            self._scannedItems = State(initialValue: items)
            self._splitMethod = State(initialValue: .byItem)
            let total = prefilledTotal ?? items.reduce(Decimal.zero) { $0 + $1.price }
            self._amountString = State(initialValue: "\(total)")
            self._descriptionText = State(initialValue: prefilledDescription ?? "Scanned Receipt")
        } else {
            if let total = prefilledTotal, total > 0 {
                self._amountString = State(initialValue: "\(total)")
            }
            if let desc = prefilledDescription, !desc.isEmpty {
                self._descriptionText = State(initialValue: desc)
            }
        }
    }

    private var totalDecimal: Decimal {
        Decimal(string: amountString) ?? 0
    }

    private var customPercentageSum: Decimal {
        customPercentages.values.reduce(Decimal.zero, +)
    }

    private var isCustomPercentageValid: Bool {
        abs(customPercentageSum - 100) <= Decimal(string: "0.01")!
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

                    // Signature [ Scan Receipt ] action button
                    SplitButton("Scan Receipt", icon: "doc.viewfinder", variant: .secondary) {
                        SplitHaptics.impact(.medium)
                        showReceiptScanner = true
                    }

                    // Scanned items badge banner if items are attached
                    if !scannedItems.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(SplitColors.green)

                            Text("\(scannedItems.count) receipt items attached")
                                .font(SplitTypography.buttonSmall)
                                .foregroundColor(SplitColors.ink)

                            Spacer()

                            Button("Edit") {
                                showReceiptScanner = true
                            }
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.green)
                            .fontWeight(.bold)
                        }
                        .padding(SplitSpacing.md)
                        .background(SplitColors.greenDim)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.green, lineWidth: 1.5)
                        )
                    }

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
                        .onChange(of: splitMethod) { _, newMethod in
                            if newMethod == .customPercent && customPercentages.isEmpty {
                                initializeCustomPercentages()
                            }
                        }
                    }

                    // Custom % Allocation Editor (Section 12)
                    if splitMethod == .customPercent {
                        customPercentEditor
                    } else if splitMethod == .byItem && !scannedItems.isEmpty {
                        byItemBreakdownSection
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
                    .disabled(
                        descriptionText.trimmingCharacters(in: .whitespaces).isEmpty ||
                        totalDecimal <= 0 ||
                        (splitMethod == .customPercent && !isCustomPercentageValid)
                    )
                }
                .padding(SplitSpacing.lg)
            }
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Add Expense")
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
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScannerSheet(
                    members: members,
                    onItemsReady: { items, total, merchant in
                        hasScannedReceipt = true
                        scannedItems = items
                        amountString = "\(total)"
                        splitMethod = .byItem
                        if let merchant, !merchant.isEmpty {
                            descriptionText = merchant
                        } else if descriptionText.isEmpty {
                            descriptionText = "Scanned Receipt"
                        }
                    }
                )
            }
        }
    }

    // ────────────────── Custom % Editor View ──────────────────

    private var customPercentEditor: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.md) {
            HStack {
                Text("CUSTOM ALLOCATION")
                    .font(SplitTypography.badge)
                    .foregroundColor(SplitColors.inkSoft)
                    .tracking(1)

                Spacer()

                // Sum indicator badge
                let sumInt = (customPercentageSum as NSDecimalNumber).intValue
                HStack(spacing: SplitSpacing.xxs) {
                    Text("Total: \(sumInt)%")
                        .font(SplitTypography.buttonSmall)
                        .foregroundColor(isCustomPercentageValid ? SplitColors.green : SplitColors.red)

                    if !isCustomPercentageValid {
                        let remaining = 100 - customPercentageSum
                        let remInt = (remaining as NSDecimalNumber).intValue
                        Text("(\(remInt > 0 ? "+\(remInt)%" : "\(remInt)%"))")
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.red)
                    }
                }
            }

            VStack(spacing: SplitSpacing.sm) {
                ForEach(members) { member in
                    let uid = member.userId
                    let currentPercent = customPercentages[uid] ?? 0
                    let memberShareAmount = (totalDecimal * currentPercent) / 100

                    HStack(spacing: SplitSpacing.md) {
                        Text(member.profile?.displayName ?? "Member")
                            .font(SplitTypography.body)
                            .foregroundColor(SplitColors.ink)

                        Spacer()

                        // Calculated dollar share
                        SplitAmount(memberShareAmount, style: .small, color: SplitColors.inkSoft)

                        // Editable percentage field
                        HStack(spacing: 2) {
                            TextField("0", value: Binding(
                                get: { currentPercent },
                                set: { customPercentages[uid] = $0 }
                            ), format: .number)
                            .font(SplitTypography.button)
                            .frame(width: 44)
                            .multilineTextAlignment(.trailing)
                            .splitMonospacedDigits()
                            #if canImport(UIKit)
                            .keyboardType(.numberPad)
                            #endif

                            Text("%")
                                .font(SplitTypography.buttonSmall)
                                .foregroundColor(SplitColors.inkSoft)
                        }
                        .padding(.horizontal, SplitSpacing.sm)
                        .padding(.vertical, SplitSpacing.xxs)
                        .background(SplitColors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(isCustomPercentageValid ? SplitColors.ink : SplitColors.red, lineWidth: 1.5)
                        )
                    }
                    .padding(SplitSpacing.sm)
                    .background(SplitColors.paperDim)
                    .cornerRadius(SplitSpacing.cornerRadius)
                }
            }

            // Quick action to re-equalize percentages
            Button(action: {
                SplitHaptics.impact(.light)
                initializeCustomPercentages()
            }) {
                HStack {
                    Image(systemName: "equal.circle")
                    Text("Split Percentages Evenly")
                }
                .font(SplitTypography.caption)
                .foregroundColor(SplitColors.inkSoft)
            }
            .buttonStyle(.plain)
        }
        .padding(SplitSpacing.md)
        .splitCardStyle(
            surfaceColor: SplitColors.paperDim,
            borderColor: isCustomPercentageValid ? SplitColors.ink : SplitColors.red,
            borderWidth: 1.5,
            shadowOffset: SplitSpacing.shadowOffsetSmall
        )
    }

    private var byItemBreakdownSection: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.sm) {
            HStack {
                Text("ITEMIZED ALLOCATION (\(scannedItems.count))")
                    .font(SplitTypography.badge)
                    .foregroundColor(SplitColors.inkSoft)
                    .tracking(1)

                Spacer()

                Button("Edit Receipt") {
                    showReceiptScanner = true
                }
                .font(SplitTypography.caption)
                .fontWeight(.bold)
                .foregroundColor(SplitColors.green)
            }

            VStack(spacing: SplitSpacing.xs) {
                ForEach(scannedItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(SplitTypography.buttonSmall)
                                .foregroundColor(SplitColors.ink)
                            Text(assigneeName(for: item.assignedTo))
                                .font(SplitTypography.caption)
                                .foregroundColor(item.assignedTo != nil ? SplitColors.green : SplitColors.inkSoft)
                        }

                        Spacer()

                        Text("$\(item.price.formatted(.number.precision(.fractionLength(2))))")
                            .font(SplitTypography.buttonSmall)
                            .foregroundColor(SplitColors.ink)
                            .splitMonospacedDigits()
                    }
                    .padding(.vertical, 2)
                    if item.id != scannedItems.last?.id {
                        Divider()
                            .background(SplitColors.ink.opacity(0.08))
                    }
                }
            }
            .padding(SplitSpacing.md)
            .splitCardStyle(surfaceColor: SplitColors.paperDim)
        }
    }

    private func assigneeName(for userId: UUID?) -> String {
        guard let userId else { return "Everyone (Split evenly)" }
        return members.first { $0.userId == userId }?.profile?.displayName ?? "Member"
    }

    private func initializeCustomPercentages() {
        guard !members.isEmpty else { return }
        let count = members.count
        let base = 100 / count
        let rem = 100 % count

        var map: [UUID: Decimal] = [:]
        for (idx, member) in members.enumerated() {
            map[member.userId] = Decimal(base + (idx < rem ? 1 : 0))
        }
        self.customPercentages = map
    }

    private func saveExpense() {
        isLoading = true
        errorMessage = nil

        let drafts = customPercentages.map { userId, percent in
            let computed = (totalDecimal * percent) / 100
            return MemberShareDraft(userId: userId, percentage: percent, computedAmount: computed)
        }

        let draft = ExpenseDraft(
            description: descriptionText.trimmingCharacters(in: .whitespaces),
            total: totalDecimal,
            payerID: selectedPayerId,
            splitMethod: splitMethod,
            items: scannedItems,
            customShares: drafts,
            receipt: hasScannedReceipt ? ReceiptDraft(recognizedItems: scannedItems) : nil
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
