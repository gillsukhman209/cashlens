import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var institutions: [LinkedInstitution] = []
    @State private var isLoading = true
    @State private var showAddBank = false
    @State private var isSyncing = false
    @State private var showSignOutAlert = false
    @State private var lastSyncTime: Date?
    @State private var showSwitchAccountAlert = false

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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Profile Section
                        profileSection

                        // Linked Banks Section
                        linkedBanksSection

                        // Data Section
                        dataSection

                        // About Section
                        aboutSection

                        // Sign Out
                        signOutSection

                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .refreshable {
                await loadInstitutions()
            }
            .task {
                await loadInstitutions()
            }
            .sheet(isPresented: $showAddBank, onDismiss: {
                Task { await loadInstitutions() }
            }) {
                PlaidLinkView(hasLinkedBank: .constant(true))
                    .environmentObject(apiClient)
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access your accounts.")
            }
        }
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Avatar with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.5, blue: 1.0),
                                    Color(red: 0.5, green: 0.3, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)

                    Text(getInitials())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("CashLens User")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)

                        Text("\(institutions.count) linked bank\(institutions.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Debug: Show userId to help diagnose issues
                    if let userId = apiClient.userId {
                        Text("ID: \(userId)")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.6))
                            .textSelection(.enabled)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
    }

    // MARK: - Linked Banks Section
    private var linkedBanksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ColorfulSectionHeader(title: "Linked Banks", icon: "building.columns.fill", color: .blue)

            VStack(spacing: 0) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if institutions.isEmpty {
                    emptyBanksView
                } else {
                    ForEach(Array(institutions.enumerated()), id: \.element.id) { index, institution in
                        ExpandableLinkedBankRow(
                            institution: institution,
                            onToggleAccount: { account, isHidden in
                                Task { await toggleAccountVisibility(account: account, isHidden: isHidden) }
                            }
                        )

                        if index < institutions.count - 1 {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }

                Divider()
                    .padding(.leading, 68)

                // Add Bank Button
                Button(action: { showAddBank = true }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

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

                        Text("Link New Bank")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .shadow(color: Color.blue.opacity(0.08), radius: 12, x: 0, y: 6)
        }
    }

    private var emptyBanksView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No banks linked")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Data Section
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ColorfulSectionHeader(title: "Data", icon: "arrow.triangle.2.circlepath", color: .green)

            VStack(spacing: 0) {
                Button(action: {
                    Task { await syncData() }
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.2), Color.mint.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            if isSyncing {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync Transactions")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                            if let lastSync = lastSyncTime {
                                Text("Last synced \(formatRelativeTime(lastSync))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Tap to refresh your data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isSyncing)
            }
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .shadow(color: Color.green.opacity(0.08), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ColorfulSectionHeader(title: "About", icon: "info.circle.fill", color: .purple)

            VStack(spacing: 0) {
                // Version
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "app.badge")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                    }

                    Text("Version")
                        .font(.body)
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                    Spacer()

                    Text("1.0.0")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()
                    .padding(.leading, 68)

                // Privacy Policy
                Link(destination: URL(string: "https://plaid.com/legal/end-user-privacy-policy/")!) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.purple)
                        }

                        Text("Privacy Policy")
                            .font(.body)
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .shadow(color: Color.purple.opacity(0.08), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Sign Out Section
    private var signOutSection: some View {
        VStack(spacing: 12) {
            // Switch Account button (for fixing userId mismatch)
            if apiClient.userId != "6939f55204bf411035728d47" {
                Button(action: { showSwitchAccountAlert = true }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Switch to Main Account")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)

                            Text("Restore access to all your data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color(.systemBackground))
                .cornerRadius(18)
                .shadow(color: Color.blue.opacity(0.08), radius: 12, x: 0, y: 6)
                .alert("Switch Account?", isPresented: $showSwitchAccountAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Switch", role: .none) {
                        switchToMainAccount()
                    }
                } message: {
                    Text("This will switch to your main account with all your linked banks and imported data.")
                }
            }

            VStack(spacing: 0) {
                Button(action: { showSignOutAlert = true }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.2), Color.orange.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18))
                                .foregroundColor(.red)
                        }

                        Text("Sign Out")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.red)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .shadow(color: Color.red.opacity(0.08), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Helper Functions
    private func getInitials() -> String {
        "CL"
    }

    private func loadInstitutions() async {
        isLoading = true
        do {
            let response = try await apiClient.getInstitutions()
            await MainActor.run {
                self.institutions = response.institutions
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func toggleAccountVisibility(account: InstitutionAccount, isHidden: Bool) async {
        do {
            try await apiClient.toggleAccountVisibility(accountId: account.id, isHidden: isHidden)
            // Reload institutions to get updated account status
            await loadInstitutions()
        } catch {
            // Silently handle error - the toggle will reset on next load
            print("Error toggling account visibility: \(error)")
        }
    }

    private func syncData() async {
        isSyncing = true
        do {
            _ = try await apiClient.syncTransactions()
            await MainActor.run {
                lastSyncTime = Date()
            }
        } catch {
            // Handle error silently
        }
        await MainActor.run {
            isSyncing = false
        }
    }

    private func signOut() {
        apiClient.userId = nil
        UserDefaults.standard.removeObject(forKey: "userId")
    }

    private func switchToMainAccount() {
        // Switch to the main account with all the data
        let mainAccountId = "6939f55204bf411035728d47"
        apiClient.userId = mainAccountId
        UserDefaults.standard.set(mainAccountId, forKey: "userId")
        // Reload data
        Task { await loadInstitutions() }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Colorful Section Header
struct ColorfulSectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
        }
        .padding(.leading, 4)
    }
}

// MARK: - Expandable Linked Bank Row
struct ExpandableLinkedBankRow: View {
    let institution: LinkedInstitution
    let onToggleAccount: (InstitutionAccount, Bool) -> Void
    @State private var isExpanded = false

    var institutionColor: Color {
        let hash = institution.name.hashValue
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        return colors[abs(hash) % colors.count]
    }

    // Helper to check if status indicates a connected account
    private func isConnectedStatus(_ status: String) -> Bool {
        return status == "active" || status == "manual"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Bank Header (tappable to expand)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 14) {
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text(institution.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                        Text(institution.accountSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Expand/Collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)

                    // Status indicator
                    ZStack {
                        Circle()
                            .fill(isConnectedStatus(institution.status) ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .frame(width: 30, height: 30)

                        Image(systemName: isConnectedStatus(institution.status) ? "checkmark" : "exclamationmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isConnectedStatus(institution.status) ? .green : .orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded accounts list
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.leading, 68)

                    if let accounts = institution.accounts, !accounts.isEmpty {
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                            AccountToggleRow(
                                account: account,
                                onToggle: { isHidden in
                                    onToggleAccount(account, isHidden)
                                }
                            )

                            if index < accounts.count - 1 {
                                Divider()
                                    .padding(.leading, 84)
                            }
                        }
                    } else {
                        // No accounts available - backend might need deployment
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No accounts found. Try syncing your data.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color(.systemGray6).opacity(0.5))
            }
        }
    }
}

// MARK: - Account Toggle Row
struct AccountToggleRow: View {
    let account: InstitutionAccount
    let onToggle: (Bool) -> Void
    @State private var isEnabled: Bool

    init(account: InstitutionAccount, onToggle: @escaping (Bool) -> Void) {
        self.account = account
        self.onToggle = onToggle
        self._isEnabled = State(initialValue: !account.isHidden)
    }

    var accountColor: Color {
        switch account.type.lowercased() {
        case "depository":
            return account.subtype?.lowercased() == "savings" ? .green : .blue
        case "credit":
            return .orange
        case "investment":
            return .purple
        default:
            return .blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Account type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accountColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: account.typeIcon)
                    .font(.system(size: 14))
                    .foregroundColor(accountColor)
            }

            // Account details
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(account.typeLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let mask = account.mask {
                        Text("••••\(mask)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(account.displayBalance)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(account.currentBalance >= 0 ? .secondary : .red)
                }
            }

            Spacer()

            // Toggle switch
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(.green)
                .onChange(of: isEnabled) { _, newValue in
                    onToggle(!newValue) // isHidden is opposite of isEnabled
                }
        }
        .padding(.horizontal, 16)
        .padding(.leading, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIClient.shared)
}
