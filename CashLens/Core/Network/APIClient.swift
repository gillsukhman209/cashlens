import Foundation
import Combine

class APIClient: ObservableObject {
    static let shared = APIClient()

    private let baseURL = "https://cashlens-backend.vercel.app/api"

    // Store user ID (in production, use Keychain)
    @Published var userId: String? {
        didSet {
            if let userId = userId {
                UserDefaults.standard.set(userId, forKey: "userId")
            }
        }
    }

    init() {
        self.userId = UserDefaults.standard.string(forKey: "userId")
    }

    // MARK: - User

    func createUser(email: String, name: String) async throws -> User {
        let url = URL(string: "\(baseURL)/user")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "name": name]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(UserResponse.self, from: data)

        self.userId = response.user.id
        return response.user
    }

    func getUser() async throws -> User? {
        guard let userId = userId else { return nil }

        let url = URL(string: "\(baseURL)/user?userId=\(userId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(UserResponse.self, from: data)
        return response.user
    }

    // MARK: - Plaid

    func createLinkToken() async throws -> String {
        guard let userId = userId else {
            throw APIError.noUser
        }

        let url = URL(string: "\(baseURL)/plaid/create-link-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["userId": userId]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(LinkTokenResponse.self, from: data)
        return response.linkToken
    }

    func exchangeToken(publicToken: String, institutionId: String?, institutionName: String?) async throws -> ExchangeTokenResponse {
        guard let userId = userId else {
            throw APIError.noUser
        }

        let url = URL(string: "\(baseURL)/plaid/exchange-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "publicToken": publicToken,
            "userId": userId
        ]
        if let institutionId = institutionId {
            body["institutionId"] = institutionId
        }
        if let institutionName = institutionName {
            body["institutionName"] = institutionName
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ExchangeTokenResponse.self, from: data)
    }

    func syncTransactions() async throws -> SyncResponse {
        guard let userId = userId else {
            throw APIError.noUser
        }

        let url = URL(string: "\(baseURL)/plaid/sync-transactions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["userId": userId]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SyncResponse.self, from: data)
    }

    // MARK: - Accounts

    func getAccounts() async throws -> AccountsResponse {
        guard let userId = userId else {
            throw APIError.noUser
        }

        let url = URL(string: "\(baseURL)/accounts?userId=\(userId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(AccountsResponse.self, from: data)
    }

    func toggleAccountVisibility(accountId: String, isHidden: Bool) async throws {
        guard let userId = userId else {
            throw APIError.noUser
        }

        let url = URL(string: "\(baseURL)/accounts")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userId": userId,
            "accountId": accountId,
            "isHidden": isHidden
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw APIError.networkError(errorMessage)
            }
            throw APIError.networkError("Failed to update account visibility")
        }
    }

    // MARK: - Transactions

    func getTransactions(startDate: Date? = nil, endDate: Date? = nil, limit: Int = 50, offset: Int = 0) async throws -> TransactionsResponse {
        guard let userId = userId else {
            print("[DEBUG] APIClient.getTransactions: No userId!")
            throw APIError.noUser
        }

        var components = URLComponents(string: "\(baseURL)/transactions")!
        var queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "startDate", value: dateFormatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "endDate", value: dateFormatter.string(from: endDate)))
        }

        components.queryItems = queryItems

        print("[DEBUG] APIClient.getTransactions: Fetching from \(components.url!.absoluteString)")

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        // Debug: Print raw response
        if let httpResponse = response as? HTTPURLResponse {
            print("[DEBUG] APIClient.getTransactions: HTTP Status = \(httpResponse.statusCode)")
        }
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[DEBUG] APIClient.getTransactions: Response (first 500 chars) = \(String(jsonString.prefix(500)))")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let result = try decoder.decode(TransactionsResponse.self, from: data)
            print("[DEBUG] APIClient.getTransactions: Decoded \(result.transactions.count) transactions successfully")
            return result
        } catch {
            print("[DEBUG] APIClient.getTransactions: Decode error = \(error)")
            throw error
        }
    }

    // MARK: - Institutions

    func getInstitutions() async throws -> InstitutionsResponse {
        guard let userId = userId else {
            throw APIError.noUser
        }

        let url = URL(string: "\(baseURL)/institutions?userId=\(userId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(InstitutionsResponse.self, from: data)
    }

    func deleteInstitution(itemId: String) async throws {
        guard let userId = userId else {
            throw APIError.noUser
        }

        let url = URL(string: "\(baseURL)/institutions?userId=\(userId)&itemId=\(itemId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw APIError.networkError(errorMessage)
            }
            throw APIError.networkError("Failed to remove bank connection")
        }
    }

    // MARK: - Subscriptions

    func getSubscriptions(months: Int = 3) async throws -> SubscriptionsResponse {
        guard let userId = userId else {
            throw APIError.noUser
        }

        let url = URL(string: "\(baseURL)/subscriptions?userId=\(userId)&months=\(months)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SubscriptionsResponse.self, from: data)
    }

    // MARK: - Manual Import

    func createManualAccount(name: String, type: String, subtype: String?, institutionName: String) async throws -> CreateManualAccountResponse {
        guard let userId = userId else {
            print("[DEBUG] createManualAccount: No userId!")
            throw APIError.noUser
        }

        print("[DEBUG] createManualAccount: Creating account with userId=\(userId), name=\(name), type=\(type)")

        let url = URL(string: "\(baseURL)/accounts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "userId": userId,
            "name": name,
            "type": type,
            "institutionName": institutionName
        ]
        if let subtype = subtype {
            body["subtype"] = subtype
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("[DEBUG] createManualAccount: HTTP Status = \(httpResponse.statusCode)")
        }
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[DEBUG] createManualAccount: Response = \(jsonString)")
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw APIError.networkError(errorMessage)
            }
            throw APIError.networkError("Failed to create manual account")
        }

        let result = try JSONDecoder().decode(CreateManualAccountResponse.self, from: data)
        print("[DEBUG] createManualAccount: Success! accountId=\(result.accountId), plaidItemId=\(result.plaidItemId)")
        return result
    }

    func importCSV(fileData: Data, accountId: String, format: String) async throws -> ImportResponse {
        guard let userId = userId else {
            print("[DEBUG] importCSV: No userId!")
            throw APIError.noUser
        }

        print("[DEBUG] importCSV: Starting import with userId=\(userId), accountId=\(accountId), format=\(format)")
        print("[DEBUG] importCSV: File size = \(fileData.count) bytes")

        let url = URL(string: "\(baseURL)/import")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add userId
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)

        // Add accountId
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"accountId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(accountId)\r\n".data(using: .utf8)!)

        // Add format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"format\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(format)\r\n".data(using: .utf8)!)

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"transactions.csv\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("[DEBUG] importCSV: HTTP Status = \(httpResponse.statusCode)")
        }
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[DEBUG] importCSV: Response = \(jsonString)")
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw APIError.networkError(errorMessage)
            }
            throw APIError.networkError("Failed to import CSV")
        }

        let result = try JSONDecoder().decode(ImportResponse.self, from: data)
        print("[DEBUG] importCSV: Success! Imported \(result.imported) transactions, balance = \(result.balance)")
        return result
    }

    func importMultipleCSV(files: [(name: String, data: Data)], mode: String, accountName: String, format: String) async throws -> MultiFileImportResponse {
        guard let userId = userId else {
            print("[DEBUG] importMultipleCSV: No userId!")
            throw APIError.noUser
        }

        print("[DEBUG] importMultipleCSV: Starting import with userId=\(userId), mode=\(mode), files=\(files.count)")

        let url = URL(string: "\(baseURL)/import/multi")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add userId
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)

        // Add mode
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"mode\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(mode)\r\n".data(using: .utf8)!)

        // Add accountName
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"accountName\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(accountName)\r\n".data(using: .utf8)!)

        // Add format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"format\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(format)\r\n".data(using: .utf8)!)

        // Add each file
        for (index, file) in files.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(file.name)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
            print("[DEBUG] importMultipleCSV: Added file \(index + 1): \(file.name) (\(file.data.count) bytes)")
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        print("[DEBUG] importMultipleCSV: Total body size = \(body.count) bytes")
        print("[DEBUG] importMultipleCSV: Files array count = \(files.count)")

        // Debug: print first 500 chars of body as string
        if let bodyString = String(data: body.prefix(500), encoding: .utf8) {
            print("[DEBUG] importMultipleCSV: Body start = \(bodyString)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("[DEBUG] importMultipleCSV: HTTP Status = \(httpResponse.statusCode)")
        }
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[DEBUG] importMultipleCSV: Response = \(String(jsonString.prefix(1000)))")
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw APIError.networkError(errorMessage)
            }
            throw APIError.networkError("Failed to import CSV files")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(MultiFileImportResponse.self, from: data)
        print("[DEBUG] importMultipleCSV: Success! Mode=\(result.mode), Transactions=\(result.totalTransactions), Subscriptions=\(result.subscriptionsDetected)")
        return result
    }
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case noUser
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noUser:
            return "No user logged in"
        case .networkError(let message):
            return message
        }
    }
}
