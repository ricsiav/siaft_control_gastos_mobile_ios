import XCTest
@testable import Siaft

private final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, body) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class BffClientTests: XCTestCase {
    override func tearDown() { StubProtocol.handler = nil; super.tearDown() }

    private func client() throws -> BffClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return try BffClient(baseURL: URL(string: "https://example.test/bff/v1")!, configuration: configuration)
    }

    func testProtectedRequestPreservesBffPrefixAndEncodesQuery() async throws {
        StubProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/bff/v1/reports/financial-summary")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "a & b")
            return (200, #"{"error":false,"data":{"summaries":[],"categories":[],"months":[],"registeredMovementCount":0,"transferCount":0}}"#)
        }
        let report: FinancialReport = try await client().request("reports/financial-summary", token: "test-token", query: [URLQueryItem(name: "walletId", value: "a & b")])
        XCTAssertEqual(report.registeredMovementCount, 0)
    }

    func testProtected401PropagatesSessionExpiry() async throws {
        StubProtocol.handler = { _ in (401, #"{"error":true,"message":"Unauthorized","data":null}"#) }
        do {
            let _: Dashboard = try await client().request("dashboard", token: "test-token")
            XCTFail("Expected 401")
        } catch let error as ApiError {
            XCTAssertEqual(error.status, 401)
            XCTAssertTrue(error.message.contains("sesión"))
        }
    }

    func testPatchAndNoContentResponse() async throws {
        StubProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/bff/v1/users/me/password")
            return (204, "")
        }
        let _: EmptyResponse = try await client().request("users/me/password", method: "PATCH", token: "test-token", body: Data("{}".utf8))
    }

    func testWritesAcceptScalarResponseAndDoNotRetryErrors() async throws {
        StubProtocol.handler = { _ in (200, #"{"error":false,"data":"created"}"#) }
        let _: EmptyResponse = try await client().request("auth/register", method: "POST", body: Data("{}".utf8))
        var count = 0
        StubProtocol.handler = { _ in count += 1; return (500, #"{"error":true,"message":"Failed","data":null}"#) }
        do {
            let _: EmptyResponse = try await client().request("movements", method: "POST", token: "test-token", body: Data("{}".utf8))
            XCTFail("Expected failure")
        } catch { XCTAssertEqual(count, 1) }
    }
}
