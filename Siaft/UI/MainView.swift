import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: SiaftModel
    @State private var confirmLogout = false
    var body: some View {
        NavigationStack {
            TabView(selection: $model.tab) {
                HomeView().tabItem { Label("Inicio", systemImage: "house") }.tag(0)
                MovementsView().tabItem { Label("Movimientos", systemImage: "arrow.left.arrow.right") }.tag(1)
                WalletsView().tabItem { Label("Billeteras", systemImage: "wallet.pass") }.tag(2)
                CategoriesView().tabItem { Label("Categorías", systemImage: "tag") }.tag(3)
                ReportsView().tabItem { Label("Reportes", systemImage: "chart.bar") }.tag(4)
            }
            .navigationTitle(["Inicio", "Movimientos", "Billeteras", "Categorías", "Reportes"][model.tab])
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Text(model.session?.name ?? "SIAFT")
                        Button("Mi perfil", systemImage: "person") { model.sheet = .profile }
                        Button("Actualizar", systemImage: "arrow.clockwise") { Task { if model.tab == 4 { await model.loadReport() } else { await model.refresh() } } }
                        Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { confirmLogout = true }
                    } label: { Image(systemName: "person.crop.circle").font(.title2).frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Menú de perfil")
                }
            }
            .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) { model.logout() }
            }
        }.foregroundStyle(SiaftTheme.ink)
    }
}

struct MissingDataView: View {
    @EnvironmentObject private var model: SiaftModel
    var body: some View {
        VStack(spacing: 20) {
            Text("No hay información cargada.")
            Button("Actualizar") { Task { await model.refresh() } }.buttonStyle(.borderedProminent)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: SiaftModel
    var body: some View {
        if let data = model.snapshot {
            ScrollView {
                VStack(spacing: 18) {
                    SiaftCard(title: "Hola, \(model.session?.name ?? "")") {
                        Text("Así van tus finanzas.").foregroundStyle(.secondary)
                        Button("Nuevo movimiento", systemImage: "plus") { model.sheet = .movement }.buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    SiaftCard(title: "Tus saldos") {
                        if data.dashboard.walletBalances.isEmpty { Text("Crea tu primera billetera para comenzar.") }
                        ForEach(Array(data.dashboard.walletBalances.enumerated()), id: \.offset) { _, balance in
                            AmountRow(title: balance.currency, amount: balance.currentBalance, currency: balance.currency)
                        }
                    }
                    SiaftCard(title: "Mes actual") {
                        if data.dashboard.currentMonth.isEmpty { Text("Todavía no hay movimientos este mes.") }
                        ForEach(Array(data.dashboard.currentMonth.enumerated()), id: \.offset) { _, summary in SummaryRows(summary: summary) }
                    }
                    SiaftCard(title: "Gastos principales") {
                        if data.dashboard.topExpenseCategories.isEmpty { Text("Sin gastos para mostrar.") }
                        ForEach(Array(data.dashboard.topExpenseCategories.enumerated()), id: \.offset) { _, category in
                            VStack(alignment: .leading) {
                                AmountRow(title: category.category, amount: category.expense, currency: category.currency)
                                Text("\(category.percentage.description)%").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    SiaftCard(title: "Movimientos recientes") {
                        if data.dashboard.recentMovements.isEmpty { Text("Aún no hay movimientos.") }
                        ForEach(data.dashboard.recentMovements) { movement in
                            MovementRow(nature: movement.nature, amount: movement.amount, currency: movement.currency,
                                        title: movement.description?.isEmpty == false ? movement.description! : movement.category ?? Finance.nature(movement.nature),
                                        detail: "\(movement.effectiveDate) · \(movement.wallet)")
                        }
                        Button("Ver todos") { model.tab = 1 }.frame(minHeight: 44)
                    }
                    SiaftCard(title: "Accesos directos") {
                        Button("Crear billetera", systemImage: "wallet.pass") { model.sheet = .wallet }.frame(minHeight: 44)
                        Button("Crear categoría", systemImage: "tag") { model.sheet = .category }.frame(minHeight: 44)
                        Button("Ver reportes", systemImage: "chart.bar") { model.tab = 4 }.frame(minHeight: 44)
                    }
                }.padding().frame(maxWidth: 760).frame(maxWidth: .infinity)
            }.background(SiaftTheme.background).refreshable { await model.refresh() }
        } else { MissingDataView() }
    }
}

struct MovementRow: View {
    let nature: Int
    let amount: Decimal
    let currency: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(Finance.nature(nature), systemImage: nature == 1 ? "arrow.down.left" : nature == 2 ? "arrow.up.right" : "arrow.left.arrow.right")
                .font(.caption.bold()).foregroundStyle(SiaftTheme.movement(nature))
            AmountRow(title: title, amount: amount, currency: currency)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 6).accessibilityElement(children: .combine)
    }
}

struct MovementsView: View {
    @EnvironmentObject private var model: SiaftModel
    @State private var filterDates = false
    @State private var filters = ReportFilters()
    @State private var cancellation: Movement?
    var body: some View {
        if let data = model.snapshot {
            List {
                Section {
                    Button("Nuevo movimiento", systemImage: "plus") { model.sheet = .movement }
                    DisclosureGroup("Filtros") {
                        Toggle("Filtrar por fechas", isOn: $filterDates)
                        if filterDates {
                            DatePicker("Desde", selection: $filters.from, displayedComponents: .date)
                            DatePicker("Hasta", selection: $filters.to, displayedComponents: .date)
                            if Finance.date(filters.from) > Finance.date(filters.to) { Text("La fecha inicial debe ser anterior a la final.").foregroundStyle(.red) }
                        }
                        Picker("Billetera", selection: $filters.walletId) {
                            Text("Todas").tag("")
                            ForEach(data.wallets) { Text($0.name).tag($0.id) }
                        }
                    }
                }
                let filtered = data.movements.filter { movement in
                    (!filterDates || (movement.effectiveDate >= Finance.date(filters.from) && String(movement.effectiveDate.prefix(10)) <= Finance.date(filters.to))) &&
                    (filters.walletId.isEmpty || movement.originWalletId == filters.walletId || movement.destinationWalletId == filters.walletId)
                }
                if filtered.isEmpty { Text("No hay movimientos para estos filtros.") }
                ForEach(filtered) { movement in
                    VStack(alignment: .leading) {
                        MovementRow(nature: movement.nature, amount: movement.amount, currency: movement.currency,
                                    title: movement.description?.isEmpty == false ? movement.description! : Finance.nature(movement.nature), detail: movement.effectiveDate)
                        if movement.status == 1 {
                            Button("Anular", role: .destructive) { cancellation = movement }.frame(minHeight: 44)
                        } else { Text("Anulado").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(SiaftTheme.background)
            .refreshable { await model.refresh() }
            .confirmationDialog("¿Anular este movimiento?", isPresented: Binding(get: { cancellation != nil }, set: { if !$0 { cancellation = nil } }), titleVisibility: .visible) {
                if let movement = cancellation {
                    Button("Anular movimiento", role: .destructive) {
                        cancellation = nil
                        Task { await model.mutate { repo, token in try await repo.cancelMovement(token: token, id: movement.id) } }
                    }
                }
            } message: { Text("Se revertirá su efecto sobre los saldos.") }
        } else { MissingDataView() }
    }
}

struct WalletsView: View {
    @EnvironmentObject private var model: SiaftModel
    var body: some View {
        if let data = model.snapshot {
            List {
                Button("Nueva billetera", systemImage: "plus") { model.sheet = .wallet }
                if data.wallets.isEmpty { Text("Todavía no tienes billeteras.") }
                ForEach(data.wallets) { wallet in
                    VStack(alignment: .leading, spacing: 8) {
                        AmountRow(title: wallet.name, amount: wallet.currentBalance, currency: wallet.currency)
                        Text("\(wallet.type == 1 ? "Efectivo" : "Cuenta bancaria") · \(wallet.active ? "Activa" : "Inactiva")").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
            }.scrollContentBackground(.hidden).background(SiaftTheme.background).refreshable { await model.refresh() }
        } else { MissingDataView() }
    }
}

struct CategoriesView: View {
    @EnvironmentObject private var model: SiaftModel
    var body: some View {
        if let data = model.snapshot {
            List {
                Button("Nueva categoría", systemImage: "plus") { model.sheet = .category }
                if data.categories.isEmpty { Text("Todavía no hay categorías.") }
                ForEach(data.categories) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.name).bold()
                        Text("\(Finance.nature(category.nature)) · \(category.isGlobal ? "Compartida" : "Personal")\(category.active ? "" : " · Inactiva")").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
            }.scrollContentBackground(.hidden).background(SiaftTheme.background).refreshable { await model.refresh() }
        } else { MissingDataView() }
    }
}
