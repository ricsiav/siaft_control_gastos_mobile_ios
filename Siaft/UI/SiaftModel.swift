import SwiftUI

enum EntryKind: String, Identifiable {
    case movement = "Nuevo movimiento", wallet = "Nueva billetera", category = "Nueva categoría", profile = "Mi perfil"
    var id: String { rawValue }
}

@MainActor
final class SiaftModel: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var report: FinancialReport?
    @Published private(set) var profile: UserProfile?
    @Published private(set) var busy = false
    @Published var message: String?
    @Published var sheet: EntryKind?
    @Published var tab = 0
    @Published var reportFilters = ReportFilters()
    private let store: SessionStore
    private var repository: SiaftRepository?

    init(store: SessionStore = SessionStore()) {
        self.store = store
        do {
            guard let raw = Bundle.main.object(forInfoDictionaryKey: "SiaftBffBaseURL") as? String,
                  let url = URL(string: raw) else { throw ValidationError(message: "Falta configurar SiaftBffBaseURL.") }
            repository = SiaftRepository(client: try BffClient(baseURL: url))
            session = try store.load()
        } catch { message = error.localizedDescription }
    }

    @discardableResult
    func perform(_ action: (SiaftRepository) async throws -> Void) async -> Bool {
        guard !busy else { return false }
        guard let repository else { message = "Revisa la configuración del BFF en Info.plist."; return false }
        busy = true
        defer { busy = false }
        do { try await action(repository); return true }
        catch {
            if let api = error as? ApiError, api.status == 401, session != nil {
                clearVisibleData()
                do { try store.clear() } catch { message = error.localizedDescription; return false }
            }
            if error is URLError {
                message = "No se pudo conectar. Revisa tu conexión. Si estabas guardando, actualiza el listado antes de repetir la operación."
            } else { message = error.localizedDescription }
            return false
        }
    }

    func login(username: String, password: String) async {
        guard !username.trimmed.isEmpty, !password.isEmpty else { message = "Ingresa tu usuario y contraseña."; return }
        await perform { repo in
            let result = try await repo.login(username: username, password: password)
            try store.save(result)
            session = result
            tab = 0
            snapshot = try await repo.load(token: result.token)
        }
    }

    func refresh() async {
        guard let token = session?.token else { return }
        await perform { repo in snapshot = try await repo.load(token: token) }
    }

    func loadReport() async {
        guard let token = session?.token else { return }
        await perform { repo in
            report = nil
            try reportFilters.validate()
            report = try await repo.report(token: token, filters: reportFilters)
        }
    }

    func loadProfile() async {
        guard let token = session?.token else { return }
        await perform { repo in profile = try await repo.profile(token: token) }
    }

    func updateProfile(name: String, surname: String, email: String) async {
        guard !name.trimmed.isEmpty, !surname.trimmed.isEmpty,
              email.trimmed.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else {
            message = "Completa nombres, apellidos y un correo válido."; return
        }
        guard let token = session?.token else { return }
        await perform { repo in
            let updated = try await repo.updateProfile(token: token, name: name, surname: surname, email: email)
            profile = updated
            let updatedSession = Session(token: token, user: updated.username, name: updated.name, surname: updated.surname, roles: updated.roles.map(\.name))
            session = updatedSession
            try store.save(updatedSession)
            message = "Perfil actualizado."
        }
    }

    func mutate(_ action: (SiaftRepository, String) async throws -> Void) async {
        guard let token = session?.token else { return }
        await perform { repo in
            try await action(repo, token)
            sheet = nil
            snapshot = nil
            report = nil
            message = "Operación guardada."
            do { snapshot = try await repo.load(token: token) }
            catch {
                if let api = error as? ApiError, api.status == 401 { throw error }
                message = "La operación se guardó, pero no se pudo actualizar la información. Pulsa Actualizar."
            }
        }
    }

    func logout() {
        guard !busy else { return }
        do { try store.clear(); clearVisibleData() }
        catch { message = error.localizedDescription }
    }

    private func clearVisibleData() {
        session = nil; snapshot = nil; report = nil; profile = nil
        sheet = nil; tab = 0; reportFilters = ReportFilters()
    }
}
