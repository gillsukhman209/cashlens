import SwiftUI
import LinkKit

struct PlaidLinkView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var isLoading = false
    @State private var error: String?
    @State private var handler: Handler?
    @State private var showAccountSelection = false
    @Binding var hasLinkedBank: Bool

    private let features = [
        ("chart.bar.fill", "Track Spending", "See where your money goes", Color.orange),
        ("building.columns.fill", "Multiple Banks", "Connect all your accounts", Color.blue),
        ("lock.shield.fill", "Bank Security", "256-bit encryption", Color.green)
    ]

    var body: some View {
        ZStack {
            // Vibrant gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.97, green: 0.95, blue: 1.0),
                    Color(red: 1.0, green: 0.97, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative circles
            GeometryReader { geo in
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .offset(x: -50, y: -50)

                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .offset(x: geo.size.width - 100, y: 100)

                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 180, height: 180)
                    .offset(x: geo.size.width - 150, y: geo.size.height - 200)
            }

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 50)

                // Animated Icon
                bankIconSection

                Spacer()
                    .frame(height: 32)

                // Title and Description
                titleSection

                Spacer()
                    .frame(height: 40)

                // Feature Pills
                featureSection

                Spacer()

                // Error message
                if let error = error {
                    errorBanner(error)
                }

                // Connect button
                connectButton

                // Security info
                securityInfo

                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .fullScreenCover(isPresented: $showAccountSelection) {
            AccountSelectionView(isPresented: $showAccountSelection, hasLinkedBank: $hasLinkedBank)
                .environmentObject(apiClient)
        }
    }

    // MARK: - Bank Icon Section
    private var bankIconSection: some View {
        ZStack {
            // Animated rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3 - Double(index) * 0.1),
                                Color.purple.opacity(0.3 - Double(index) * 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: CGFloat(120 + index * 30), height: CGFloat(120 + index * 30))
            }

            // Main circle with gradient
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
                .frame(width: 100, height: 100)
                .shadow(color: .blue.opacity(0.4), radius: 25, x: 0, y: 12)

            // Icon
            Image(systemName: "building.columns.fill")
                .font(.system(size: 44))
                .foregroundColor(.white)
        }
    }

    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Connect Your Bank")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

            Text("Link your accounts to see all your transactions, balances, and spending insights.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - Feature Section
    private var featureSection: some View {
        VStack(spacing: 14) {
            ForEach(features, id: \.0) { icon, title, subtitle, color in
                ColorfulFeatureRow(icon: icon, title: title, subtitle: subtitle, color: color)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Error Banner
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(2)

            Spacer()
        }
        .padding(14)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .padding(.bottom, 16)
    }

    // MARK: - Connect Button
    private var connectButton: some View {
        Button(action: {
            Task { await openPlaidLink() }
        }) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Connect Bank Account")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                LinearGradient(
                    colors: isLoading ? [.gray, .gray] : [
                        Color(red: 0.3, green: 0.5, blue: 1.0),
                        Color(red: 0.5, green: 0.3, blue: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(18)
            .shadow(color: isLoading ? .clear : .blue.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .disabled(isLoading)
        .padding(.bottom, 16)
    }

    // MARK: - Security Info
    private var securityInfo: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(.green)

            Text("Secured by ")
                .font(.caption)
                .foregroundColor(.secondary)
            +
            Text("Plaid")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            +
            Text(". Your credentials are never stored.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Plaid Link
    private func openPlaidLink() async {
        isLoading = true
        error = nil

        do {
            let linkToken = try await apiClient.createLinkToken()

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
            let publicToken = success.publicToken
            let metadata = success.metadata

            _ = try await apiClient.exchangeToken(
                publicToken: publicToken,
                institutionId: metadata.institution.id,
                institutionName: metadata.institution.name
            )

            _ = try await apiClient.syncTransactions()

            await MainActor.run {
                isLoading = false
                // Show account selection instead of direct success
                showAccountSelection = true
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Colorful Feature Row
struct ColorfulFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(color.opacity(0.8))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(16)
    }
}

#Preview {
    PlaidLinkView(hasLinkedBank: .constant(false))
        .environmentObject(APIClient.shared)
}
