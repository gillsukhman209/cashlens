import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var subscriptions: [Subscription] = []
    @State private var totalMonthly: Double = 0
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedAccount: String? = nil // nil means "All Accounts"

    // Get unique accounts from subscriptions
    private var uniqueAccounts: [String] {
        let accounts = subscriptions.compactMap { sub -> String? in
            if let name = sub.accountName {
                if let mask = sub.accountMask {
                    return "\(name) •••• \(mask)"
                }
                return name
            }
            return nil
        }
        return Array(Set(accounts)).sorted()
    }

    // Filter subscriptions by selected account
    private var filteredSubscriptions: [Subscription] {
        guard let selectedAccount = selectedAccount else {
            return subscriptions
        }
        return subscriptions.filter { sub in
            if let name = sub.accountName {
                let fullName = sub.accountMask != nil ? "\(name) •••• \(sub.accountMask!)" : name
                return fullName == selectedAccount
            }
            return false
        }
    }

    // Calculate total monthly for filtered subscriptions
    private var filteredTotalMonthly: Double {
        var total = 0.0
        for sub in filteredSubscriptions {
            total += sub.monthlyEquivalent
        }
        return total
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
                    // Account Filter Bar
                    if !subscriptions.isEmpty && uniqueAccounts.count > 1 {
                        accountFilterBar
                            .padding(.top, 8)
                    }

                    if isLoading {
                        loadingView
                    } else if subscriptions.isEmpty {
                        emptyState
                    } else {
                        subscriptionsList
                    }
                }
            }
            .navigationTitle("Subscriptions")
            .task {
                await loadSubscriptions()
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)

                ProgressView()
                    .scaleEffect(1.2)
            }
            Text("Analyzing your transactions...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.2), Color.mint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("No Subscriptions Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                Text("We couldn't detect any recurring\nsubscriptions in your transactions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Subscriptions List
    private var subscriptionsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Hero Card - Total Monthly Cost
                totalCostCard

                // Subscriptions List (sorted by last charge date, newest first)
                VStack(spacing: 0) {
                    ForEach(Array(sortedSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                        SubscriptionRow(subscription: subscription, onUpdate: {
                            Task { await loadSubscriptions() }
                        })

                        if index < sortedSubscriptions.count - 1 {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)

                // Info Text
                infoSection

                Spacer()
                    .frame(height: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .refreshable {
            await loadSubscriptions()
        }
    }

    // MARK: - Total Cost Card
    private var totalCostCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedAccount != nil ? "Account Subscriptions" : "Monthly Subscriptions")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))

                    Text(formatCurrency(filteredTotalMonthly))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(filteredSubscriptions.count) recurring payment\(filteredSubscriptions.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.75))

                    Text("per month")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.75))

                    Text(formatCurrency(filteredTotalMonthly * 12) + "/year")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            // Show overall total when filtering by account
            if selectedAccount != nil {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)

                HStack {
                    Text("All accounts total:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))

                    Spacer()

                    Text(formatCurrency(totalMonthly) + "/mo")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.3, blue: 0.3),
                    Color(red: 0.95, green: 0.5, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: Color.red.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Subscriptions are detected automatically based on recurring transaction patterns.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)

                Text("Orange amounts show the monthly equivalent for non-monthly subscriptions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // Sort subscriptions by last charge date (newest first)
    private var sortedSubscriptions: [Subscription] {
        filteredSubscriptions.sorted { $0.lastCharge > $1.lastCharge }
    }

    // MARK: - Account Filter Bar
    private var accountFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All Accounts option
                AccountFilterPill(
                    title: "All Accounts",
                    isSelected: selectedAccount == nil,
                    color: .blue
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedAccount = nil
                    }
                }

                // Individual accounts
                ForEach(uniqueAccounts, id: \.self) { account in
                    AccountFilterPill(
                        title: account,
                        isSelected: selectedAccount == account,
                        color: .purple
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedAccount = account
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Data Loading
    private func loadSubscriptions() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.getSubscriptions(months: 3)
            await MainActor.run {
                self.subscriptions = response.subscriptions
                self.totalMonthly = response.totalMonthly
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
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Subscription Row
struct SubscriptionRow: View {
    let subscription: Subscription
    @EnvironmentObject var apiClient: APIClient
    var onUpdate: (() -> Void)?
    @State private var showDetail = false

    var categoryColor: Color {
        guard let category = subscription.category?.lowercased() else { return .blue }

        if category.contains("entertainment") || category.contains("streaming") {
            return .purple
        } else if category.contains("software") || category.contains("technology") {
            return .blue
        } else if category.contains("food") {
            return .orange
        } else if category.contains("health") || category.contains("fitness") {
            return .red
        } else if category.contains("music") {
            return .pink
        } else if category.contains("utility") || category.contains("bill") {
            return .cyan
        } else {
            return .blue
        }
    }

    var body: some View {
        Button(action: {
            showDetail = true
        }) {
            rowContent
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            SubscriptionDetailView(subscription: subscription, onUpdate: onUpdate)
                .environmentObject(apiClient)
        }
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.2), categoryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: subscription.categoryIcon)
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.merchantName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(subscription.frequencyLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let accountMask = subscription.accountMask {
                        Text("•••• \(accountMask)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Amount & Chevron
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(subscription.displayAmount)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                    // Show monthly equivalent if different from charge amount
                    if subscription.frequency != "monthly" {
                        Text("\(subscription.displayMonthlyEquivalent)/mo")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if let nextExpected = subscription.nextExpected {
                        Text("Next: \(formatDate(nextExpected))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Account Filter Pill
struct AccountFilterPill: View {
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
                .padding(.horizontal, 16)
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

#Preview {
    SubscriptionsView()
        .environmentObject(APIClient.shared)
}
