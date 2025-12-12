import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var accounts: [Account] = []
    @State private var institutions: [LinkedInstitution] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showAddBank = false
    @State private var institutionToDelete: LinkedInstitution?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    // Filter out hidden accounts
    private var visibleAccounts: [Account] {
        let hiddenIds = UserDefaults.standard.stringArray(forKey: "hiddenAccountIds") ?? []
        return accounts.filter { !hiddenIds.contains($0.id) }
    }

    // Depository accounts (checking & savings)
    private var depositoryAccounts: [Account] {
        visibleAccounts.filter { $0.type == "depository" }
    }

    // Credit card accounts
    private var creditAccounts: [Account] {
        visibleAccounts.filter { $0.type == "credit" }
    }

    // Investment accounts
    private var investmentAccounts: [Account] {
        visibleAccounts.filter { $0.type == "investment" }
    }

    // Group depository accounts by institution
    private var depositoryByInstitution: [(String, [Account])] {
        let grouped = Dictionary(grouping: depositoryAccounts) { account in
            account.institution?.name ?? "Unknown Bank"
        }
        return grouped.sorted { $0.key < $1.key }
    }

    // Group credit accounts by institution
    private var creditByInstitution: [(String, [Account])] {
        let grouped = Dictionary(grouping: creditAccounts) { account in
            account.institution?.name ?? "Unknown Bank"
        }
        return grouped.sorted { $0.key < $1.key }
    }

    // Group investment accounts by institution
    private var investmentByInstitution: [(String, [Account])] {
        let grouped = Dictionary(grouping: investmentAccounts) { account in
            account.institution?.name ?? "Unknown Bank"
        }
        return grouped.sorted { $0.key < $1.key }
    }

    // Totals
    var totalSavings: Double {
        depositoryAccounts.reduce(0) { $0 + $1.currentBalance }
    }

    var totalCreditDebt: Double {
        creditAccounts.reduce(0) { $0 + $1.currentBalance }
    }

    var totalInvestments: Double {
        investmentAccounts.reduce(0) { $0 + $1.currentBalance }
    }

    var netWorth: Double {
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
            VStack(spacing: 24) {
                // Your Money Section (Checking & Savings)
                if !depositoryAccounts.isEmpty {
                    AccountTypeSection(
                        title: "Your Money",
                        subtitle: "Checking & Savings",
                        total: totalSavings,
                        icon: "banknote.fill",
                        gradientColors: [Color(red: 0.2, green: 0.7, blue: 0.5), Color(red: 0.1, green: 0.5, blue: 0.6)],
                        accountsByInstitution: depositoryByInstitution,
                        isDebt: false
                    )
                }

                // Credit Cards Section
                if !creditAccounts.isEmpty {
                    AccountTypeSection(
                        title: "Credit Cards",
                        subtitle: "Total Owed",
                        total: totalCreditDebt,
                        icon: "creditcard.fill",
                        gradientColors: [Color(red: 0.9, green: 0.3, blue: 0.3), Color(red: 0.95, green: 0.5, blue: 0.3)],
                        accountsByInstitution: creditByInstitution,
                        isDebt: true
                    )
                }

                // Investments Section
                if !investmentAccounts.isEmpty {
                    AccountTypeSection(
                        title: "Investments",
                        subtitle: "Total Value",
                        total: totalInvestments,
                        icon: "chart.line.uptrend.xyaxis",
                        gradientColors: [Color.purple, Color.pink],
                        accountsByInstitution: investmentByInstitution,
                        isDebt: false
                    )
                }

                // Net Worth Summary
                netWorthCard

                // Linked Banks Section
                if !institutions.isEmpty {
                    linkedBanksSection
                }

                // Add Bank Button
                addBankButton

                Spacer()
                    .frame(height: 80)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .alert("Remove Bank Connection?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                institutionToDelete = nil
            }
            Button("Remove", role: .destructive) {
                if let institution = institutionToDelete {
                    Task { await deleteInstitution(institution) }
                }
            }
        } message: {
            if let institution = institutionToDelete {
                Text("This will permanently remove \(institution.name) and all its accounts and transactions from CashLens. This cannot be undone.")
            }
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Removing bank...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }
        }
    }

    // MARK: - Net Worth Card
    private var netWorthCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Net Worth")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Assets minus liabilities")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()

            Text(formatCurrency(netWorth))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(netWorth >= 0 ? Color(red: 0.2, green: 0.7, blue: 0.5) : .red)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
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

    // MARK: - Linked Banks Section
    private var linkedBanksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Linked Banks")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                Spacer()

                Text("\(institutions.count) connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(institutions.enumerated()), id: \.element.id) { index, institution in
                    LinkedBankRow(
                        institution: institution,
                        onDelete: {
                            institutionToDelete = institution
                            showDeleteConfirmation = true
                        }
                    )

                    if index < institutions.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
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

    private func deleteInstitution(_ institution: LinkedInstitution) async {
        isDeleting = true
        institutionToDelete = nil

        do {
            try await apiClient.deleteInstitution(itemId: institution.id)

            // Refresh all data after deletion
            await loadData()

            await MainActor.run {
                isDeleting = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isDeleting = false
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

// MARK: - Linked Bank Row
struct LinkedBankRow: View {
    let institution: LinkedInstitution
    let onDelete: () -> Void

    var institutionColor: Color {
        let hash = institution.name.hashValue
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        return colors[abs(hash) % colors.count]
    }

    var body: some View {
        HStack(spacing: 14) {
            // Bank Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [institutionColor.opacity(0.2), institutionColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 18))
                    .foregroundColor(institutionColor)
            }

            // Bank Details
            VStack(alignment: .leading, spacing: 4) {
                Text(institution.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(institution.accountCount) account\(institution.accountCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if institution.status == "active" {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text(institution.status.capitalized)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Spacer()

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Account Type Section
struct AccountTypeSection: View {
    let title: String
    let subtitle: String
    let total: Double
    let icon: String
    let gradientColors: [Color]
    let accountsByInstitution: [(String, [Account])]
    let isDebt: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Section Header Card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isDebt && total > 0 ? "-\(formatCurrency(total))" : formatCurrency(total))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        let accountCount = accountsByInstitution.reduce(0) { $0 + $1.1.count }
                        Text("\(accountCount) account\(accountCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("\(accountsByInstitution.count) institution\(accountsByInstitution.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .shadow(color: gradientColors[0].opacity(0.3), radius: 15, x: 0, y: 8)

            // Accounts grouped by institution
            VStack(spacing: 0) {
                ForEach(Array(accountsByInstitution.enumerated()), id: \.element.0) { instIndex, institutionData in
                    let (institutionName, accounts) = institutionData

                    // Institution Header
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)

                            Text(institutionName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                        }

                        Spacer()

                        let instTotal = accounts.reduce(0) { $0 + $1.currentBalance }
                        Text(isDebt && instTotal > 0 ? "-\(formatCurrency(instTotal))" : formatCurrency(instTotal))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isDebt ? .red : Color(red: 0.1, green: 0.1, blue: 0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))

                    // Accounts for this institution
                    ForEach(Array(accounts.enumerated()), id: \.element.id) { accIndex, account in
                        ColorfulAccountCardRow(account: account)

                        if accIndex < accounts.count - 1 {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }

                    if instIndex < accountsByInstitution.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
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
