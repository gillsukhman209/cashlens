import SwiftUI

struct SubscriptionDetailView: View {
    let subscription: Subscription
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
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
                        // Hero Section
                        heroSection

                        // Subscription Details Card
                        detailsCard

                        // Cost Breakdown Card
                        costBreakdownCard

                        // Transaction History
                        if let transactions = subscription.transactions, !transactions.isEmpty {
                            transactionHistoryCard(transactions)
                        }

                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.2), categoryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: subscription.categoryIcon)
                    .font(.system(size: 32))
                    .foregroundColor(categoryColor)
            }

            // Merchant Name
            Text(subscription.merchantName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                .multilineTextAlignment(.center)

            // Amount per period
            VStack(spacing: 4) {
                Text(subscription.displayAmount)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                Text("per \(subscription.frequency.replacingOccurrences(of: "ly", with: ""))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Frequency Badge
            HStack(spacing: 6) {
                Image(systemName: "repeat")
                    .font(.caption)
                Text(subscription.frequencyLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(categoryColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(categoryColor.opacity(0.1))
            .cornerRadius(20)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
    }

    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            // Category
            if let category = subscription.category {
                DetailRow(
                    icon: subscription.categoryIcon,
                    iconColor: categoryColor,
                    title: "Category",
                    value: category
                )
                Divider().padding(.leading, 60)
            }

            // Last Charge
            DetailRow(
                icon: "calendar",
                iconColor: .blue,
                title: "Last Charged",
                value: formatFullDate(subscription.lastCharge)
            )

            Divider().padding(.leading, 60)

            // Next Expected
            if let nextExpected = subscription.nextExpected {
                DetailRow(
                    icon: "calendar.badge.clock",
                    iconColor: .orange,
                    title: "Next Expected",
                    value: formatFullDate(nextExpected)
                )
                Divider().padding(.leading, 60)
            }

            // Account
            if let accountName = subscription.accountName {
                DetailRow(
                    icon: "building.columns",
                    iconColor: .purple,
                    title: "Account",
                    value: subscription.accountMask != nil ? "\(accountName) (•••• \(subscription.accountMask!))" : accountName
                )
                Divider().padding(.leading, 60)
            }

            // Total Charges
            DetailRow(
                icon: "number",
                iconColor: .green,
                title: "Total Charges",
                value: "\(subscription.transactionCount) payments"
            )
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
    }

    // MARK: - Cost Breakdown Card
    private var costBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Cost Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            // Monthly Cost
            CostRow(
                title: "Monthly",
                amount: monthlyAmount,
                icon: "calendar",
                color: .blue
            )

            Divider().padding(.leading, 60)

            // Yearly Cost
            CostRow(
                title: "Yearly",
                amount: monthlyAmount * 12,
                icon: "calendar.badge.clock",
                color: .orange
            )

            Divider().padding(.leading, 60)

            // Total Spent
            let totalSpent = subscription.transactions?.reduce(0) { $0 + $1.amount } ?? (subscription.amount * Double(subscription.transactionCount))
            CostRow(
                title: "Total Spent",
                amount: totalSpent,
                icon: "sum",
                color: .red
            )
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
    }

    // MARK: - Transaction History Card
    private func transactionHistoryCard(_ transactions: [SubscriptionTransaction]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Payment History")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                Spacer()

                Text("\(transactions.count) payments")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                TransactionHistoryRow(transaction: transaction)

                if index < transactions.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
    }

    // MARK: - Helpers
    private var categoryColor: Color {
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

    private var monthlyAmount: Double {
        switch subscription.frequency {
        case "weekly":
            return subscription.amount * 4.33
        case "bi-weekly":
            return subscription.amount * 2.17
        case "monthly":
            return subscription.amount
        case "quarterly":
            return subscription.amount / 3
        case "yearly":
            return subscription.amount / 12
        default:
            return subscription.amount
        }
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Cost Row Component
struct CostRow: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(formatCurrency(amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Transaction History Row
struct TransactionHistoryRow: View {
    let transaction: SubscriptionTransaction

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(transaction.date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                if let accountName = transaction.accountName {
                    Text(transaction.accountMask != nil ? "\(accountName) •••• \(transaction.accountMask!)" : accountName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(formatCurrency(transaction.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

#Preview {
    SubscriptionDetailView(subscription: Subscription(
        id: "sub_netflix",
        merchantName: "Netflix",
        amount: 15.99,
        frequency: "monthly",
        category: "Entertainment",
        lastCharge: Date(),
        nextExpected: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
        accountName: "Chase Checking",
        accountMask: "1234",
        logoUrl: nil,
        transactionCount: 6,
        confidence: 0.95,
        transactions: [
            SubscriptionTransaction(id: "1", amount: 15.99, date: Date(), accountName: "Chase Checking", accountMask: "1234"),
            SubscriptionTransaction(id: "2", amount: 15.99, date: Calendar.current.date(byAdding: .month, value: -1, to: Date())!, accountName: "Chase Checking", accountMask: "1234"),
            SubscriptionTransaction(id: "3", amount: 15.99, date: Calendar.current.date(byAdding: .month, value: -2, to: Date())!, accountName: "Chase Checking", accountMask: "1234")
        ]
    ))
}
