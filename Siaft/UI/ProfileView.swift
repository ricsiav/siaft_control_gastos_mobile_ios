import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var model: SiaftModel
    @State private var name = ""
    @State private var surname = ""
    @State private var email = ""
    @State private var current = ""
    @State private var new = ""
    @State private var confirmation = ""
    var body: some View {
        Form {
            if let profile = model.profile {
                Section("Mis datos") {
                    LabeledContent("Usuario", value: profile.username)
                    TextField("Nombres", text: $name).textContentType(.givenName)
                    TextField("Apellidos", text: $surname).textContentType(.familyName)
                    TextField("Correo electrónico", text: $email).keyboardType(.emailAddress).textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Guardar perfil") { Task { await model.updateProfile(name: name, surname: surname, email: email) } }.frame(minHeight: 44)
                }
                Section("Cambiar contraseña") {
                    SecureField("Contraseña actual", text: $current).textContentType(.password)
                    SecureField("Nueva contraseña", text: $new).textContentType(.newPassword)
                    SecureField("Confirma la nueva contraseña", text: $confirmation).textContentType(.newPassword)
                    Text("Entre 8 y 72 caracteres.").font(.caption)
                    Button("Actualizar contraseña") { Task { await changePassword() } }.frame(minHeight: 44)
                }
            } else {
                Button("Cargar perfil") { Task { await load() } }
            }
        }
        .task { await load() }
        .onDisappear { current = ""; new = ""; confirmation = "" }
    }

    private func load() async {
        await model.loadProfile()
        if let profile = model.profile { name = profile.name; surname = profile.surname; email = profile.email }
    }
    private func changePassword() async {
        guard !current.isEmpty, current.count <= 72, (8...72).contains(new.count), new == confirmation, new != current else {
            model.message = "Verifica la contraseña actual y confirma una nueva de 8 a 72 caracteres, distinta de la actual."; return
        }
        guard let token = model.session?.token else { return }
        let success = await model.perform { repo in
            try await repo.changePassword(token: token, current: current, new: new, confirmation: confirmation)
        }
        if success { current = ""; new = ""; confirmation = ""; model.message = "Contraseña actualizada." }
    }
}
