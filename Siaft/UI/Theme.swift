import SwiftUI

enum SiaftTheme {
    static let primary = Color(light: 0x185B55, dark: 0x9FC879)
    static let background = Color(light: 0xF7FAF8, dark: 0x102526)
    static let surface = Color(light: 0xFFFFFF, dark: 0x193536)
    static let ink = Color(light: 0x183033, dark: 0xEFF5F2)
    static let border = Color(light: 0xDFE8E4, dark: 0x385252)
    static let login = Color(hex: 0x0B3335)
    static let accent = Color(hex: 0x9FC879)
    static func movement(_ nature: Int) -> Color {
        switch nature { case 1: return primary; case 2: return Color(light: 0xB33C3C, dark: 0xFF9999); default: return Color(light: 0x3A67A0, dark: 0x9ABEFF) }
    }
}

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

struct SiaftCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.custom("DMSans-Bold", size: 20, relativeTo: .headline))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(SiaftTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(SiaftTheme.border, lineWidth: 1))
    }
}

struct AmountRow: View {
    let title: String
    let amount: Decimal
    let currency: String
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { Text(title); Spacer(); Text(Finance.money(amount, currency)).bold().monospacedDigit() }
            VStack(alignment: .leading) { Text(title); Text(Finance.money(amount, currency)).bold().monospacedDigit() }
        }
    }
}

struct SummaryRows: View {
    let summary: Summary
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.currency).bold()
            AmountRow(title: "Ingresos", amount: summary.income, currency: summary.currency)
            AmountRow(title: "Gastos", amount: summary.expense, currency: summary.currency)
            AmountRow(title: "Balance", amount: summary.balance, currency: summary.currency)
        }
    }
}

struct MessageAlert: ViewModifier {
    @ObservedObject var model: SiaftModel
    func body(content: Content) -> some View {
        content.alert("SIAFT", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("Aceptar", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
}
