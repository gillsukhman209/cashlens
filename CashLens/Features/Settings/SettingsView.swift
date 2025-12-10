import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var institutions: [LinkedInstitution] = []
    @State private var isLoading = true
    @State private var showAddBank = false
    @State private var isSyncing = false

    var body: some View {
        NavigationView {
            List {
                // Linked Banks Section
                Section("Linked Banks") {
                    if isLoading {
                        ProgressView()
                    } else if institutions.isEmpty {
                        Text("No banks linked")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(institutions) { institution in
                            InstitutionRow(institution: institution)
                        }
                    }

                    Button(action: { showAddBank = true }) {
                        Label("Link New Bank", systemImage: "plus.circle")
                    }
                }

                // Sync Section
                Section("Data") {
                    Button(action: {
                        Task {
                            await syncData()
                        }
                    }) {
                        HStack {
                            Label("Sync Transactions", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                }

                // App Info Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://plaid.com/legal/end-user-privacy-policy/")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Account Section
                Section {
                    Button(role: .destructive) {
                        // Sign out logic
                        apiClient.userId = nil
                        UserDefaults.standard.removeObject(forKey: "userId")
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .refreshable {
                await loadInstitutions()
            }
            .task {
                await loadInstitutions()
            }
            .sheet(isPresented: $showAddBank) {
                PlaidLinkView(hasLinkedBank: .constant(true))
                    .environmentObject(apiClient)
            }
        }
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
        } catch {
            // Handle error
        }
        await MainActor.run {
            isSyncing = false
        }
    }
}

struct InstitutionRow: View {
    let institution: LinkedInstitution

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(institution.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Text("\(institution.accountCount) accounts")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if institution.status == "needs_reauth" {
                        Text("• Needs reconnection")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(institution.status == "active" ? .green : .orange)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIClient.shared)
}
