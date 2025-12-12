import SwiftUI
import UniformTypeIdentifiers

struct StatementImportView: View {
    @EnvironmentObject var apiClient: APIClient
    @Environment(\.dismiss) var dismiss

    // File selection
    @State private var showFilePicker = false
    @State private var selectedFiles: [SelectedFile] = []
    @State private var isLoading = false
    @State private var error: String?

    // Import settings
    @State private var accountName = "Apple Card"
    @State private var step: ImportStep = .selectFiles
    @State private var importMode: ImportMode = .subscriptionsOnly
    @State private var createdAccountId: String?

    // Results
    @State private var importResult: MultiFileImportResponse?
    @State private var detectedSubscriptions: [DetectedSubscription] = []

    // Optional callback when import is complete (used for onboarding flow)
    var onComplete: (() -> Void)?

    struct SelectedFile: Identifiable {
        let id = UUID()
        let name: String
        let data: Data
        let transactionCount: Int
    }

    struct DetectedSubscription: Identifiable {
        let id: String
        let merchantName: String
        let amount: Double
        let frequency: String
    }

    enum ImportStep {
        case selectFiles
        case chooseMode
        case importing
        case complete
    }

    enum ImportMode {
        case subscriptionsOnly
        case fullImport
    }

    var totalTransactionCount: Int {
        selectedFiles.reduce(0) { $0 + $1.transactionCount }
    }

    var body: some View {
        NavigationStack {
            VStack {
                switch step {
                case .selectFiles:
                    fileSelectionView
                case .chooseMode:
                    chooseModeView
                case .importing:
                    importingView
                case .complete:
                    completeView
                }
            }
            .navigationTitle("Import Statements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.text],
            allowsMultipleSelection: true,
            onCompletion: handleFileSelection
        )
    }

    // MARK: - Step 1: File Selection (Multiple Files)

    private var fileSelectionView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 30)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.purple)
            }

            Text("Import Apple Card Statements")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

            Text("Select 3-10 monthly statement files to detect your subscriptions accurately")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Selected files list
            if !selectedFiles.isEmpty {
                VStack(spacing: 0) {
                    ForEach(selectedFiles) { file in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.subheadline)
                                    .lineLimit(1)

                                Text("\(file.transactionCount) transactions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                selectedFiles.removeAll { $0.id == file.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)

                        if file.id != selectedFiles.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 24)

                // Summary
                HStack {
                    Text("\(selectedFiles.count) files")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("\(totalTransactionCount) total transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Instructions (collapsed if files selected)
            if selectedFiles.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How to export from Apple Card:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    instructionRow(number: "1", text: "Open Wallet → Apple Card")
                    instructionRow(number: "2", text: "Tap Card Balance")
                    instructionRow(number: "3", text: "Export Transactions as CSV")
                    instructionRow(number: "4", text: "Repeat for each month")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 24)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: selectedFiles.isEmpty ? "folder" : "plus")
                        Text(selectedFiles.isEmpty ? "Select Files" : "Add More Files")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedFiles.count >= 10 ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedFiles.count >= 10)
                .padding(.horizontal, 24)

                if selectedFiles.count >= 3 {
                    Button {
                        step = .chooseMode
                    } label: {
                        HStack {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                } else if !selectedFiles.isEmpty {
                    Text("Select at least \(3 - selectedFiles.count) more file(s)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.purple))

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Step 2: Choose Import Mode

    private var chooseModeView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            Text("What would you like to do?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

            Text("Choose how to use your \(totalTransactionCount) transactions")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                // Option 1: Subscriptions Only
                Button {
                    importMode = .subscriptionsOnly
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 50, height: 50)

                            Image(systemName: "repeat.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.purple)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Detect Subscriptions Only")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                            Text("Find recurring charges without adding transactions to your history")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Image(systemName: importMode == .subscriptionsOnly ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(importMode == .subscriptionsOnly ? .purple : .secondary.opacity(0.5))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: importMode == .subscriptionsOnly ? .purple.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(importMode == .subscriptionsOnly ? Color.purple : Color.gray.opacity(0.2), lineWidth: importMode == .subscriptionsOnly ? 2 : 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Option 2: Full Import
                Button {
                    importMode = .fullImport
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 50, height: 50)

                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Full Import")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

                            Text("Add all transactions, update balance, and detect subscriptions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Image(systemName: importMode == .fullImport ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(importMode == .fullImport ? .blue : .secondary.opacity(0.5))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: importMode == .fullImport ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(importMode == .fullImport ? Color.blue : Color.gray.opacity(0.2), lineWidth: importMode == .fullImport ? 2 : 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)

            Spacer()

            // Account name (only for full import)
            if importMode == .fullImport {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Name")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Apple Card", text: $accountName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }

            // Continue button
            Button {
                Task { await performImport() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(importMode == .subscriptionsOnly ? "Detect Subscriptions" : "Import & Detect")
                        Image(systemName: "arrow.right")
                    }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(importMode == .subscriptionsOnly ? Color.purple : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading || (importMode == .fullImport && accountName.isEmpty))
            .padding(.horizontal, 24)

            Button {
                step = .selectFiles
            } label: {
                Text("Back")
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 3: Importing

    private var importingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text(importMode == .subscriptionsOnly ? "Analyzing Transactions..." : "Importing & Analyzing...")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

            Text("Detecting subscription patterns")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Step 4: Complete

    private var completeView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }

            Text(importMode == .subscriptionsOnly ? "Analysis Complete!" : "Import Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))

            // Summary
            VStack(spacing: 12) {
                summaryRow(label: "Files analyzed", value: "\(selectedFiles.count)")
                Divider()
                summaryRow(label: "Transactions processed", value: "\(totalTransactionCount)")

                if importMode == .fullImport, let result = importResult, let balance = result.balance {
                    Divider()
                    summaryRow(label: "Account balance", value: formatCurrency(balance))
                }

                Divider()
                summaryRow(label: "Subscriptions found", value: "\(detectedSubscriptions.count)")

                if let result = importResult, result.totalMonthly > 0 {
                    Divider()
                    summaryRow(label: "Monthly total", value: formatCurrency(result.totalMonthly))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            // Detected subscriptions preview
            if !detectedSubscriptions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected Subscriptions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(detectedSubscriptions.prefix(5)) { sub in
                                VStack(spacing: 4) {
                                    Text(sub.merchantName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)

                                    Text(formatCurrency(sub.amount))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    Text(sub.frequency)
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }

            Spacer()

            Button {
                onComplete?()
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.2))
        }
    }

    // MARK: - Actions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent

                    // Count transactions
                    var txnCount = 0
                    if let csvString = String(data: data, encoding: .utf8) {
                        let lines = csvString.components(separatedBy: .newlines)
                            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        txnCount = max(0, lines.count - 1)
                    }

                    // Don't add duplicates
                    if !selectedFiles.contains(where: { $0.name == fileName }) {
                        selectedFiles.append(SelectedFile(name: fileName, data: data, transactionCount: txnCount))
                    }
                } catch {
                    self.error = "Failed to read \(url.lastPathComponent)"
                }
            }

            // Limit to 10 files
            if selectedFiles.count > 10 {
                selectedFiles = Array(selectedFiles.prefix(10))
            }

        case .failure(let error):
            self.error = error.localizedDescription
        }
    }

    private func performImport() async {
        guard !selectedFiles.isEmpty else {
            error = "No files selected"
            return
        }

        isLoading = true
        step = .importing

        do {
            // Prepare files with names
            let fileData = selectedFiles.map { (name: $0.name, data: $0.data) }

            print("[DEBUG] StatementImportView: Preparing to import \(fileData.count) files")
            for (index, file) in fileData.enumerated() {
                print("[DEBUG] StatementImportView: File \(index + 1): \(file.name), size=\(file.data.count) bytes")
            }

            // Call the multi-file import API
            let result = try await apiClient.importMultipleCSV(
                files: fileData,
                mode: importMode == .subscriptionsOnly ? "subscriptions_only" : "full",
                accountName: accountName,
                format: "apple_card"
            )

            await MainActor.run {
                importResult = result
                detectedSubscriptions = result.subscriptions.map { sub in
                    DetectedSubscription(
                        id: sub.id,
                        merchantName: sub.merchantName,
                        amount: sub.amount,
                        frequency: sub.frequency
                    )
                }
                // Mark setup as complete so user won't see onboarding again
                UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
                isLoading = false
                step = .complete
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
                step = .chooseMode
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

#Preview {
    StatementImportView()
        .environmentObject(APIClient.shared)
}
