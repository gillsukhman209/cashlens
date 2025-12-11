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
                .preferredColorScheme(.light) // Force light mode
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var hasLinkedBank = false
    @State private var isCheckingStatus = true
    @State private var hasUser = false

    var body: some View {
        Group {
            if isCheckingStatus {
                LoadingView()
            } else if !hasUser {
                OnboardingView(hasUser: $hasUser)
                    .environmentObject(apiClient)
            } else if !hasLinkedBank {
                PlaidLinkView(hasLinkedBank: $hasLinkedBank)
                    .environmentObject(apiClient)
            } else {
                MainTabView()
                    .environmentObject(apiClient)
            }
        }
        .task {
            await checkStatus()
        }
    }

    private func checkStatus() async {
        if apiClient.userId != nil {
            hasUser = true
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

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var apiClient: APIClient
    @Binding var hasUser: Bool
    @State private var name = ""
    @State private var email = ""
    @State private var isLoading = false
    @State private var error: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case name, email
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 80)

                    // Logo
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)

                    Spacer()
                        .frame(height: 40)

                    // Title
                    Text("CashLens")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("Your finances, simplified")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    Spacer()
                        .frame(height: 60)

                    // Input Fields
                    VStack(spacing: 16) {
                        CustomTextField(
                            placeholder: "Your name",
                            text: $name,
                            icon: "person.fill"
                        )
                        .focused($focusedField, equals: .name)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }

                        CustomTextField(
                            placeholder: "Email address",
                            text: $email,
                            icon: "envelope.fill"
                        )
                        .focused($focusedField, equals: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                    }
                    .padding(.horizontal, 24)

                    // Error
                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 12)
                    }

                    Spacer()
                        .frame(height: 40)

                    // Button
                    Button(action: { Task { await createUser() } }) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Get Started")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            canContinue
                                ? LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(canContinue ? .white : .gray)
                        .cornerRadius(16)
                    }
                    .disabled(!canContinue || isLoading)
                    .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 100)
                }
            }
        }
        .onTapGesture { focusedField = nil }
    }

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@")
    }

    private func createUser() async {
        focusedField = nil
        isLoading = true
        error = nil

        do {
            _ = try await apiClient.createUser(email: email.trimmingCharacters(in: .whitespaces), name: name.trimmingCharacters(in: .whitespaces))
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

// MARK: - Custom Text Field
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            TextField(placeholder, text: $text)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)

            AccountsView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "creditcard.fill" : "creditcard")
                    Text("Accounts")
                }
                .tag(1)

            TransactionsView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                    Text("Activity")
                }
                .tag(2)

            SubscriptionsView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "repeat.circle.fill" : "repeat.circle")
                    Text("Subscriptions")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                    Text("Settings")
                }
                .tag(4)
        }
        .tint(.blue)
    }
}

#Preview {
    OnboardingView(hasUser: .constant(false))
        .environmentObject(APIClient.shared)
}
