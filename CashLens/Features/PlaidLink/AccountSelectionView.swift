import SwiftUI

struct AccountSelectionView: View {
    @EnvironmentObject var apiClient: APIClient
    @Binding var isPresented: Bool
    @Binding var hasLinkedBank: Bool

    @State private var accounts: [Account] = []
    @State private var selectedAccountIds: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.98, green: 0.95, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else {
                    VStack(spacing: 0) {
                        // Header
                        headerSection

                        // Account List
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(accounts) { account in
                                    AccountSelectionRow(
                                        account: account,
                                        isSelected: selectedAccountIds.contains(account.id)
                                    ) {
                                        toggleAccount(account.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 120)
                        }

                        Spacer()
                    }
                }

                // Bottom Button
                VStack {
                    Spacer()
                    bottomButton
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadAccounts()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                ProgressView()
                    .scaleEffect(1.3)
            }

            Text("Loading your accounts...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Success Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .green.opacity(0.4), radius: 15, x: 0, y: 8)

                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("Bank Connected!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Select the accounts you want to track")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Selection Summary
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)

                Text("\(selectedAccountIds.count) of \(accounts.count) selected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(20)
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }

    // MARK: - Bottom Button
    private var bottomButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)

            VStack(spacing: 12) {
                Button(action: {
                    Task { await saveSelection() }
                }) {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue with \(selectedAccountIds.count) Accounts")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: selectedAccountIds.isEmpty ? [.gray, .gray] : [
                                Color(red: 0.3, green: 0.5, blue: 1.0),
                                Color(red: 0.5, green: 0.3, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: selectedAccountIds.isEmpty ? .clear : .blue.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .disabled(selectedAccountIds.isEmpty || isSaving)

                Button("Select All") {
                    selectAll()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Functions
    private func toggleAccount(_ id: String) {
        if selectedAccountIds.contains(id) {
            selectedAccountIds.remove(id)
        } else {
            selectedAccountIds.insert(id)
        }
    }

    private func selectAll() {
        if selectedAccountIds.count == accounts.count {
            selectedAccountIds.removeAll()
        } else {
            selectedAccountIds = Set(accounts.map { $0.id })
        }
    }

    private func loadAccounts() async {
        isLoading = true
        do {
            let response = try await apiClient.getAccounts()
            await MainActor.run {
                self.accounts = response.accounts
                // Select all by default
                self.selectedAccountIds = Set(response.accounts.map { $0.id })
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func saveSelection() async {
        isSaving = true

        // Save hidden accounts to UserDefaults
        let hiddenIds = accounts
            .filter { !selectedAccountIds.contains($0.id) }
            .map { $0.id }

        UserDefaults.standard.set(hiddenIds, forKey: "hiddenAccountIds")

        await MainActor.run {
            isSaving = false
            hasLinkedBank = true
            isPresented = false
        }
    }
}

// MARK: - Account Selection Row
struct AccountSelectionRow: View {
    let account: Account
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection Circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 26, height: 26)

                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Account Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accountColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: account.typeIcon)
                        .font(.system(size: 20))
                        .foregroundColor(accountColor)
                }

                // Account Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
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
                Text(account.displayBalance)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(account.currentBalance >= 0 ? .primary : .red)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? .blue.opacity(0.15) : .black.opacity(0.05), radius: isSelected ? 10 : 5, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
}

#Preview {
    AccountSelectionView(isPresented: .constant(true), hasLinkedBank: .constant(false))
        .environmentObject(APIClient.shared)
}
