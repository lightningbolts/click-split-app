import SwiftUI

/// Primary dashboard view for Click Split.
public struct DashboardView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.appRouter) private var router
    @State private var viewModel = DashboardViewModel()
    @State private var selectedTab: SplitTab = .groups
    @State private var showCreateGroupSheet = false
    @State private var showJoinGroupSheet = false
    @State private var showProfileSheet = false
    @State private var showGroupPickerForScan = false
    @State private var scanGroup: SplitGroup?
    @State private var showScannerSheet = false
    @State private var scanMembers: [SplitGroupMember] = []

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                        // Overall Balance Hero Card
                        VStack(alignment: .leading, spacing: SplitSpacing.md) {
                            Text(viewModel.netOverallBalance >= 0 ? "OVERALL, YOU'RE OWED" : "OVERALL, YOU OWE")
                                .font(SplitTypography.badge)
                                .foregroundColor(SplitColors.inkSoft)
                                .tracking(1)

                            SplitAmount(
                                abs(viewModel.netOverallBalance),
                                style: .hero,
                                color: viewModel.netOverallBalance >= 0 ? SplitColors.green : SplitColors.red
                            )

                            HStack(spacing: SplitSpacing.md) {
                                SplitBalanceBadge(.owed(viewModel.totalOwedToYou))
                                SplitBalanceBadge(.youOwe(viewModel.totalYouOwe))
                            }
                        }
                        .padding(SplitSpacing.xl)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .splitCardStyle(
                            surfaceColor: SplitColors.paperDim,
                            borderColor: SplitColors.border,
                            borderWidth: 1.0,
                            shadowOffset: 0
                        )

                        if selectedTab == .groups {
                            // Groups Section
                            groupsSection
                        } else {
                            // Activity Section
                            activitySection
                        }
                    }
                    .padding(SplitSpacing.lg)
                    .padding(.bottom, 110) // Space for floating liquid glass nav bar
                }
                .background(SplitColors.paper.ignoresSafeArea())
                .navigationTitle("Click Split")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            SplitHaptics.impact(.light)
                            showProfileSheet = true
                        } label: {
                            UserAvatarView(
                                avatarUrl: environment.sessionStore.currentUser?.avatarUrl,
                                name: environment.sessionStore.currentUser?.fullName,
                                size: 32,
                                shape: .circle,
                                showBorder: true,
                                showShadow: false
                            )
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            SplitHaptics.impact(.light)
                            showJoinGroupSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.plus")
                                Text("Join")
                            }
                            .font(SplitTypography.buttonSmall)
                            .foregroundColor(SplitColors.ink)
                            .padding(.horizontal, SplitSpacing.sm)
                            .padding(.vertical, 4)
                            .background(SplitColors.paperDim)
                            .overlay(
                                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                    .stroke(SplitColors.ink, lineWidth: 1)
                            )
                        }
                    }
                }
                .navigationDestination(for: SplitGroup.self) { group in
                    GroupDetailView(group: group)
                }

                // Floating Liquid Glass Bottom Navigation Bar
                LiquidGlassNavBar(
                    selectedTab: $selectedTab,
                    avatarUrl: environment.sessionStore.currentUser?.avatarUrl,
                    userName: environment.sessionStore.currentUser?.fullName,
                    onAddGroup: {
                        showCreateGroupSheet = true
                    },
                    onScanReceipt: {
                        handleScanTap()
                    },
                    onOpenProfile: {
                        showProfileSheet = true
                    }
                )
                .padding(.bottom, SplitSpacing.sm)
            }
            .sheet(isPresented: $showCreateGroupSheet) {
                CreateGroupSheet(onGroupCreated: { newGroup in
                    Task {
                        await viewModel.loadData(environment: environment)
                    }
                })
            }
            .sheet(isPresented: $showJoinGroupSheet) {
                GroupJoinView(onJoined: { joinedGroup in
                    Task {
                        await viewModel.loadData(environment: environment)
                    }
                })
            }
            .sheet(isPresented: $showProfileSheet) {
                UserProfileSheet()
            }
            .sheet(isPresented: $showGroupPickerForScan) {
                groupPickerSheet
            }
            .sheet(isPresented: $showScannerSheet) {
                ReceiptScannerSheet(members: scanMembers) { items, total, merchant in
                    Task {
                        await viewModel.loadData(environment: environment)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { router.showJoinGroupSheet },
                set: { router.showJoinGroupSheet = $0 }
            )) {
                GroupJoinView(prefilledGroupId: router.presentedJoinGroupId) { joinedGroup in
                    Task {
                        await viewModel.loadData(environment: environment)
                    }
                }
            }
            .task {
                await viewModel.loadData(environment: environment)
                await environment.sessionStore.refreshUserProfile()
            }
            .refreshable {
                await viewModel.loadData(environment: environment)
            }
            .onReceive(NotificationCenter.default.publisher(for: SplitRealtimeNotification.dataChanged)) { _ in
                Task {
                    await viewModel.loadData(environment: environment)
                }
            }
        }
    }

    // MARK: - Subviews

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.md) {
            HStack {
                Text("YOUR GROUPS")
                    .font(SplitTypography.sectionHeader)
                    .foregroundColor(SplitColors.ink)
                    .tracking(1)

                Spacer()

                Text("\(viewModel.groups.count)")
                    .font(SplitTypography.badge)
                    .padding(.horizontal, SplitSpacing.sm)
                    .padding(.vertical, SplitSpacing.xxs)
                    .background(SplitColors.paperDim)
                    .overlay(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .stroke(SplitColors.ink, lineWidth: 1)
                    )
            }

            if viewModel.isLoading && viewModel.groups.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, SplitSpacing.xxl)
            } else if viewModel.groups.isEmpty {
                VStack(spacing: SplitSpacing.md) {
                    Text("No groups yet")
                        .font(SplitTypography.title)
                        .foregroundColor(SplitColors.ink)

                    Text("Create a group or join an existing trip to split expenses.")
                        .font(SplitTypography.body)
                        .foregroundColor(SplitColors.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(SplitSpacing.xxl)
                .frame(maxWidth: .infinity)
                .splitCardStyle(surfaceColor: SplitColors.paperDim)
            } else {
                VStack(spacing: SplitSpacing.md) {
                    ForEach(viewModel.groups) { group in
                        let meta = viewModel.groupMeta[group.id]
                        NavigationLink(value: group) {
                            GroupCardView(
                                group: group,
                                balance: meta?.balance ?? viewModel.groupBalances[group.id] ?? 0,
                                memberSummary: meta?.memberSummary ?? viewModel.memberSummaries[group.id],
                                memberCount: meta?.memberCount ?? 1,
                                expenseCount: meta?.expenseCount ?? 0,
                                totalSpend: meta?.totalSpend ?? 0,
                                latestExpenseDesc: meta?.latestExpenseDesc,
                                latestExpenseAmount: meta?.latestExpenseAmount
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.md) {
            HStack {
                Text("BALANCE SUMMARY")
                    .font(SplitTypography.sectionHeader)
                    .foregroundColor(SplitColors.ink)
                    .tracking(1)

                Spacer()
            }

            if viewModel.groups.isEmpty {
                VStack(spacing: SplitSpacing.md) {
                    Text("No active balances")
                        .font(SplitTypography.title)
                        .foregroundColor(SplitColors.ink)

                    Text("When you join groups and add expenses, running debt calculations will appear here.")
                        .font(SplitTypography.body)
                        .foregroundColor(SplitColors.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(SplitSpacing.xxl)
                .frame(maxWidth: .infinity)
                .splitCardStyle(surfaceColor: SplitColors.paperDim)
            } else {
                VStack(spacing: SplitSpacing.md) {
                    ForEach(viewModel.groups) { group in
                        let bal = viewModel.groupBalances[group.id] ?? 0
                        HStack(spacing: SplitSpacing.md) {
                            Text(group.icon ?? "👥")
                                .font(.system(size: 26))
                                .frame(width: 44, height: 44)
                                .background(SplitColors.paper)
                                .overlay(
                                    RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                        .stroke(SplitColors.ink, lineWidth: 1.5)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(SplitTypography.title)
                                    .foregroundColor(SplitColors.ink)

                                Text(bal > 0 ? "You are owed in this group" : (bal < 0 ? "You owe in this group" : "All settled up"))
                                    .font(SplitTypography.caption)
                                    .foregroundColor(SplitColors.inkSoft)
                            }

                            Spacer()

                            SplitAmount(abs(bal), style: .medium, color: bal >= 0 ? SplitColors.green : SplitColors.red)
                        }
                        .padding(SplitSpacing.md)
                        .splitCardStyle(surfaceColor: SplitColors.paperDim)
                    }
                }
            }
        }
    }

    private var groupPickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplitSpacing.lg) {
                Text("Select a group for receipt scan:")
                    .font(SplitTypography.body)
                    .foregroundColor(SplitColors.inkSoft)

                ScrollView {
                    VStack(spacing: SplitSpacing.sm) {
                        ForEach(viewModel.groups) { group in
                            Button {
                                SplitHaptics.selection()
                                showGroupPickerForScan = false
                                startScan(for: group)
                            } label: {
                                HStack(spacing: SplitSpacing.md) {
                                    Text(group.icon ?? "👥")
                                        .font(.system(size: 24))
                                    Text(group.name)
                                        .font(SplitTypography.title)
                                        .foregroundColor(SplitColors.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(SplitColors.grey)
                                }
                                .padding(SplitSpacing.md)
                                .splitCardStyle(surfaceColor: SplitColors.paperDim)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()
            }
            .padding(SplitSpacing.lg)
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Scan Receipt")
            .splitInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showGroupPickerForScan = false
                    }
                    .foregroundColor(SplitColors.ink)
                }
            }
        }
    }

    private func handleScanTap() {
        if viewModel.groups.isEmpty {
            showCreateGroupSheet = true
        } else if viewModel.groups.count == 1, let singleGroup = viewModel.groups.first {
            startScan(for: singleGroup)
        } else {
            showGroupPickerForScan = true
        }
    }

    private func startScan(for group: SplitGroup) {
        scanGroup = group
        Task {
            do {
                let members = try await environment.groupRepository.fetchGroupMembers(groupId: group.id)
                await MainActor.run {
                    self.scanMembers = members
                    self.showScannerSheet = true
                }
            } catch {
                await MainActor.run {
                    self.scanMembers = []
                    self.showScannerSheet = true
                }
            }
        }
    }
}
