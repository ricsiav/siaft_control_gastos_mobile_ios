import XCTest
@testable import Siaft

final class FinanceTests: XCTestCase {
    func testAmountsPreserveDecimalPrecision() throws {
        XCTAssertEqual(Finance.amount("123456789012,34"), Decimal(string: "123456789012.34"))
        XCTAssertEqual(Finance.amount("0.10")! + Finance.amount("0.20")!, Finance.amount("0.30"))
        for invalid in ["1.234", "NaN", "1e3", "1,000.00", "", "1234567890123"] { XCTAssertNil(Finance.amount(invalid)) }
    }

    func testCalendarDates() {
        XCTAssertTrue(Finance.validDate("2024-02-29"))
        for invalid in ["2025-02-29", "2026-13-01", "2026-1-01", "2026-04-31"] { XCTAssertFalse(Finance.validDate(invalid)) }
    }

    func testTransferRejectsDifferentCurrencySameWalletAndInactiveWallet() throws {
        let usd = wallet("a", "USD"), other = wallet("b", "USD"), eur = wallet("c", "EUR"), inactive = wallet("d", "USD", active: false)
        var draft = MovementDraft(nature: 3, amount: 10, currency: "USD", effectiveDate: "2026-10-02", originWalletId: "a", destinationWalletId: "b")
        let wallets = [usd, other, eur, inactive]
        XCTAssertNoThrow(try draft.validate(wallets: wallets, categories: []))
        for id in ["a", "c", "d", "missing"] {
            draft.destinationWalletId = id
            XCTAssertThrowsError(try draft.validate(wallets: wallets, categories: []))
        }
    }

    func testExpenseRequiresMatchingActiveCategoryAndCurrency() throws {
        let category = Category(id: "food", name: "Comida", nature: 2, active: true, isGlobal: true)
        var draft = MovementDraft(nature: 2, amount: 10, currency: "USD", effectiveDate: "2026-10-02", originWalletId: "a", categoryId: "food")
        XCTAssertNoThrow(try draft.validate(wallets: [wallet("a", "USD")], categories: [category]))
        draft.nature = 1; draft.destinationWalletId = "a"
        XCTAssertThrowsError(try draft.validate(wallets: [wallet("a", "USD")], categories: [category]))
        draft.nature = 2; draft.currency = "EUR"
        XCTAssertThrowsError(try draft.validate(wallets: [wallet("a", "USD")], categories: [category]))
        draft.currency = "USD"; draft.amount = 0
        XCTAssertThrowsError(try draft.validate(wallets: [wallet("a", "USD")], categories: [category]))
    }

    func testReportRange() throws {
        var filters = ReportFilters()
        filters.from = Date(timeIntervalSince1970: 200_000)
        filters.to = Date(timeIntervalSince1970: 0)
        XCTAssertThrowsError(try filters.validate())
        filters.to = filters.from
        XCTAssertNoThrow(try filters.validate())
    }

    func testDashboardAndProfileContracts() throws {
        let raw = #"{"error":false,"data":{"walletBalances":[{"currency":"USD","currentBalance":12.34}],"currentMonth":[{"currency":"USD","income":20,"expense":7.66,"balance":12.34}],"topExpenseCategories":[],"recentMovements":[{"id":"m","nature":2,"amount":7.66,"currency":"USD","effectiveDate":"2026-10-02","description":null,"wallet":"Efectivo","category":"Comida"}]}}"#
        let dashboard = try XCTUnwrap(JSONDecoder().decode(Envelope<Dashboard>.self, from: Data(raw.utf8)).data)
        XCTAssertEqual(dashboard.walletBalances.first?.currentBalance, Decimal(string: "12.34"))
        XCTAssertEqual(dashboard.recentMovements.first?.wallet, "Efectivo")
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(#"{"name":"Ana","surname":"Prueba","email":"ana@example.test","username":"ana","roles":[{"name":"CONTROL_GASTOS_USER"}]}"#.utf8))
        XCTAssertEqual(profile.roles.first?.name, "CONTROL_GASTOS_USER")
    }

    func testReportContract() throws {
        let raw = #"{"summaries":[],"categories":[{"category":"Comida","currency":"USD","income":0,"expense":12.34,"total":12.34,"percentage":100}],"months":[{"month":"2026-10","currency":"USD","income":0,"expense":12.34,"balance":-12.34}],"registeredMovementCount":1,"transferCount":0}"#
        let report = try JSONDecoder().decode(FinancialReport.self, from: Data(raw.utf8))
        XCTAssertEqual(report.categories.first?.expense, Decimal(string: "12.34"))
        XCTAssertEqual(report.registeredMovementCount, 1)
    }

    func testEncodedMovementUsesNumericMoneyAndNoUserId() throws {
        let draft = MovementDraft(nature: 1, amount: Decimal(string: "12.34")!, currency: "USD", effectiveDate: "2026-10-02", destinationWalletId: "a", categoryId: "income")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any])
        XCTAssertTrue(object["amount"] is NSNumber)
        XCTAssertNil(object["userId"])
        XCTAssertNil(object["originWalletId"])
        XCTAssertEqual(object["effectiveDate"] as? String, "2026-10-02")
    }

    func testClientRejectsInsecureOrCredentialedURLs() {
        for url in ["http://example.test/bff/v1", "https://user:password@example.test/bff/v1"] {
            XCTAssertThrowsError(try BffClient(baseURL: URL(string: url)!))
        }
    }

    private func wallet(_ id: String, _ currency: String, active: Bool = true) -> Wallet {
        Wallet(id: id, name: id, type: 1, currentBalance: 100, currency: currency, active: active)
    }
}
