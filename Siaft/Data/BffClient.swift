import Foundation

struct ApiError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

struct Envelope<T: Decodable>: Decodable {
    let error: Bool?
    let message: String?
    let data: T?
}

private struct ErrorEnvelope: Decodable { let error: Bool?; let message: String? }
// Successful write responses may contain an object, scalar or null data.
struct EmptyResponse: Decodable {
    init() {}
    init(from decoder: Decoder) throws {}
}

final class BffClient: NSObject, URLSessionTaskDelegate {
    private let baseURL: URL
    private let configuration: URLSessionConfiguration
    private lazy var transport: URLSession = {
        let config = configuration
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.httpCookieStorage = nil
        config.urlCache = nil
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    init(baseURL: URL, configuration: URLSessionConfiguration = .ephemeral) throws {
        guard baseURL.scheme == "https", baseURL.host != nil, baseURL.user == nil,
              baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil else {
            throw ValidationError(message: "Configura una URL HTTPS válida para el BFF.")
        }
        self.baseURL = baseURL
        self.configuration = configuration
        super.init()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", token: String? = nil,
                               body: Data? = nil, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ApiError(status: 0, message: "Respuesta no válida.") }
        let problem = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
        guard (200...299).contains(http.statusCode), problem?.error != true else {
            let message = http.statusCode == 401 && token != nil
                ? "Tu sesión ha vencido. Inicia sesión nuevamente."
                : problem?.message ?? "No se pudo completar la solicitud (HTTP \(http.statusCode))."
            throw ApiError(status: http.statusCode, message: message)
        }
        if T.self == EmptyResponse.self {
            if http.statusCode != 204 {
                _ = try JSONDecoder().decode(Envelope<EmptyResponse>.self, from: data)
            }
            return EmptyResponse() as! T
        }
        let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        guard let value = envelope.data else { throw ApiError(status: http.statusCode, message: "El servicio devolvió datos incompletos.") }
        return value
    }
}
