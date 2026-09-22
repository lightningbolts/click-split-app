import SwiftUI

/// Primary dashboard view for Click Split.
public struct DashboardView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var viewModel = DashboardViewModel()
    @State private var showCreateGroupSheet = false
    @State private var selectedGroup: SplitGroup?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
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
                            borderColor: SplitColors.ink,
                            shadowOffset: SplitSpacing.shadowOffset
                        )

                        // Groups Header
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

                        // Group Cards List
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
                                    NavigationLink(value: group) {
                                        GroupCardView(
                                            group: group,
                                            balance: viewModel.groupBalances[group.id] ?? 0
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(SplitSpacing.lg)
                    .padding(.bottom, 80) // Space for bottom action button
                }
                .background(SplitColors.paper.ignoresSafeArea())
                .navigationTitle("Click Split")
                .navigationDestination(for: SplitGroup.self) { group in
                    GroupDetailView(group: group)
                }

                // Primary Action Button (Green neo-brutalist square +)
                Button(action: {
                    SplitHaptics.impact(.medium)
                    showCreateGroupSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(SplitColors.white)
                        .frame(width: 56, height: 56)
                        .background(SplitColors.green)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .fill(SplitColors.ink)
                                .offset(x: SplitSpacing.shadowOffset, y: SplitSpacing.shadowOffset)
                        )
                }
                .padding(.trailing, SplitSpacing.xl)
                .padding(.bottom, SplitSpacing.xl)
            }
            .sheet(isPresented: $showCreateGroupSheet) {
                CreateGroupSheet(onGroupCreated: { newGroup in
                    Task {
                        await viewModel.loadData(environment: environment)
                    }
                })
            }
            .task {
                await viewModel.loadData(environment: environment)
            }
            .refreshable {
                await viewModel.loadData(environment: environment)
            }
        }
    }
}
