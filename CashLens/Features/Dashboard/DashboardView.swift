import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var accounts: [Account] = []
    @State private var transactions: [Transaction] = []
    @State private var netWorth: Double = 0
    @State private var totals: AccountTotals?
    @State private var isLoading = true
    @State private var error: String?

    // Filter out hidden accounts
    private var visibleAccounts: [Account] {
        let hiddenIds = UserDefaults.standard.stringArray(forKey: "hiddenAccountIds") ?? []
        return accounts.filter { !hiddenIds.contains($0.id) }
    }

    private var visibleNetWorth: Double {
        visibleAccounts.reduce(0) { $0 + $1.currentBalance }
    }

    // Total savings = checking + savings accounts only
    private var totalSavings: Double {
        visibleAccounts
            .filter { $0.type == "depository" }
            .reduce(0) { $0 + $1.currentBalance }
    }

    // Total credit card debt
    private var totalCreditDebt: Double {
        visibleAccounts
            .filter { $0.type == "credit" }
            .reduce(0) { $0 + $1.currentBalance }
    }

    // Total investments
    private var totalInvestments: Double {
        visibleAccounts
            .filter { $0.type == "investment" }
            .reduce(0) { $0 + $1.currentBalance }
    }

    // True net worth = savings + investments - credit debt
    private var trueNetWorth: Double {
        totalSavings + totalInvestments - totalCreditDebt
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Vibrant gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.98, green: 0.96, blue: 1.0),
                        Color(red: 1.0, green: 0.98, blue: 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero Net Worth Section
                        netWorthSection

                        // Quick Stats
                        if let totals = totals {
                            quickStatsGrid(totals: totals)
                        }

                        // Recent Activity
                        recentActivitySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Net Worth Section
    private var netWorthSection: some View {
        VStack(spacing: 16) {
            // Main Savings Card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Savings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.85))

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(formatCurrency(totalSavings))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Text("Checking & Savings")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: "banknote.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)

                // Bottom row with credit debt and net worth
                HStack(spacing: 24) {
                    // Credit Card Debt
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Text("Credit Debt")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Text(totalCreditDebt > 0 ? "-\(formatCurrency(totalCreditDebt))" : "$0.00")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(totalCreditDebt > 0 ? Color(red: 1.0, green: 0.6, blue: 0.6) : .white)
                    }

                    Spacer()

                    // Net Worth
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Net Worth")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Image(systemName: trueNetWorth >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10))
                                .foregroundColor(trueNetWorth >= 0 ? .green : .red)
                        }
                        Text(formatCurrency(trueNetWorth))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.6, blue: 0.4),
                        Color(red: 0.1, green: 0.5, blue: 0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(24)
            .shadow(color: Color.green.opacity(0.3), radius: 20, x: 0, y: 10)

            // Credit Card Summary Card (only show if there's credit debt)
            if totalCreditDebt > 0 {
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 44, height: 44)

                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.red)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Credit Cards Owed")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                            Text("Pay off to increase net worth")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text("-\(formatCurrency(totalCreditDebt))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
        }
    }

    // MARK: - Quick Stats Grid
    private func quickStatsGrid(totals: AccountTotals) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Summary")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ColorfulStatCard(
                    title: "Checking",
                    amount: totals.checking,
                    icon: "dollarsign.circle.fill",
                    gradientColors: [Color.blue, Color.cyan]
                )

                ColorfulStatCard(
                    title: "Savings",
                    amount: totals.savings,
                    icon: "leaf.fill",
                    gradientColors: [Color.green, Color.mint]
                )

                ColorfulStatCard(
                    title: "Credit",
                    amount: -totals.credit,
                    icon: "creditcard.fill",
                    gradientColors: [Color.orange, Color.red]
                )

                ColorfulStatCard(
                    title: "Investments",
                    amount: totals.investment,
                    icon: "chart.line.uptrend.xyaxis",
                    gradientColors: [Color.purple, Color.pink]
                )
            }
        }
    }

    // Sort transactions by date (newest first)
    private var sortedTransactions: [Transaction] {
        transactions.sorted { $0.date > $1.date }
    }

    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                Spacer()

                NavigationLink(destination: TransactionsView()) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                }
            }

            VStack(spacing: 0) {
                if isLoading {
                    ForEach(0..<3, id: \.self) { _ in
                        TransactionSkeletonRow()
                    }
                } else if sortedTransactions.isEmpty {
                    emptyTransactionsView
                } else {
                    ForEach(Array(sortedTransactions.prefix(5).enumerated()), id: \.element.id) { index, transaction in
                        ColorfulTransactionRow(transaction: transaction)

                        if index < min(4, sortedTransactions.count - 1) {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
    }

    private var emptyTransactionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No transactions yet")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Your recent activity will appear here")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        error = nil

        do {
            async let accountsTask = apiClient.getAccounts()
            async let transactionsTask = apiClient.getTransactions(limit: 10)

            let accountsResponse = try await accountsTask
            let transactionsResponse = try await transactionsTask

            await MainActor.run {
                self.accounts = accountsResponse.accounts
                self.netWorth = accountsResponse.netWorth
                self.totals = accountsResponse.totals
                self.transactions = transactionsResponse.transactions
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Colorful Stat Card
struct ColorfulStatCard: View {
    let title: String
    let amount: Double
    let icon: String
    let gradientColors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: gradientColors.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatCurrency(amount))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(amount < 0 ? .red : Color(red: 0.1, green: 0.1, blue: 0.2))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: gradientColors[0].opacity(0.15), radius: 10, x: 0, y: 5)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Colorful Transaction Row
struct ColorfulTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 14) {
            // Category Icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.2), categoryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: transaction.categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(transaction.category ?? "Uncategorized")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if transaction.pending {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 5, height: 5)
                            Text("Pending")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.isIncome ? "+\(transaction.displayAmount)" : "-\(transaction.displayAmount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.isIncome ? .green : Color(red: 0.1, green: 0.1, blue: 0.2))

                Text(formatDate(transaction.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
    }

    private var categoryColor: Color {
        switch transaction.category?.lowercased() {
        case "food and drink", "restaurants":
            return .orange
        case "shopping":
            return .pink
        case "travel":
            return .blue
        case "transfer", "payment":
            return .purple
        case "income":
            return .green
        case "entertainment":
            return .red
        default:
            return .blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Skeleton Loading Row
struct TransactionSkeletonRow: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 80, height: 12)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 40, height: 12)
            }
        }
        .padding(.vertical, 10)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

#Preview {
    DashboardView()
        .environmentObject(APIClient.shared)
}
