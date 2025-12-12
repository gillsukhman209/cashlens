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

        let (data, _) = try await URLSession.shared.data(from: components.url!)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TransactionsResponse.self, from: data)
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
