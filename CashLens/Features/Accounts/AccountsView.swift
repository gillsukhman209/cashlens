import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var accounts: [Account] = []
    @State private var institutions: [LinkedInstitution] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showAddBank = false

    // Group accounts by institution
    var groupedAccounts: [(String, [Account])] {
        let grouped = Dictionary(grouping: accounts) { account in
            account.institution?.name ?? "Unknown Bank"
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading accounts...")
                } else if accounts.isEmpty {
                    emptyState
                } else {
                    accountsList
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddBank = true }) {
                        Image(systemName: "plus")
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Accounts")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect a bank account to see your balances here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { showAddBank = true }) {
                Label("Connect Bank", systemImage: "plus")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
    }

    private var accountsList: some View {
        List {
            ForEach(groupedAccounts, id: \.0) { institutionName, institutionAccounts in
                Section {
                    ForEach(institutionAccounts) { account in
                        AccountRow(account: account)
                    }
                } header: {
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.blue)
                        Text(institutionName)
                            .textCase(nil)
                            .font(.headline)
                    }
                }
            }

            // Add Bank Button
            Section {
                Button(action: { showAddBank = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)

                        Text("Link Another Bank")
                            .foregroundColor(.blue)

                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

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
}

struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            // Account Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: account.typeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }

            // Account Details
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
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
                    .foregroundColor(account.currentBalance >= 0 ? .primary : .red)

                if let available = account.availableBalance, available != account.currentBalance {
                    Text("Available: \(formatCurrency(available))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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
