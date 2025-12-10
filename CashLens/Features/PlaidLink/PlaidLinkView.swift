import SwiftUI
import LinkKit

struct PlaidLinkView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var isLoading = false
    @State private var error: String?
    @State private var handler: Handler?
    @State private var showSuccess = false
    @Binding var hasLinkedBank: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "building.columns.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // Title
            Text("Connect Your Bank")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Description
            Text("Link your bank account to see all your transactions in one place.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Error message
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }

            // Connect button
            Button(action: {
                Task {
                    await openPlaidLink()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "link")
                        Text("Connect Bank Account")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading)
            .padding(.horizontal, 24)

            // Info text
            Text("Secured by Plaid. Your credentials are never stored on our servers.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .alert("Bank Connected!", isPresented: $showSuccess) {
            Button("Continue") {
                hasLinkedBank = true
            }
        } message: {
            Text("Your bank account has been linked successfully. Your transactions are being synced.")
        }
    }

    private func openPlaidLink() async {
        isLoading = true
        error = nil

        do {
            // Get link token from backend
            let linkToken = try await apiClient.createLinkToken()

            // Create Link configuration
            var configuration = LinkTokenConfiguration(token: linkToken) { success in
                Task {
                    await handleSuccess(success)
                }
            }

            configuration.onExit = { exit in
                if let error = exit.error {
                    self.error = error.localizedDescription
                }
                isLoading = false
            }

            // Create and present Link
            let result = Plaid.create(configuration)
            switch result {
            case .success(let handler):
                self.handler = handler
                await MainActor.run {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let viewController = windowScene.windows.first?.rootViewController {
                        handler.open(presentUsing: .viewController(viewController))
                    }
                }
            case .failure(let error):
                self.error = error.localizedDescription
                isLoading = false
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func handleSuccess(_ success: LinkSuccess) async {
        do {
            // Exchange public token for access token
            let publicToken = success.publicToken
            let metadata = success.metadata

            _ = try await apiClient.exchangeToken(
                publicToken: publicToken,
                institutionId: metadata.institution.id,
                institutionName: metadata.institution.name
            )

            // Sync transactions
            _ = try await apiClient.syncTransactions()

            await MainActor.run {
                isLoading = false
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    PlaidLinkView(hasLinkedBank: .constant(false))
        .environmentObject(APIClient.shared)
}
