import Foundation

@MainActor
final class SiaftRepository {
    private let client: BffClient
    private var currencies: [String]?
    init(client: BffClient) { self.client = client }

    func login(username: String, password: String) async throws -> Session {
        let body = try JSONEncoder().encode(["username": username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), "password": password])
        let session: Session = try await client.request("auth/login", method: "POST", body: body)
        guard !session.token.isEmpty, !session.user.isEmpty else { throw ValidationError(message: "Respuesta de autenticación incompleta.") }
        return session
    }

    func register(name: String, surname: String, email: String, username: String, password: String, confirmation: String) async throws {
        struct Registration: Encodable {
            let name: String; let surname: String; let email: String; let username: String
            let password: String; let confirmPassword: String
            let role = ["CONTROL_GASTOS_USER"]
        }
        let draft = Registration(name: name.trimmed, surname: surname.trimmed, email: email.trimmed.lowercased(),
                                 username: username.trimmed.lowercased(), password: password, confirmPassword: confirmation)
        let _: EmptyResponse = try await client.request("auth/register", method: "POST", body: JSONEncoder().encode(draft))
    }

    func load(token: String) async throws -> Snapshot {
        let dashboard: Dashboard = try await client.request("dashboard", token: token)
        let wallets: [Wallet] = try await client.request("wallets", token: token)
        let categories: [Category] = try await client.request("categories", token: token)
        let movements: [Movement] = try await client.request("movements", token: token)
        if currencies == nil {
            struct Currency: Decodable { let code: String }
            let catalog: [Currency] = try await client.request("wallets/currencies", token: token)
            currencies = catalog.map(\.code)
        }
        return Snapshot(dashboard: dashboard, wallets: wallets, categories: categories,
                        movements: movements.sorted { $0.effectiveDate > $1.effectiveDate }, currencies: currencies ?? [])
    }

    func report(token: String, filters: ReportFilters) async throws -> FinancialReport {
        try filters.validate()
        var query = [URLQueryItem(name: "from", value: Finance.date(filters.from)), URLQueryItem(name: "to", value: Finance.date(filters.to))]
        if !filters.walletId.isEmpty { query.append(URLQueryItem(name: "walletId", value: filters.walletId)) }
        return try await client.request("reports/financial-summary", token: token, query: query)
    }

    func profile(token: String) async throws -> UserProfile { try await client.request("users/me", token: token) }
    func updateProfile(token: String, name: String, surname: String, email: String) async throws -> UserProfile {
        try await client.request("users/me", method: "PATCH", token: token,
                                 body: JSONEncoder().encode(["name": name.trimmed, "surname": surname.trimmed, "email": email.trimmed.lowercased()]))
    }
    func changePassword(token: String, current: String, new: String, confirmation: String) async throws {
        let _: EmptyResponse = try await client.request("users/me/password", method: "PATCH", token: token,
            body: JSONEncoder().encode(["currentPassword": current, "newPassword": new, "confirmPassword": confirmation]))
    }
    func createWallet(token: String, name: String, type: Int, balance: Decimal, currency: String) async throws {
        struct Draft: Encodable { let name: String; let type: Int; let initialBalance: Decimal; let currency: String }
        let _: EmptyResponse = try await client.request("wallets", method: "POST", token: token,
            body: JSONEncoder().encode(Draft(name: name.trimmed, type: type, initialBalance: balance, currency: currency)))
    }
    func createCategory(token: String, name: String, nature: Int) async throws {
        struct Draft: Encodable { let name: String; let nature: Int }
        let _: EmptyResponse = try await client.request("categories", method: "POST", token: token,
            body: JSONEncoder().encode(Draft(name: name.trimmed, nature: nature)))
    }
    func createMovement(token: String, draft: MovementDraft) async throws {
        let _: EmptyResponse = try await client.request("movements", method: "POST", token: token, body: JSONEncoder().encode(draft))
    }
    func cancelMovement(token: String, id: String) async throws {
        let _: EmptyResponse = try await client.request("movements/\(id)", method: "DELETE", token: token)
    }
}

extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
