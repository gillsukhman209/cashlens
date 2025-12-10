import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var offset = 0
    @State private var searchText = ""
    @State private var error: String?

    private let limit = 30

    var filteredTransactions: [Transaction] {
        if searchText.isEmpty {
            return transactions
        }
        return transactions.filter { transaction in
            transaction.displayName.localizedCaseInsensitiveContains(searchText) ||
            (transaction.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var groupedTransactions: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            formatDateHeader(transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading && transactions.isEmpty {
                    ProgressView("Loading transactions...")
                } else if transactions.isEmpty {
                    emptyState
                } else {
                    transactionsList
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .refreshable {
                await refresh()
            }
            .task {
                if transactions.isEmpty {
                    await loadTransactions()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Transactions")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your transactions will appear here once you connect a bank account.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var transactionsList: some View {
        List {
            ForEach(groupedTransactions, id: \.0) { dateString, dayTransactions in
                Section(header: Text(dateString)) {
                    ForEach(dayTransactions) { transaction in
                        TransactionListRow(transaction: transaction)
                    }
                }
            }

            if hasMore && !isLoading {
                Button("Load More") {
                    Task {
                        await loadMore()
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.blue)
            }

            if isLoading && !transactions.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func loadTransactions() async {
        isLoading = true
        error = nil
        offset = 0

        do {
            let response = try await apiClient.getTransactions(limit: limit, offset: 0)
            await MainActor.run {
                self.transactions = response.transactions
                self.hasMore = response.hasMore
                self.offset = response.transactions.count
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func loadMore() async {
        guard !isLoading && hasMore else { return }

        isLoading = true

        do {
            let response = try await apiClient.getTransactions(limit: limit, offset: offset)
            await MainActor.run {
                self.transactions.append(contentsOf: response.transactions)
                self.hasMore = response.hasMore
                self.offset += response.transactions.count
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func refresh() async {
        await loadTransactions()
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

struct TransactionListRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: transaction.categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }

            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(transaction.category ?? "Uncategorized")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if transaction.pending {
                        Text("• Pending")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Amount
            Text(transaction.isIncome ? "+\(transaction.displayAmount)" : "-\(transaction.displayAmount)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(transaction.isIncome ? .green : .primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TransactionsView()
        .environmentObject(APIClient.shared)
}
