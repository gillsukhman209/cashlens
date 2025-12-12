import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var subscriptions: [Subscription] = []
    @State private var totalMonthly: Double = 0
    @State private var isLoading = true
    @State private var error: String?

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

                if isLoading {
                    loadingView
                } else if subscriptions.isEmpty {
                    emptyState
                } else {
                    subscriptionsList
                }
            }
            .navigationTitle("Subscriptions")
            .refreshable {
                await loadSubscriptions()
            }
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
                        SubscriptionRow(subscription: subscription)

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
    }

    // MARK: - Total Cost Card
    private var totalCostCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly Subscriptions")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))

                    Text(formatCurrency(totalMonthly))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(subscriptions.count) recurring payment\(subscriptions.count == 1 ? "" : "s")")
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

                    Text(formatCurrency(totalMonthly * 12) + "/year")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.85))
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
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Subscriptions are detected automatically based on recurring transaction patterns.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // Sort subscriptions by last charge date (newest first)
    private var sortedSubscriptions: [Subscription] {
        subscriptions.sorted { $0.lastCharge > $1.lastCharge }
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

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(subscription.displayAmount)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                if let nextExpected = subscription.nextExpected {
                    Text("Next: \(formatDate(nextExpected))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

#Preview {
    SubscriptionsView()
        .environmentObject(APIClient.shared)
}
