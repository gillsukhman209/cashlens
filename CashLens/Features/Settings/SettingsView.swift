import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var institutions: [LinkedInstitution] = []
    @State private var isLoading = true
    @State private var showAddBank = false
    @State private var isSyncing = false
    @State private var showSignOutAlert = false
    @State private var lastSyncTime: Date?

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
                        ColorfulLinkedBankRow(institution: institution)

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

// MARK: - Colorful Linked Bank Row
struct ColorfulLinkedBankRow: View {
    let institution: LinkedInstitution

    var institutionColor: Color {
        let hash = institution.name.hashValue
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        return colors[abs(hash) % colors.count]
    }

    var body: some View {
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

                HStack(spacing: 6) {
                    Text("\(institution.accountCount) account\(institution.accountCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if institution.status == "needs_reauth" {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text("Needs reconnection")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(institution.status == "active" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 30, height: 30)

                Image(systemName: institution.status == "active" ? "checkmark" : "exclamationmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(institution.status == "active" ? .green : .orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIClient.shared)
}
