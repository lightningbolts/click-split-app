import SwiftUI

/// Itemized receipt review and member assignment screen.
public struct ReceiptReviewView: View {
    public var members: [SplitGroupMember]
    public var initialItems: [ExpenseItemDraft]
    public var onApply: ([ExpenseItemDraft], Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [ExpenseItemDraft]
    @State private var selectedItemForAssignment: ExpenseItemDraft?
    @State private var showAssigneeSheet = false

    public init(
        members: [SplitGroupMember],
        initialItems: [ExpenseItemDraft],
        onApply: @escaping ([ExpenseItemDraft], Decimal) -> Void
    ) {
        self.members = members
        self.initialItems = initialItems
        self.onApply = onApply
        self._items = State(initialValue: initialItems)
    }

    private var totalCalculated: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.price }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Total Card
                HStack {
                    VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                        Text("TOTAL RECOGNIZED")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)

                        SplitAmount(totalCalculated, style: .large, color: SplitColors.ink)
                    }

                    Spacer()

                    Text("\(items.count) items")
                        .font(SplitTypography.buttonSmall)
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
                    }
                    .padding(SplitSpacing.lg)
                }

                // Footer Action
                VStack {
                    SplitButton("Apply Items to Expense", icon: "checkmark", variant: .primary) {
                        SplitHaptics.notify(.success)
                        onApply(items, totalCalculated)
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
            .navigationTitle("Review Receipt")
            .splitInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(SplitColors.ink)
                }
            }
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
