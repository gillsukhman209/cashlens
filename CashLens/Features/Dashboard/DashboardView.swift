import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var accounts: [Account] = []
    @State private var transactions: [Transaction] = []
    @State private var netWorth: Double = 0
    @State private var totals: AccountTotals?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Net Worth Card
                    netWorthCard

                    // Account Summary
                    if let totals = totals {
                        accountSummaryCard(totals: totals)
                    }

                    // Recent Transactions
                    recentTransactionsCard
                }
                .padding()
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

    private var netWorthCard: some View {
        VStack(spacing: 8) {
            Text("Net Worth")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if isLoading {
                ProgressView()
            } else {
                Text(formatCurrency(netWorth))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(netWorth >= 0 ? .primary : .red)
            }

            Text("Across \(accounts.count) accounts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func accountSummaryCard(totals: AccountTotals) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Summary")
                .font(.headline)

            HStack(spacing: 16) {
                summaryItem(title: "Checking", amount: totals.checking, icon: "dollarsign.circle.fill", color: .blue)
                summaryItem(title: "Savings", amount: totals.savings, icon: "banknote.fill", color: .green)
            }

            HStack(spacing: 16) {
                summaryItem(title: "Credit", amount: -totals.credit, icon: "creditcard.fill", color: .red)
                summaryItem(title: "Investments", amount: totals.investment, icon: "chart.line.uptrend.xyaxis", color: .purple)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func summaryItem(title: String, amount: Double, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: TransactionsView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if transactions.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(transactions.prefix(5)) { transaction in
                    TransactionRow(transaction: transaction)
                    if transaction.id != transactions.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

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

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: transaction.categoryIcon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(transaction.category ?? "Uncategorized")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.isIncome ? "+\(transaction.displayAmount)" : "-\(transaction.displayAmount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.isIncome ? .green : .primary)

                Text(formatDate(transaction.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    DashboardView()
        .environmentObject(APIClient.shared)
}
