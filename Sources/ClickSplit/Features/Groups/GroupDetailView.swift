import SwiftUI

/// Main group detail view displaying members, group balances, actions, and expenses.
public struct GroupDetailView: View {
    public var group: SplitGroup
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: GroupDetailViewModel
    @State private var showAddExpenseSheet = false
    @State private var showSettleUpSheet = false

    public init(group: SplitGroup) {
        self.group = group
        self._viewModel = State(initialValue: GroupDetailViewModel(group: group))
    }

    private var currentUserId: UUID? {
        environment.sessionStore.currentUser?.id
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                // Group Header
                HStack(spacing: SplitSpacing.md) {
                    Text(group.icon ?? "👥")
                        .font(.system(size: 32))
                        .padding(SplitSpacing.sm)
                        .background(SplitColors.paperDim)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                        )

                    VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                        Text(group.name)
                            .font(SplitTypography.title)
                            .foregroundColor(SplitColors.ink)

                        Text(viewModel.members.map { $0.profile?.displayName ?? "Member" }.joined(separator: ", "))
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.inkSoft)
                            .lineLimit(1)
                    }
                }

                // Group Balance Hero Card
                VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                    Text("YOUR GROUP BALANCE")
                        .font(SplitTypography.badge)
                        .foregroundColor(SplitColors.inkSoft)
                        .tracking(1)

                    HStack(spacing: SplitSpacing.xs) {
                        if viewModel.userBalance > 0 {
                            Text("You're owed")
                                .font(SplitTypography.amountLarge)
                                .foregroundColor(SplitColors.green)
                            SplitAmount(viewModel.userBalance, style: .large, color: SplitColors.green)
                        } else if viewModel.userBalance < 0 {
                            Text("You owe")
                                .font(SplitTypography.amountLarge)
                                .foregroundColor(SplitColors.red)
                            SplitAmount(abs(viewModel.userBalance), style: .large, color: SplitColors.red)
                        } else {
                            Text("You're all settled up")
                                .font(SplitTypography.amountLarge)
                                .foregroundColor(SplitColors.inkSoft)
                        }
                    }
                }
                .padding(SplitSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .splitCardStyle(
                    surfaceColor: SplitColors.paperDim,
                    borderColor: SplitColors.ink,
                    shadowOffset: SplitSpacing.shadowOffsetSmall
                )

                // Action Row: Add Expense & Settle Up
                HStack(spacing: SplitSpacing.md) {
                    SplitButton("Add expense", icon: "plus", variant: .primary) {
                        showAddExpenseSheet = true
                    }

                    SplitButton("Settle up", icon: "arrow.2.squarepath", variant: .secondary) {
                        showSettleUpSheet = true
                    }
                }

                // Members Section
                VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                    Text("MEMBERS")
                        .font(SplitTypography.sectionHeader)
                        .foregroundColor(SplitColors.ink)
                        .tracking(1)

                    VStack(spacing: SplitSpacing.xs) {
                        ForEach(viewModel.members) { member in
                            MemberBalanceRowView(
                                member: member,
                                balance: viewModel.memberBalances[member.userId] ?? 0,
                                isCurrentUser: member.userId == currentUserId
                            )

                            if member.id != viewModel.members.last?.id {
                                Divider()
                                    .background(SplitColors.grey.opacity(0.3))
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

                // Expenses Section
                VStack(alignment: .leading, spacing: SplitSpacing.md) {
                    Text("EXPENSES")
                        .font(SplitTypography.sectionHeader)
                        .foregroundColor(SplitColors.ink)
                        .tracking(1)

                    if viewModel.expenses.isEmpty {
                        Text("No expenses recorded yet.")
                            .font(SplitTypography.body)
                            .foregroundColor(SplitColors.inkSoft)
                            .padding(.vertical, SplitSpacing.lg)
                    } else {
                        VStack(spacing: SplitSpacing.sm) {
                            ForEach(viewModel.expenses) { expense in
                                ExpenseRowView(
                                    expense: expense,
                                    currentUserId: currentUserId,
                                    shares: viewModel.memberShares[expense.id] ?? []
                                )
                            }
                        }
                    }
                }
            }
            .padding(SplitSpacing.lg)
        }
        .background(SplitColors.paper.ignoresSafeArea())
        .splitInlineTitleDisplayMode()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(
                        item: URL(string: "https://clickplatforms.com/group/\(group.id)")!,
                        subject: Text("Join \(group.name) on Click Split"),
                        message: Text("Join our group on Click Split to share expenses!")
                    ) {
                        Label("Invite Members", systemImage: "person.badge.plus")
                    }

                    Button {
                        // Export action
                    } label: {
                        Label("Export Expenses CSV", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        // Leave group action
                    } label: {
                        Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(SplitColors.ink)
                }
            }
        }
        .sheet(isPresented: $showAddExpenseSheet) {
            AddExpenseView(group: group, members: viewModel.members) {
                Task {
                    await viewModel.loadGroupData(environment: environment)
                }
            }
        }
        .sheet(isPresented: $showSettleUpSheet) {
            SettleUpView(group: group, members: viewModel.members) {
                Task {
                    await viewModel.loadGroupData(environment: environment)
                }
            }
        }
        .task {
            await viewModel.loadGroupData(environment: environment)
        }
        .refreshable {
            await viewModel.loadGroupData(environment: environment)
        }
    }
}
