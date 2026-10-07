import Foundation

struct Session: Codable {
    let token: String
    let user: String
    let name: String
    let surname: String
    let roles: [String]
}

struct Wallet: Codable, Identifiable {
    let id: String
    let name: String
    let type: Int
    let currentBalance: Decimal
    let currency: String
    let active: Bool
}

struct Category: Codable, Identifiable {
    let id: String
    let name: String
    let nature: Int
    let active: Bool
    let isGlobal: Bool
}

struct Movement: Codable, Identifiable {
    let id: String
    let nature: Int
    let amount: Decimal
    let currency: String
    let effectiveDate: String
    let status: Int
    let originWalletId: String?
    let destinationWalletId: String?
    let categoryId: String?
    let description: String?
}

struct Balance: Codable {
    let currency: String
    let currentBalance: Decimal
}

struct Summary: Codable {
    let currency: String
    let income: Decimal
    let expense: Decimal
    let balance: Decimal
}

struct ExpenseCategory: Codable {
    let categoryId: String
    let category: String
    let currency: String
    let expense: Decimal
    let percentage: Decimal
}

struct RecentMovement: Codable, Identifiable {
    let id: String
    let nature: Int
    let amount: Decimal
    let currency: String
    let effectiveDate: String
    let description: String?
    let wallet: String
    let category: String?
}

struct Dashboard: Codable {
    let walletBalances: [Balance]
    let currentMonth: [Summary]
    let topExpenseCategories: [ExpenseCategory]
    let recentMovements: [RecentMovement]
}

struct ReportCategory: Codable {
    let category: String
    let currency: String
    let income: Decimal
    let expense: Decimal
    let total: Decimal
    let percentage: Decimal
}

struct MonthlySummary: Codable {
    let month: String
    let currency: String
    let income: Decimal
    let expense: Decimal
    let balance: Decimal
}

struct FinancialReport: Codable {
    let summaries: [Summary]
    let categories: [ReportCategory]
    let months: [MonthlySummary]
    let registeredMovementCount: Int
    let transferCount: Int
}

struct UserProfile: Codable {
    struct Role: Codable { let name: String }
    let name: String
    let surname: String
    let email: String
    let username: String
    let roles: [Role]
}

struct Snapshot {
    let dashboard: Dashboard
    let wallets: [Wallet]
    let categories: [Category]
    let movements: [Movement]
    let currencies: [String]
}

struct ValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum Finance {
    static func amount(_ text: String) -> Decimal? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard value.range(of: #"^-?[0-9]{1,12}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func validDate(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }

    static func money(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_EC")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(currency) \(formatter.string(from: amount as NSDecimalNumber) ?? amount.description)"
    }

    static func nature(_ value: Int) -> String {
        switch value { case 1: return "Ingreso"; case 2: return "Gasto"; default: return "Transferencia" }
    }
}

struct MovementDraft: Encodable {
    var nature = 2
    var amount: Decimal
    var currency: String
    var effectiveDate: String
    var originWalletId: String?
    var destinationWalletId: String?
    var categoryId: String?
    var description: String?

    func validate(wallets: [Wallet], categories: [Category]) throws {
        guard (1...3).contains(nature), amount > 0, Finance.amount(amount.description) != nil else {
            throw ValidationError(message: "Ingresa un importe positivo con hasta dos decimales.")
        }
        guard Finance.validDate(effectiveDate) else { throw ValidationError(message: "Selecciona una fecha válida.") }
        let source = wallets.first { $0.id == originWalletId && $0.active }
        let target = wallets.first { $0.id == destinationWalletId && $0.active }
        if nature != 1 && source == nil { throw ValidationError(message: "Selecciona una billetera de origen activa.") }
        if nature != 2 && target == nil { throw ValidationError(message: "Selecciona una billetera de destino activa.") }
        if nature == 3 && (source?.id == target?.id || source?.currency != target?.currency) {
            throw ValidationError(message: "Selecciona dos billeteras distintas de la misma moneda.")
        }
        guard currency == (nature == 1 ? target?.currency : source?.currency) else {
            throw ValidationError(message: "La moneda debe coincidir con la billetera.")
        }
        if nature != 3 && !categories.contains(where: { $0.id == categoryId && $0.active && $0.nature == nature }) {
            throw ValidationError(message: "Selecciona una categoría activa del tipo indicado.")
        }
    }
}

struct ReportFilters {
    var from = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    var to = Date()
    var walletId = ""
    func validate() throws {
        guard Finance.date(from) <= Finance.date(to) else {
            throw ValidationError(message: "La fecha inicial debe ser anterior a la final.")
        }
    }
}
