//
//  CashLensApp.swift
//  CashLens
//
//  Created by Sukhman Singh on 12/10/25.
//

import SwiftUI

@main
struct CashLensApp: App {
    @StateObject private var apiClient = APIClient.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(apiClient)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var hasLinkedBank = false
    @State private var isCheckingStatus = true
    @State private var hasUser = false

    var body: some View {
        Group {
            if isCheckingStatus {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            } else if !hasUser {
                // Onboarding - Create user
                OnboardingView(hasUser: $hasUser)
                    .environmentObject(apiClient)
            } else if !hasLinkedBank {
                // No bank linked yet
                PlaidLinkView(hasLinkedBank: $hasLinkedBank)
                    .environmentObject(apiClient)
            } else {
                // Main app with tab bar
                MainTabView()
                    .environmentObject(apiClient)
            }
        }
        .task {
            await checkStatus()
        }
    }

    private func checkStatus() async {
        // Check if user exists
        if apiClient.userId != nil {
            hasUser = true

            // Check if any banks are linked
            do {
                let response = try await apiClient.getInstitutions()
                await MainActor.run {
                    hasLinkedBank = !response.institutions.isEmpty
                    isCheckingStatus = false
                }
            } catch {
                await MainActor.run {
                    hasLinkedBank = false
                    isCheckingStatus = false
                }
            }
        } else {
            await MainActor.run {
                hasUser = false
                isCheckingStatus = false
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var apiClient: APIClient
    @Binding var hasUser: Bool
    @State private var name = ""
    @State private var email = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App Icon/Logo
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // Title
            VStack(spacing: 8) {
                Text("Welcome to CashLens")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("See all your finances in one place")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Input Fields
            VStack(spacing: 16) {
                TextField("Your Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            .padding(.horizontal, 32)

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Continue Button
            Button(action: {
                Task {
                    await createUser()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Get Started")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canContinue ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canContinue || isLoading)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var canContinue: Bool {
        !name.isEmpty && !email.isEmpty && email.contains("@")
    }

    private func createUser() async {
        isLoading = true
        error = nil

        do {
            _ = try await apiClient.createUser(email: email, name: name)
            await MainActor.run {
                hasUser = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

            AccountsView()
                .tabItem {
                    Label("Accounts", systemImage: "building.columns.fill")
                }

            TransactionsView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(APIClient.shared)
}
