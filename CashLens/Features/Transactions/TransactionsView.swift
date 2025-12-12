import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var hasMore = true
    @State private var offset = 0
    @State private var searchText = ""
    @State private var error: String?
    @State private var selectedFilter: TransactionFilter = .all

    private let limit = 30

    enum TransactionFilter: String, CaseIterable {
        case all = "All"
        case income = "Income"
        case expenses = "Expenses"
        case pending = "Pending"

        var color: Color {
            switch self {
            case .all: return .blue
            case .income: return .green
            case .expenses: return .red
            case .pending: return .orange
            }
        }
    }

    var filteredTransactions: [Transaction] {
        var result = transactions

        if !searchText.isEmpty {
            result = result.filter { transaction in
                transaction.displayName.localizedCaseInsensitiveContains(searchText) ||
                (transaction.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch selectedFilter {
        case .all:
            break
        case .income:
            result = result.filter { $0.isIncome }
        case .expenses:
            result = result.filter { !$0.isIncome }
        case .pending:
            result = result.filter { $0.pending }
        }

        // Sort by date (newest first)
        return result.sorted { $0.date > $1.date }
    }

    var groupedTransactions: [(String, [Transaction])] {
        // Group transactions by date
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }

        // Sort groups by date (newest first) and format the header
        return grouped
            .sorted { $0.key > $1.key }
            .map { (formatDateHeader($0.key), $0.value.sorted { $0.date > $1.date }) }
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

                VStack(spacing: 0) {
                    // Filter Pills
                    filterBar
                        .padding(.top, 8)

                    // Content
                    if isLoading && transactions.isEmpty {
                        loadingView
                    } else if transactions.isEmpty {
                        emptyState
                    } else if filteredTransactions.isEmpty {
                        noResultsView
                    } else {
                        transactionsList
                    }
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .task {
                if transactions.isEmpty {
                    await loadTransactions()
                }
            }
        }
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    ColorfulFilterPill(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        color: filter.color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                ProgressView()
                    .scaleEffect(1.2)
            }
            Text("Loading transactions...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("No Transactions")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                Text("Your transactions will appear here\nonce you connect a bank account.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 8) {
                Text("No Results")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                Text("Try adjusting your search or filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Transactions List
    private var transactionsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedTransactions, id: \.0) { dateString, dayTransactions in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(Array(dayTransactions.enumerated()), id: \.element.id) { index, transaction in
                                ColorfulTransactionListItem(transaction: transaction)

                                if index < dayTransactions.count - 1 {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    } header: {
                        HStack {
                            Text(dateString)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.97, blue: 1.0),
                                    Color(red: 0.98, green: 0.96, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                }

                // Load More
                if hasMore && !isLoading {
                    Button(action: {
                        Task { await loadMore() }
                    }) {
                        HStack(spacing: 8) {
                            Text("Load More")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                if isLoading && !transactions.isEmpty {
                    ProgressView()
                        .padding(.vertical, 20)
                }

                Spacer()
                    .frame(height: 80)
            }
            .padding(.top, 8)
        }
        .refreshable {
            await refresh()
        }
    }

    // MARK: - Data Loading
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

// MARK: - Colorful Filter Pill
struct ColorfulFilterPill: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color(red: 0.1, green: 0.1, blue: 0.2))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Color(.systemBackground)
                        }
                    }
                )
                .cornerRadius(20)
                .shadow(color: isSelected ? color.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 8 : 4, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Colorful Transaction List Item
struct ColorfulTransactionListItem: View {
    let transaction: Transaction
    @State private var showDetail = false

    var body: some View {
        Button(action: {
            showDetail = true
        }) {
            transactionContent
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            TransactionDetailView(transaction: transaction)
        }
    }

    private var transactionContent: some View {
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
                    .frame(width: 50, height: 50)

                Image(systemName: transaction.categoryIcon)
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.displayName)
                    .font(.body)
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
                                .frame(width: 6, height: 6)
                            Text("Pending")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Spacer()

            // Amount & Chevron
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.isIncome ? "+\(transaction.displayAmount)" : "-\(transaction.displayAmount)")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(transaction.isIncome ? .green : Color(red: 0.1, green: 0.1, blue: 0.2))

                    Text(formatTime(transaction.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
        case "bills", "utilities":
            return .cyan
        default:
            return .blue
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    TransactionsView()
        .environmentObject(APIClient.shared)
}
