import SwiftUI

@main
struct SiaftApp: App {
    @StateObject private var model = SiaftModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
                .tint(SiaftTheme.primary)
                .font(.custom("DMSans-Regular", size: 16, relativeTo: .body))
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: SiaftModel
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            Group {
                if model.session == nil { AuthView() } else { MainView() }
            }
            .disabled(model.busy)
            if model.busy {
                ProgressView("Un momento…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            if scenePhase != .active { SiaftTheme.login.ignoresSafeArea().overlay(Text("SIAFT").font(.largeTitle.bold()).foregroundStyle(.white)) }
        }
        .modifier(MessageAlert(model: model))
        .sheet(item: $model.sheet) { kind in
            NavigationStack {
                Group {
                    if kind == .profile { ProfileView() } else { EntryView(kind: kind) }
                }
                .navigationTitle(kind.rawValue)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { model.sheet = nil }.disabled(model.busy) } }
                .disabled(model.busy)
                .overlay { if model.busy { ProgressView().padding().background(.regularMaterial, in: Capsule()) } }
            }
            .interactiveDismissDisabled(model.busy)
            .environmentObject(model)
            .modifier(MessageAlert(model: model))
            .tint(SiaftTheme.primary)
        }
        .task { if model.session != nil { await model.refresh() } }
    }
}
