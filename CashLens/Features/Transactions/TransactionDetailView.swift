import SwiftUI

struct TransactionDetailView: View {
    let transaction: Transaction
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
                        // Hero Section - Amount
                        amountHeroSection

                        // Transaction Details Card
                        detailsCard

                        // Account Info Card
                        if transaction.account != nil {
                            accountCard
                        }

                        // Location Card (if available)
                        if let location = transaction.location,
                           (location.city != nil || location.address != nil) {
                            locationCard(location)
                        }

                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Transaction")
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

    // MARK: - Amount Hero Section
    private var amountHeroSection: some View {
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

                Image(systemName: transaction.categoryIcon)
                    .font(.system(size: 32))
                    .foregroundColor(categoryColor)
            }

            // Merchant Name
            Text(transaction.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                .multilineTextAlignment(.center)

            // Amount
            Text(transaction.isIncome ? "+\(transaction.displayAmount)" : "-\(transaction.displayAmount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(transaction.isIncome ? .green : Color(red: 0.1, green: 0.1, blue: 0.2))

            // Status Badge
            if transaction.pending {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Pending")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(20)
            }
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

            // Date
            DetailRow(
                icon: "calendar",
                iconColor: .blue,
                title: "Date",
                value: formatFullDate(transaction.date)
            )

            Divider().padding(.leading, 60)

            // Time
            DetailRow(
                icon: "clock",
                iconColor: .purple,
                title: "Time",
                value: formatTime(transaction.date)
            )

            Divider().padding(.leading, 60)

            // Category
            DetailRow(
                icon: transaction.categoryIcon,
                iconColor: categoryColor,
                title: "Category",
                value: transaction.category ?? "Uncategorized"
            )

            if let detailedCategory = transaction.detailedCategory, !detailedCategory.isEmpty {
                Divider().padding(.leading, 60)

                DetailRow(
                    icon: "tag",
                    iconColor: .orange,
                    title: "Subcategory",
                    value: detailedCategory
                )
            }

            Divider().padding(.leading, 60)

            // Payment Channel
            if let channel = transaction.paymentChannel {
                DetailRow(
                    icon: channelIcon(channel),
                    iconColor: .cyan,
                    title: "Payment Method",
                    value: channel.capitalized
                )

                Divider().padding(.leading, 60)
            }

            // Transaction Type
            DetailRow(
                icon: transaction.isIncome ? "arrow.down.circle" : "arrow.up.circle",
                iconColor: transaction.isIncome ? .green : .red,
                title: "Type",
                value: transaction.isIncome ? "Income" : "Expense"
            )
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
    }

    // MARK: - Account Card
    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            if let account = transaction.account {
                // Account Name
                DetailRow(
                    icon: accountIcon(account.type),
                    iconColor: .blue,
                    title: "Account",
                    value: account.name
                )

                Divider().padding(.leading, 60)

                // Account Type
                DetailRow(
                    icon: "creditcard",
                    iconColor: .purple,
                    title: "Type",
                    value: (account.subtype ?? account.type).capitalized
                )

                if let mask = account.mask {
                    Divider().padding(.leading, 60)

                    // Account Number (masked)
                    DetailRow(
                        icon: "number",
                        iconColor: .gray,
                        title: "Account Number",
                        value: "•••• \(mask)"
                    )
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
    }

    // MARK: - Location Card
    private func locationCard(_ location: TransactionLocation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Location")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            if let address = location.address {
                DetailRow(
                    icon: "mappin",
                    iconColor: .red,
                    title: "Address",
                    value: address
                )
                Divider().padding(.leading, 60)
            }

            if let city = location.city {
                DetailRow(
                    icon: "building.2",
                    iconColor: .blue,
                    title: "City",
                    value: [city, location.region].compactMap { $0 }.joined(separator: ", ")
                )
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
    }

    // MARK: - Helpers
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

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func channelIcon(_ channel: String) -> String {
        switch channel.lowercased() {
        case "online": return "globe"
        case "in store": return "storefront"
        case "other": return "questionmark.circle"
        default: return "creditcard"
        }
    }

    private func accountIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "depository": return "building.columns"
        case "credit": return "creditcard"
        case "loan": return "doc.text"
        case "investment": return "chart.line.uptrend.xyaxis"
        default: return "building.columns"
        }
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

#Preview {
    TransactionDetailView(transaction: Transaction(
        id: "1",
        plaidTransactionId: "plaid_1",
        amount: 25.99,
        isoCurrencyCode: "USD",
        date: Date(),
        name: "Starbucks",
        merchantName: "Starbucks",
        category: "Food and Drink",
        detailedCategory: "Coffee Shops",
        pending: false,
        paymentChannel: "in store",
        logoUrl: nil,
        location: nil,
        userNote: nil,
        userCategory: nil,
        account: TransactionAccount(name: "Chase Checking", mask: "1234", type: "depository", subtype: "checking")
    ))
}
