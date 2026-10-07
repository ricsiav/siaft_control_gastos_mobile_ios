import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var model: SiaftModel
    @State private var filters = ReportFilters()
    var body: some View {
        List {
            Section("Período y billetera") {
                DatePicker("Desde", selection: $filters.from, displayedComponents: .date)
                DatePicker("Hasta", selection: $filters.to, displayedComponents: .date)
                Picker("Billetera", selection: $filters.walletId) {
                    Text("Todas").tag("")
                    ForEach(model.snapshot?.wallets ?? []) { Text($0.name).tag($0.id) }
                }
                Button("Consultar reporte") {
                    model.reportFilters = filters
                    Task { await model.loadReport() }
                }.frame(minHeight: 44)
            }
            if let report = model.report {
                Section("Resultados: \(Finance.date(model.reportFilters.from)) a \(Finance.date(model.reportFilters.to))") {
                    Text("\(report.registeredMovementCount) movimientos · \(report.transferCount) transferencias")
                    if report.summaries.isEmpty { Text("Sin movimientos para este período.") }
                    ForEach(Array(report.summaries.enumerated()), id: \.offset) { _, summary in SummaryRows(summary: summary).padding(.vertical, 8) }
                }
                Section("Por categoría") {
                    ForEach(Array(report.categories.enumerated()), id: \.offset) { _, category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.category).bold()
                            AmountRow(title: "Ingresos", amount: category.income, currency: category.currency)
                            AmountRow(title: "Gastos", amount: category.expense, currency: category.currency)
                            AmountRow(title: "Total", amount: category.total, currency: category.currency)
                            Text("\(category.percentage.description)%").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    }
                }
                Section("Evolución mensual") {
                    ForEach(Array(report.months.enumerated()), id: \.offset) { _, month in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(month.month).bold()
                            AmountRow(title: "Ingresos", amount: month.income, currency: month.currency)
                            AmountRow(title: "Gastos", amount: month.expense, currency: month.currency)
                            AmountRow(title: "Balance", amount: month.balance, currency: month.currency)
                        }.padding(.vertical, 8)
                    }
                }
            } else if !model.busy { Text("Selecciona los filtros y consulta el reporte.") }
        }
        .scrollContentBackground(.hidden).background(SiaftTheme.background)
        .task {
            filters = model.reportFilters
            if model.report == nil { await model.loadReport() }
        }
    }
}
