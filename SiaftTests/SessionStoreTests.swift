import XCTest
@testable import Siaft

final class SessionStoreTests: XCTestCase {
    func testIsolatedSessionRoundTripAndDeletion() throws {
        let store = SessionStore(service: "net.siaft.tests.\(UUID().uuidString)")
        defer { try? store.clear() }
        XCTAssertNil(try store.load())
        let session = Session(token: "fake-token", user: "test", name: "Ana", surname: "Prueba", roles: ["CONTROL_GASTOS_USER"])
        try store.save(session)
        XCTAssertEqual(try store.load()?.token, "fake-token")
        try store.save(Session(token: "rotated-fake-token", user: "test", name: "Ana", surname: "Prueba", roles: []))
        XCTAssertEqual(try store.load()?.token, "rotated-fake-token")
        try store.clear()
        XCTAssertNil(try store.load())
    }
}
