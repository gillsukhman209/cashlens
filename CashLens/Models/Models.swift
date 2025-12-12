import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let image: String?
    let provider: String?
    let createdAt: String?
    let settings: UserSettings?
}

struct UserSettings: Codable {
    let currency: String
    let notifications: Bool
}

struct UserResponse: Codable {
    let user: User
    let message: String?
}

// MARK: - Plaid Responses

struct LinkTokenResponse: Codable {
    let linkToken: String
    let expiration: String?
}

struct ExchangeTokenResponse: Codable {
    let success: Bool
    let itemId: String
    let plaidItemId: String
    let accounts: [AccountBasic]
    let institution: InstitutionBasic?
}

struct AccountBasic: Codable {
    let id: String
    let name: String
    let type: String
    let subtype: String?
    let mask: String?
    let currentBalance: Double?
    let availableBalance: Double?
}

struct InstitutionBasic: Codable {
    let id: String?
    let name: String?
    let logo: String?
    let color: String?
}

struct SyncResponse: Codable {
    let success: Bool
    let added: Int
    let modified: Int
    let removed: Int
    let accounts: [SyncAccount]?
}

struct SyncAccount: Codable {
    let accountId: String
    let name: String
    let currentBalance: Double?
    let availableBalance: Double?
}

// MARK: - Account

struct Account: Codable, Identifiable {
    let id: String
    let accountId: String
    let name: String
    let officialName: String?
    let type: String
    let subtype: String?
    let mask: String?
    let currentBalance: Double
    let availableBalance: Double?
    let creditLimit: Double?
    let isoCurrencyCode: String
    let institution: Institution?
    let lastUpdatedAt: String?

    var displayBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = isoCurrencyCode
        return formatter.string(from: NSNumber(value: currentBalance)) ?? "$\(currentBalance)"
    }

    var typeIcon: String {
        switch type {
        case "depository":
            switch subtype {
            case "checking": return "dollarsign.circle.fill"
            case "savings": return "banknote.fill"
            default: return "building.columns.fill"
            }
        case "credit": return "creditcard.fill"
        case "loan": return "doc.text.fill"
        case "investment": return "chart.line.uptrend.xyaxis"
        default: return "building.columns.fill"
        }
    }
}

struct Institution: Codable {
    let name: String
    let logo: String?
    let color: String?
}

struct AccountsResponse: Codable {
    let accounts: [Account]
    let totals: AccountTotals
    let netWorth: Double
}

struct AccountTotals: Codable {
    let checking: Double
    let savings: Double
    let credit: Double
    let investment: Double
    let other: Double
}

// MARK: - Transaction

struct Transaction: Codable, Identifiable {
    let id: String
    let plaidTransactionId: String?
    let amount: Double
    let isoCurrencyCode: String
    let date: Date
    let name: String
    let merchantName: String?
    let category: String?
    let detailedCategory: String?
    let pending: Bool
    let paymentChannel: String?
    let logoUrl: String?
    let location: TransactionLocation?
    let userNote: String?
    let userCategory: String?
    let account: TransactionAccount?

    var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = isoCurrencyCode
        let value = amount
        return formatter.string(from: NSNumber(value: abs(value))) ?? "$\(abs(value))"
    }

    var isIncome: Bool {
        return amount < 0 // Negative amounts are income in Plaid
    }

    var displayName: String {
        return merchantName ?? name
    }

    var categoryIcon: String {
        guard let category = category?.lowercased() else { return "questionmark.circle" }

        if category.contains("food") || category.contains("restaurant") {
            return "fork.knife"
        } else if category.contains("transport") || category.contains("travel") {
            return "car.fill"
        } else if category.contains("shop") || category.contains("store") {
            return "bag.fill"
        } else if category.contains("entertainment") {
            return "film.fill"
        } else if category.contains("health") || category.contains("medical") {
            return "heart.fill"
        } else if category.contains("income") || category.contains("payment") {
            return "arrow.down.circle.fill"
        } else if category.contains("transfer") {
            return "arrow.left.arrow.right"
        } else if category.contains("bill") || category.contains("utility") {
            return "doc.text.fill"
        } else {
            return "creditcard"
        }
    }
}

struct TransactionLocation: Codable {
    let address: String?
    let city: String?
    let region: String?
    let postalCode: String?
    let country: String?
    let lat: Double?
    let lon: Double?
}

struct TransactionAccount: Codable {
    let name: String
    let mask: String?
    let type: String
    let subtype: String?
}

struct TransactionsResponse: Codable {
    let transactions: [Transaction]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

// MARK: - Institution (for linked banks list)

struct LinkedInstitution: Codable, Identifiable {
    let id: String
    let itemId: String
    let institutionId: String?
    let name: String
    let logo: String?
    let color: String?
    let status: String
    let accountCount: Int
    let lastSyncedAt: String?
    let createdAt: String?
    let accounts: [InstitutionAccount]?

    // Summary of account types for display
    var accountSummary: String {
        guard let accounts = accounts, !accounts.isEmpty else {
            return "\(accountCount) account\(accountCount == 1 ? "" : "s")"
        }

        let checking = accounts.filter { $0.subtype == "checking" }.count
        let savings = accounts.filter { $0.subtype == "savings" }.count
        let credit = accounts.filter { $0.type == "credit" }.count

        var parts: [String] = []
        if checking > 0 { parts.append("\(checking) checking") }
        if savings > 0 { parts.append("\(savings) savings") }
        if credit > 0 { parts.append("\(credit) credit") }

        if parts.isEmpty {
            return "\(accountCount) account\(accountCount == 1 ? "" : "s")"
        }
        return parts.joined(separator: ", ")
    }
}

struct InstitutionAccount: Codable, Identifiable {
    let id: String
    let accountId: String
    let name: String
    let officialName: String?
    let type: String
    let subtype: String?
    let mask: String?
    let currentBalance: Double
    let isHidden: Bool

    var displayName: String {
        if let mask = mask {
            return "\(name) ••••\(mask)"
        }
        return name
    }

    var typeLabel: String {
        if let subtype = subtype {
            return subtype.capitalized
        }
        return type.capitalized
    }

    var typeIcon: String {
        switch type {
        case "depository":
            switch subtype {
            case "checking": return "dollarsign.circle.fill"
            case "savings": return "banknote.fill"
            default: return "building.columns.fill"
            }
        case "credit": return "creditcard.fill"
        case "loan": return "doc.text.fill"
        case "investment": return "chart.line.uptrend.xyaxis"
        default: return "building.columns.fill"
        }
    }

    var displayBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: currentBalance)) ?? "$\(currentBalance)"
    }
}

struct InstitutionsResponse: Codable {
    let institutions: [LinkedInstitution]
}

// MARK: - Subscription

struct Subscription: Codable, Identifiable {
    let id: String
    let merchantName: String
    let amount: Double
    let frequency: String
    let category: String?
    let lastCharge: Date
    let nextExpected: Date?
    let accountName: String?
    let accountMask: String?
    let logoUrl: String?
    let transactionCount: Int
    let confidence: Double
    let transactions: [SubscriptionTransaction]?

    var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    var frequencyLabel: String {
        switch frequency {
        case "weekly": return "Weekly"
        case "bi-weekly": return "Bi-weekly"
        case "monthly": return "Monthly"
        case "quarterly": return "Quarterly"
        case "yearly": return "Yearly"
        default: return frequency.capitalized
        }
    }

    var categoryIcon: String {
        guard let category = category?.lowercased() else { return "repeat.circle" }

        if category.contains("entertainment") || category.contains("streaming") {
            return "play.tv.fill"
        } else if category.contains("software") || category.contains("technology") {
            return "laptopcomputer"
        } else if category.contains("food") || category.contains("restaurant") {
            return "fork.knife"
        } else if category.contains("health") || category.contains("fitness") {
            return "heart.fill"
        } else if category.contains("music") {
            return "music.note"
        } else if category.contains("news") || category.contains("media") {
            return "newspaper.fill"
        } else if category.contains("utility") || category.contains("bill") {
            return "bolt.fill"
        } else if category.contains("insurance") {
            return "shield.fill"
        } else if category.contains("membership") || category.contains("subscription") {
            return "person.2.fill"
        } else {
            return "repeat.circle"
        }
    }

    // Calculate monthly equivalent based on frequency
    var monthlyEquivalent: Double {
        switch frequency {
        case "weekly":
            return amount * 4.33
        case "bi-weekly":
            return amount * 2.17
        case "monthly":
            return amount
        case "quarterly":
            return amount / 3
        case "yearly":
            return amount / 12
        default:
            return amount
        }
    }

    var displayMonthlyEquivalent: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: monthlyEquivalent)) ?? "$\(monthlyEquivalent)"
    }
}

struct SubscriptionsResponse: Codable {
    let subscriptions: [Subscription]
    let totalMonthly: Double
    let count: Int
}

struct SubscriptionTransaction: Codable, Identifiable {
    let id: String
    let amount: Double
    let date: Date
    let accountName: String?
    let accountMask: String?
}

// MARK: - Manual Import

struct CreateManualAccountResponse: Codable {
    let success: Bool
    let accountId: String
    let plaidItemId: String
}

struct ImportResponse: Codable {
    let success: Bool
    let imported: Int
    let balance: Double
}

// MARK: - Multi-File Import

struct MultiFileImportResponse: Codable {
    let success: Bool
    let mode: String
    let filesProcessed: Int
    let totalTransactions: Int
    let subscriptionsDetected: Int
    let subscriptions: [Subscription]
    let totalMonthly: Double
    let accountId: String?
    let balance: Double?
}
