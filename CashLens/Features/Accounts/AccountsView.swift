import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var accounts: [Account] = []
    @State private var institutions: [LinkedInstitution] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showAddBank = false

    // Filter out hidden accounts
    private var visibleAccounts: [Account] {
        let hiddenIds = UserDefaults.standard.stringArray(forKey: "hiddenAccountIds") ?? []
        return accounts.filter { !hiddenIds.contains($0.id) }
    }

    // Group accounts by institution
    var groupedAccounts: [(String, [Account])] {
        let grouped = Dictionary(grouping: visibleAccounts) { account in
            account.institution?.name ?? "Unknown Bank"
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var totalBalance: Double {
        visibleAccounts.reduce(0) { $0 + $1.currentBalance }
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

                if isLoading {
                    loadingView
                } else if visibleAccounts.isEmpty {
                    emptyState
                } else {
                    accountsContent
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddBank = true }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)

                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                }
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .sheet(isPresented: $showAddBank) {
                PlaidLinkView(hasLinkedBank: .constant(true))
                    .environmentObject(apiClient)
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                ProgressView()
                    .scaleEffect(1.2)
            }
            Text("Loading accounts...")
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
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("No Accounts Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                Text("Connect your bank accounts to see\nyour balances and transactions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showAddBank = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Connect Bank")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.5, blue: 1.0),
                            Color(red: 0.5, green: 0.3, blue: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Accounts Content
    private var accountsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Total Balance Header
                totalBalanceCard

                // Accounts by Institution
                ForEach(groupedAccounts, id: \.0) { institutionName, institutionAccounts in
                    ColorfulInstitutionSection(
                        name: institutionName,
                        accounts: institutionAccounts
                    )
                }

                // Add Bank Button
                addBankButton

                Spacer()
                    .frame(height: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }

    // MARK: - Total Balance Card
    private var totalBalanceCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Balance")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))

                    Text(formatCurrency(totalBalance))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "chart.pie.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)

            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.75))

                    Text("\(visibleAccounts.count) accounts")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.75))

                    Text("\(groupedAccounts.count) banks")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.7, blue: 0.5),
                    Color(red: 0.1, green: 0.5, blue: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: Color.green.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    // MARK: - Add Bank Button
    private var addBankButton: some View {
        Button(action: { showAddBank = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Link Another Bank")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                    Text("Add more accounts to track")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        error = nil

        do {
            async let accountsTask = apiClient.getAccounts()
            async let institutionsTask = apiClient.getInstitutions()

            let accountsResponse = try await accountsTask
            let institutionsResponse = try await institutionsTask

            await MainActor.run {
                self.accounts = accountsResponse.accounts
                self.institutions = institutionsResponse.institutions
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

// MARK: - Colorful Institution Section
struct ColorfulInstitutionSection: View {
    let name: String
    let accounts: [Account]

    var sectionTotal: Double {
        accounts.reduce(0) { $0 + $1.currentBalance }
    }

    var institutionColor: Color {
        // Different colors for different banks
        let hash = name.hashValue
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        return colors[abs(hash) % colors.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [institutionColor.opacity(0.2), institutionColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 18))
                            .foregroundColor(institutionColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                        Text("\(accounts.count) account\(accounts.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(formatCurrency(sectionTotal))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(sectionTotal >= 0 ? Color(red: 0.1, green: 0.1, blue: 0.2) : .red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Divider()
                .padding(.leading, 72)

            // Accounts
            ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                ColorfulAccountCardRow(account: account)

                if index < accounts.count - 1 {
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: institutionColor.opacity(0.1), radius: 15, x: 0, y: 8)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Colorful Account Card Row
struct ColorfulAccountCardRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 14) {
            // Account Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [accountColor.opacity(0.2), accountColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: account.typeIcon)
                    .font(.system(size: 18))
                    .foregroundColor(accountColor)
            }

            // Account Details
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let subtype = account.subtype {
                        Text(subtype.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let mask = account.mask {
                        Text("•••• \(mask)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 4) {
                Text(account.displayBalance)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(account.currentBalance >= 0 ? Color(red: 0.1, green: 0.1, blue: 0.2) : .red)

                if let available = account.availableBalance,
                   abs(available - account.currentBalance) > 0.01 {
                    Text("Available: \(formatCurrency(available))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var accountColor: Color {
        switch account.type.lowercased() {
        case "depository":
            return account.subtype?.lowercased() == "savings" ? .green : .blue
        case "credit":
            return .orange
        case "investment":
            return .purple
        case "loan":
            return .red
        default:
            return .blue
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = account.isoCurrencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

#Preview {
    AccountsView()
        .environmentObject(APIClient.shared)
}
