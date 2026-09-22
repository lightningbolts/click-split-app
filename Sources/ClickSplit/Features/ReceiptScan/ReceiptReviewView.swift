import SwiftUI

/// Itemized receipt review, tax/tip calculator, and member assignment screen.
public struct ReceiptReviewView: View {
    public var members: [SplitGroupMember]
    public var initialItems: [ExpenseItemDraft]
    public var initialTax: Decimal
    public var initialTip: Decimal
    public var onApply: ([ExpenseItemDraft], Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [ExpenseItemDraft]
    @State private var tax: Decimal
    @State private var selectedTipPct: Int = 0
    @State private var customTipAmount: Decimal = 0
    @State private var isCustomTip: Bool = false
    @State private var selectedItemForAssignment: ExpenseItemDraft?
    @State private var showAssigneeSheet = false

    public init(
        members: [SplitGroupMember],
        initialItems: [ExpenseItemDraft],
        initialTax: Decimal = 0,
        initialTip: Decimal = 0,
        onApply: @escaping ([ExpenseItemDraft], Decimal) -> Void
    ) {
        self.members = members
        self.initialItems = initialItems
        self.initialTax = initialTax
        self.initialTip = initialTip
        self.onApply = onApply
        self._items = State(initialValue: initialItems)
        self._tax = State(initialValue: initialTax)

        if initialTip > 0 {
            self._isCustomTip = State(initialValue: true)
            self._customTipAmount = State(initialValue: initialTip)
            self._selectedTipPct = State(initialValue: 0)
        } else {
            self._isCustomTip = State(initialValue: false)
            self._customTipAmount = State(initialValue: 0)
            self._selectedTipPct = State(initialValue: 0)
        }
    }

    private var itemsSubtotal: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.price }
    }

    private var tipAmount: Decimal {
        if isCustomTip {
            return max(0, customTipAmount)
        } else if selectedTipPct > 0 {
            return ((itemsSubtotal * Decimal(selectedTipPct)) / 100)
        }
        return 0
    }

    private var totalCalculated: Decimal {
        itemsSubtotal + max(0, tax) + tipAmount
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Total Card
            HStack {
                VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                    Text("TOTAL (WITH TAX & TIP)")
                        .font(SplitTypography.badge)
                        .foregroundColor(SplitColors.inkSoft)
                        .tracking(1)

                    SplitAmount(totalCalculated, style: .large, color: SplitColors.ink)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(items.count) items")
                        .font(SplitTypography.buttonSmall)
                        .foregroundColor(SplitColors.ink)
                    if tax > 0 || tipAmount > 0 {
                        Text("Sub: $\(itemsSubtotal.formatted(.number.precision(.fractionLength(2))))")
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.inkSoft)
                    }
                }
                .padding(.horizontal, SplitSpacing.md)
                .padding(.vertical, SplitSpacing.xs)
                .background(SplitColors.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                        .stroke(SplitColors.ink, lineWidth: 1.5)
                )
            }
            .padding(SplitSpacing.lg)
            .background(SplitColors.paperDim)
            .overlay(
                Rectangle()
                    .frame(height: SplitSpacing.borderWidth)
                    .foregroundColor(SplitColors.ink),
                alignment: .bottom
            )

            // Item List
            ScrollView {
                VStack(spacing: SplitSpacing.md) {
                    ForEach($items) { $item in
                        HStack(spacing: SplitSpacing.md) {
                            VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                                TextField("Item name", text: $item.label)
                                    .font(SplitTypography.button)
                                    .foregroundColor(SplitColors.ink)

                                // Assignee Selector Button
                                Button(action: {
                                    SplitHaptics.selection()
                                    selectedItemForAssignment = item
                                    showAssigneeSheet = true
                                }) {
                                    HStack(spacing: SplitSpacing.xxs) {
                                        Text("Assigned to:")
                                            .font(SplitTypography.caption)
                                            .foregroundColor(SplitColors.inkSoft)

                                        Text(assigneeName(for: item.assignedTo))
                                            .font(SplitTypography.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(item.assignedTo != nil ? SplitColors.green : SplitColors.ink)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(SplitColors.grey)
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            // Price Field
                            HStack(spacing: SplitSpacing.xxs) {
                                Text("$")
                                    .font(SplitTypography.button)
                                    .foregroundColor(SplitColors.ink)

                                TextField("0.00", value: $item.price, format: .number)
                                    .font(SplitTypography.button)
                                    .foregroundColor(SplitColors.ink)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                    .splitMonospacedDigits()
                                    #if canImport(UIKit)
                                    .keyboardType(.decimalPad)
                                    #endif
                            }
                        }
                        .padding(SplitSpacing.md)
                        .splitCardStyle(
                            surfaceColor: SplitColors.paperDim,
                            borderColor: SplitColors.ink,
                            borderWidth: 1.5,
                            shadowOffset: SplitSpacing.shadowOffsetSmall
                        )
                    }

                    // Add item button
                    Button(action: {
                        SplitHaptics.impact(.light)
                        items.append(ExpenseItemDraft(label: "New item", price: 0))
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Line Item")
                        }
                        .font(SplitTypography.buttonSmall)
                        .foregroundColor(SplitColors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(SplitSpacing.md)
                        .background(SplitColors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.ink, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        )
                    }

                    // Tax & Tip Calculation Card
                    VStack(alignment: .leading, spacing: SplitSpacing.md) {
                        Text("TAX & GRATUITY")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)
                            .tracking(1)

                        // Tax Input Row
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sales Tax")
                                    .font(SplitTypography.button)
                                    .foregroundColor(SplitColors.ink)
                                Text("Split evenly among group")
                                    .font(SplitTypography.caption)
                                    .foregroundColor(SplitColors.inkSoft)
                            }

                            Spacer()

                            HStack(spacing: SplitSpacing.xxs) {
                                Text("$")
                                    .font(SplitTypography.button)
                                    .foregroundColor(SplitColors.ink)

                                TextField("0.00", value: $tax, format: .number)
                                    .font(SplitTypography.button)
                                    .foregroundColor(SplitColors.ink)
                                    .frame(width: 70)
                                    .multilineTextAlignment(.trailing)
                                    .splitMonospacedDigits()
                                    #if canImport(UIKit)
                                    .keyboardType(.decimalPad)
                                    #endif
                            }
                            .padding(.horizontal, SplitSpacing.sm)
                            .padding(.vertical, SplitSpacing.xs)
                            .background(SplitColors.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                    .stroke(SplitColors.ink, lineWidth: 1)
                            )
                        }

                        Divider()
                            .background(SplitColors.ink.opacity(0.15))

                        // Tip Presets & Custom
                        VStack(alignment: .leading, spacing: SplitSpacing.xs) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tip / Gratuity")
                                        .font(SplitTypography.button)
                                        .foregroundColor(SplitColors.ink)
                                    Text("Split evenly among group")
                                        .font(SplitTypography.caption)
                                        .foregroundColor(SplitColors.inkSoft)
                                }

                                Spacer()

                                if tipAmount > 0 {
                                    Text("+$\(tipAmount.formatted(.number.precision(.fractionLength(2))))")
                                        .font(SplitTypography.buttonSmall)
                                        .foregroundColor(SplitColors.green)
                                }
                            }

                            HStack(spacing: SplitSpacing.xs) {
                                ForEach([0, 15, 18, 20], id: \.self) { pct in
                                    Button {
                                        SplitHaptics.selection()
                                        isCustomTip = false
                                        selectedTipPct = pct
                                    } label: {
                                        Text("\(pct)%")
                                            .font(SplitTypography.buttonSmall)
                                            .foregroundColor((!isCustomTip && selectedTipPct == pct) ? SplitColors.white : SplitColors.ink)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, SplitSpacing.xs)
                                            .background((!isCustomTip && selectedTipPct == pct) ? SplitColors.ink : SplitColors.paper)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                                    .stroke(SplitColors.ink, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    SplitHaptics.selection()
                                    isCustomTip = true
                                } label: {
                                    Text("Custom")
                                        .font(SplitTypography.buttonSmall)
                                        .foregroundColor(isCustomTip ? SplitColors.white : SplitColors.ink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, SplitSpacing.xs)
                                        .background(isCustomTip ? SplitColors.ink : SplitColors.paper)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                                .stroke(SplitColors.ink, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            if isCustomTip {
                                HStack {
                                    Text("Custom Tip ($):")
                                        .font(SplitTypography.caption)
                                        .foregroundColor(SplitColors.inkSoft)

                                    Spacer()

                                    HStack(spacing: SplitSpacing.xxs) {
                                        Text("$")
                                            .font(SplitTypography.button)
                                            .foregroundColor(SplitColors.ink)

                                        TextField("0.00", value: $customTipAmount, format: .number)
                                            .font(SplitTypography.button)
                                            .foregroundColor(SplitColors.ink)
                                            .frame(width: 70)
                                            .multilineTextAlignment(.trailing)
                                            .splitMonospacedDigits()
                                            #if canImport(UIKit)
                                            .keyboardType(.decimalPad)
                                            #endif
                                    }
                                    .padding(.horizontal, SplitSpacing.sm)
                                    .padding(.vertical, SplitSpacing.xs)
                                    .background(SplitColors.paper)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                            .stroke(SplitColors.ink, lineWidth: 1)
                                    )
                                }
                                .padding(.top, SplitSpacing.xxs)
                            }
                        }
                    }
                    .padding(SplitSpacing.md)
                    .splitCardStyle(
                        surfaceColor: SplitColors.paperDim,
                        borderColor: SplitColors.ink,
                        borderWidth: 1.5,
                        shadowOffset: SplitSpacing.shadowOffsetSmall
                    )
                }
                .padding(SplitSpacing.lg)
            }

            // Footer Action
            VStack {
                SplitButton("Apply Items to Expense", icon: "checkmark", variant: .primary) {
                    SplitHaptics.notify(.success)
                    var finalItems = items
                    if tax > 0 {
                        finalItems.append(ExpenseItemDraft(label: "Tax", price: tax, assignedTo: nil))
                    }
                    if tipAmount > 0 {
                        let label = isCustomTip ? "Tip" : "Tip (\(selectedTipPct)%)"
                        finalItems.append(ExpenseItemDraft(label: label, price: tipAmount, assignedTo: nil))
                    }
                    onApply(finalItems, totalCalculated)
                    dismiss()
                }
            }
            .padding(SplitSpacing.lg)
            .background(SplitColors.paperDim)
            .overlay(
                Rectangle()
                    .frame(height: SplitSpacing.borderWidth)
                    .foregroundColor(SplitColors.ink),
                alignment: .top
            )
        }
        .background(SplitColors.paper.ignoresSafeArea())
        .sheet(isPresented: $showAssigneeSheet) {
            if let targetItem = selectedItemForAssignment {
                AssigneePickerSheet(
                    item: targetItem,
                    members: members,
                    onSelect: { newAssignedId in
                        if let index = items.firstIndex(where: { $0.id == targetItem.id }) {
                            items[index].assignedTo = newAssignedId
                        }
                        showAssigneeSheet = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    private func assigneeName(for userId: UUID?) -> String {
        guard let userId else { return "Everyone (Split evenly)" }
        return members.first { $0.userId == userId }?.profile?.displayName ?? "Member"
    }
}

/// Bottom sheet for selecting member assignee.
public struct AssigneePickerSheet: View {
    public var item: ExpenseItemDraft
    public var members: [SplitGroupMember]
    public var onSelect: (UUID?) -> Void

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplitSpacing.md) {
                Text("Assign \"\(item.label)\"")
                    .font(SplitTypography.button)
                    .foregroundColor(SplitColors.ink)
                    .padding(.top, SplitSpacing.md)

                // Option: Everyone (Even split)
                Button(action: {
                    SplitHaptics.selection()
                    onSelect(nil)
                }) {
                    HStack {
                        Text("👥 Everyone (Split evenly)")
                            .font(SplitTypography.body)
                            .foregroundColor(SplitColors.ink)
                        Spacer()
                        if item.assignedTo == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(SplitColors.green)
                        }
                    }
                    .padding(SplitSpacing.md)
                    .background(item.assignedTo == nil ? SplitColors.greenDim : SplitColors.paperDim)
                    .overlay(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .stroke(SplitColors.ink, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Individual Members
                ForEach(members) { member in
                    let isSelected = item.assignedTo == member.userId
                    Button(action: {
                        SplitHaptics.selection()
                        onSelect(member.userId)
                    }) {
                        HStack {
                            Text("○ \(member.profile?.displayName ?? "Member")")
                                .font(SplitTypography.body)
                                .foregroundColor(SplitColors.ink)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(SplitColors.green)
                            }
                        }
                        .padding(SplitSpacing.md)
                        .background(isSelected ? SplitColors.greenDim : SplitColors.paperDim)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.ink, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(SplitSpacing.lg)
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Assign Item")
            .splitInlineTitleDisplayMode()
        }
    }
}
