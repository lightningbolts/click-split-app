import SwiftUI

/// Detailed inspection view for an individual group expense.
/// Displays financial breakdown, payer, itemized receipt breakdown (if available),
/// member shares, and provides an option to delete the expense.
public struct ExpenseDetailView: View {
    public var expense: SplitExpense
    public var group: SplitGroup
    public var members: [SplitGroupMember]
    public var initialShares: [SplitExpenseShare]
    public var onExpenseDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var items: [SplitExpenseItem] = []
    @State private var shares: [SplitExpenseShare] = []
    @State private var isLoadingItems = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    public init(
        expense: SplitExpense,
        group: SplitGroup,
        members: [SplitGroupMember],
        initialShares: [SplitExpenseShare] = [],
        onExpenseDeleted: @escaping () -> Void
    ) {
        self.expense = expense
        self.group = group
        self.members = members
        self.initialShares = initialShares
        self.onExpenseDeleted = onExpenseDeleted
        self._shares = State(initialValue: initialShares)
    }

    private var currentUserId: UUID? {
        environment.sessionStore.currentUser?.id
    }

    private var payerMember: SplitGroupMember? {
        members.first { $0.userId == expense.paidBy }
    }

    private var payerName: String {
        payerMember?.profile?.displayName ?? "Group Member"
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                    headerSection
                    totalHeroCard

                    if !items.isEmpty {
                        receiptItemsSection
                    }

                    sharesBreakdownSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.red)
                    }

                    deleteExpenseButton
                }
                .padding(SplitSpacing.lg)
            }
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Expense Details")
            .splitInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(SplitColors.ink)
                }
            }
            .task {
                await loadExpenseDetails()
            }
            .confirmationDialog(
                "Delete Expense?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Expense", role: .destructive) {
                    deleteExpense()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(expense.description)\"? This will recalculate all group member balances.")
            }
        }
    }

    // ──────────────── Subviews ────────────────

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.xs) {
            HStack(spacing: SplitSpacing.xs) {
                Image(systemName: expense.source == .receiptScan ? "doc.text.viewfinder" : "creditcard")
                    .font(.system(size: 13, weight: .bold))

                Text(expense.source == .receiptScan ? "RECEIPT SCAN" : "MANUAL ENTRY")
                    .font(SplitTypography.badge)
                    .tracking(1)
            }
            .foregroundColor(SplitColors.inkSoft)
            .padding(.horizontal, SplitSpacing.sm)
            .padding(.vertical, 4)
            .background(SplitColors.paperDim)
            .overlay(
                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                    .stroke(SplitColors.ink, lineWidth: 1)
            )

            Text(expense.description)
                .font(SplitTypography.amountHero)
                .foregroundColor(SplitColors.ink)
                .lineLimit(2)

            Text(expense.createdAt, style: .date)
                .font(SplitTypography.caption)
                .foregroundColor(SplitColors.inkSoft)
        }
    }

    private var totalHeroCard: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.sm) {
            Text("TOTAL AMOUNT")
                .font(SplitTypography.badge)
                .foregroundColor(SplitColors.inkSoft)
                .tracking(1)

            SplitAmount(expense.totalAmount, style: .large)

            Divider()
                .background(SplitColors.grey.opacity(0.4))

            HStack {
                Image(systemName: "person.fill.checkmark")
                    .foregroundColor(SplitColors.green)
                Text("Paid by")
                    .font(SplitTypography.body)
                    .foregroundColor(SplitColors.inkSoft)

                Text(payerName)
                    .font(SplitTypography.button)
                    .foregroundColor(SplitColors.ink)

                if expense.paidBy == currentUserId {
                    Text("(You)")
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.green)
                        .fontWeight(.bold)
                }
            }
        }
        .padding(SplitSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .splitCardStyle(surfaceColor: SplitColors.paperDim)
    }

    private var receiptItemsSection: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.sm) {
            Text("RECEIPT ITEMS (\(items.count))")
                .font(SplitTypography.sectionHeader)
                .foregroundColor(SplitColors.ink)
                .tracking(1)

            VStack(spacing: SplitSpacing.xs) {
                ForEach(items) { item in
                    ReceiptItemRow(
                        item: item,
                        assigneeName: assigneeName(for: item),
                        isLast: item.id == items.last?.id
                    )
                }
            }
            .padding(SplitSpacing.md)
            .splitCardStyle(
                surfaceColor: SplitColors.paperDim,
                borderColor: SplitColors.ink,
                shadowOffset: SplitSpacing.shadowOffsetSmall
            )
        }
    }

    private func assigneeName(for item: SplitExpenseItem) -> String? {
        guard let assigneeId = item.assignedTo else { return nil }
        return members.first { $0.userId == assigneeId }?.profile?.displayName
    }

    private var sharesBreakdownSection: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.sm) {
            HStack {
                Text("SPLIT SHARES")
                    .font(SplitTypography.sectionHeader)
                    .foregroundColor(SplitColors.ink)
                    .tracking(1)

                Spacer()

                Text(expense.splitMethod.title.uppercased())
                    .font(SplitTypography.badge)
                    .foregroundColor(SplitColors.inkSoft)
                    .padding(.horizontal, SplitSpacing.xs)
                    .padding(.vertical, 2)
                    .background(SplitColors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(SplitColors.ink, lineWidth: 1)
                    )
            }

            VStack(spacing: SplitSpacing.xs) {
                if shares.isEmpty {
                    Text("Calculating shares...")
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.inkSoft)
                        .padding(SplitSpacing.sm)
                } else {
                    ForEach(shares, id: \.userId) { share in
                        let member = members.first { $0.userId == share.userId }
                        let isPayer = share.userId == expense.paidBy
                        let isSelf = share.userId == currentUserId
                        let isLast = share.userId == shares.last?.userId

                        ShareBreakdownRow(
                            share: share,
                            memberName: member?.profile?.displayName ?? "Member",
                            isPayer: isPayer,
                            isSelf: isSelf,
                            isLast: isLast
                        )
                    }
                }
            }
            .padding(SplitSpacing.md)
            .splitCardStyle(
                surfaceColor: SplitColors.paperDim,
                borderColor: SplitColors.ink,
                shadowOffset: SplitSpacing.shadowOffsetSmall
            )
        }
    }

    private var deleteExpenseButton: some View {
        VStack(spacing: SplitSpacing.xs) {
            Button {
                SplitHaptics.impact(.medium)
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: SplitSpacing.xs) {
                    Image(systemName: "trash")
                    Text("Delete Expense")
                }
                .font(SplitTypography.button)
                .foregroundColor(SplitColors.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplitSpacing.md)
                .background(SplitColors.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                        .stroke(SplitColors.red, lineWidth: SplitSpacing.borderWidth)
                )
                .splitShadow(offset: SplitSpacing.shadowOffsetSmall)
            }
            .disabled(isDeleting)

            Text("Deleting will remove this expense and recalculate group balances.")
                .font(SplitTypography.caption)
                .foregroundColor(SplitColors.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, SplitSpacing.md)
    }

    // ──────────────── Actions ────────────────

    private func loadExpenseDetails() async {
        guard !isLoadingItems else { return }
        isLoadingItems = true

        do {
            async let loadedItems = environment.expenseRepository.fetchExpenseItems(expenseId: expense.id)
            async let loadedShares = environment.expenseRepository.fetchExpenseShares(expenseId: expense.id)

            let (fetchedItems, fetchedShares) = try await (loadedItems, loadedShares)
            self.items = fetchedItems
            if !fetchedShares.isEmpty {
                self.shares = fetchedShares
            }
        } catch {
            // Retain initial shares if remote fetch fails
        }

        isLoadingItems = false
    }

    private func deleteExpense() {
        isDeleting = true
        errorMessage = nil

        Task {
            do {
                try await environment.expenseRepository.deleteExpense(expenseId: expense.id)
                SplitHaptics.notify(.success)
                onExpenseDeleted()
                dismiss()
            } catch {
                isDeleting = false
                errorMessage = "Failed to delete expense: \(error.localizedDescription)"
                SplitHaptics.notify(.error)
            }
        }
    }
}

// ──────────────── Helper Row Views ────────────────

private struct ReceiptItemRow: View {
    let item: SplitExpenseItem
    let assigneeName: String?
    let isLast: Bool

    var body: some View {
        VStack(spacing: SplitSpacing.xxs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(SplitTypography.body)
                        .foregroundColor(SplitColors.ink)

                    if let assigneeName {
                        Text("Assigned to \(assigneeName)")
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.inkSoft)
                    } else {
                        Text("Split evenly")
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.inkSoft)
                    }
                }

                Spacer()

                SplitAmount(item.price, style: .small)
            }
            .padding(.vertical, SplitSpacing.xxs)

            if !isLast {
                Divider()
                    .background(SplitColors.grey.opacity(0.3))
            }
        }
    }
}

private struct ShareBreakdownRow: View {
    let share: SplitExpenseShare
    let memberName: String
    let isPayer: Bool
    let isSelf: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: SplitSpacing.xxs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(memberName)
                            .font(SplitTypography.buttonSmall)
                            .foregroundColor(SplitColors.ink)

                        if isSelf {
                            Text("(You)")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.inkSoft)
                        }
                    }

                    if isPayer {
                        Text("Payer")
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.green)
                            .fontWeight(.bold)
                    }
                }

                Spacer()

                SplitAmount(share.shareAmount, style: .small)
            }
            .padding(.vertical, SplitSpacing.xxs)

            if !isLast {
                Divider()
                    .background(SplitColors.grey.opacity(0.3))
            }
        }
    }
}
