import SwiftUI

struct EntryView: View {
    @EnvironmentObject private var model: SiaftModel
    let kind: EntryKind
    @State private var name = ""
    @State private var nature = 2
    @State private var type = 1
    @State private var amount = ""
    @State private var currency = ""
    @State private var date = Date()
    @State private var origin = ""
    @State private var destination = ""
    @State private var category = ""
    @State private var description = ""

    var body: some View {
        if let data = model.snapshot {
            Form {
                if kind == .movement { movementFields(data) }
                if kind == .wallet {
                    TextField("Nombre", text: $name)
                    Picker("Tipo", selection: $type) { Text("Efectivo").tag(1); Text("Cuenta bancaria").tag(2) }
                    Picker("Moneda", selection: $currency) { Text("Selecciona").tag(""); ForEach(data.currencies, id: \.self) { Text($0).tag($0) } }
                    TextField("Saldo inicial", text: $amount).keyboardType(.decimalPad)
                    Text("El saldo inicial representa el dinero que ya tienes en esta billetera.").font(.caption)
                }
                if kind == .category {
                    TextField("Nombre", text: $name)
                    Picker("Tipo", selection: $nature) { Text("Ingreso").tag(1); Text("Gasto").tag(2) }
                    Text("La categoría será personal. Las compartidas están disponibles en el listado.").font(.caption)
                }
                Button("Guardar") { Task { await submit(data) } }.frame(minHeight: 44)
            }.onAppear {
                if kind == .wallet { amount = "0"; currency = data.currencies.contains("USD") ? "USD" : data.currencies.first ?? "" }
            }
        }
    }

    @ViewBuilder private func movementFields(_ data: Snapshot) -> some View {
        Picker("Tipo", selection: $nature) { Text("Ingreso").tag(1); Text("Gasto").tag(2); Text("Transferencia").tag(3) }
            .onChange(of: nature) { _ in origin = ""; destination = ""; category = "" }
        if nature != 1 {
            Picker("Origen", selection: $origin) {
                Text("Selecciona").tag("")
                ForEach(data.wallets.filter(\.active)) { Text("\($0.name) · \($0.currency)").tag($0.id) }
            }.onChange(of: origin) { _ in destination = "" }
        }
        if nature != 2 {
            Picker("Destino", selection: $destination) {
                Text("Selecciona").tag("")
                ForEach(data.wallets.filter { $0.active && (nature != 3 || ($0.id != origin && $0.currency == data.wallets.first(where: { $0.id == origin })?.currency)) }) {
                    Text("\($0.name) · \($0.currency)").tag($0.id)
                }
            }
        }
        if nature != 3 {
            Picker("Categoría", selection: $category) {
                Text("Selecciona").tag("")
                ForEach(data.categories.filter { $0.active && $0.nature == nature }) { Text($0.name).tag($0.id) }
            }
        }
        let selectedCurrency = data.wallets.first { $0.id == (nature == 1 ? destination : origin) }?.currency ?? ""
        TextField("Importe \(selectedCurrency)", text: $amount).keyboardType(.decimalPad)
        DatePicker("Fecha", selection: $date, displayedComponents: .date)
        TextField("Descripción (opcional)", text: $description, axis: .vertical)
        if !data.wallets.contains(where: \.active) { Text("Crea una billetera activa antes de registrar movimientos.").foregroundStyle(.red) }
    }

    private func submit(_ data: Snapshot) async {
        do {
            if kind == .movement {
                guard let value = Finance.amount(amount) else { throw ValidationError(message: "Ingresa un importe válido con hasta dos decimales.") }
                let selectedCurrency = data.wallets.first { $0.id == (nature == 1 ? destination : origin) }?.currency ?? ""
                let draft = MovementDraft(nature: nature, amount: value, currency: selectedCurrency, effectiveDate: Finance.date(date),
                                          originWalletId: nature == 1 ? nil : origin, destinationWalletId: nature == 2 ? nil : destination,
                                          categoryId: nature == 3 ? nil : category, description: description.trimmed.isEmpty ? nil : description.trimmed)
                try draft.validate(wallets: data.wallets, categories: data.categories)
                await model.mutate { repo, token in try await repo.createMovement(token: token, draft: draft) }
            } else {
                guard !name.trimmed.isEmpty, name.trimmed.count <= 100 else { throw ValidationError(message: "Ingresa un nombre de hasta 100 caracteres.") }
                if kind == .wallet {
                    guard let value = Finance.amount(amount), value >= 0, data.currencies.contains(currency) else {
                        throw ValidationError(message: "Ingresa un saldo no negativo y una moneda válida.")
                    }
                    await model.mutate { repo, token in try await repo.createWallet(token: token, name: name, type: type, balance: value, currency: currency) }
                } else {
                    await model.mutate { repo, token in try await repo.createCategory(token: token, name: name, nature: nature) }
                }
            }
        } catch { model.message = error.localizedDescription }
    }
}
