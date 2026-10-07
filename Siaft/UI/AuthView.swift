import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var model: SiaftModel
    @State private var registering = false
    @State private var username = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var name = ""
    @State private var surname = ""
    @State private var email = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("SIAFT").font(.custom("DMSans-Bold", size: 34, relativeTo: .largeTitle)).foregroundStyle(.white)
                Text("Tu dinero, en orden.").font(.largeTitle.bold()).foregroundStyle(.white)
                Image("LoginFinances").resizable().scaledToFill().frame(height: 160).clipped().clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                SiaftCard(title: registering ? "Crea tu cuenta" : "Bienvenido de nuevo") {
                    VStack(spacing: 16) {
                        if registering {
                            TextField("Nombres", text: $name).textContentType(.givenName)
                            TextField("Apellidos", text: $surname).textContentType(.familyName)
                            TextField("Correo electrónico", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        }
                        TextField("Usuario", text: $username).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Contraseña", text: $password).textContentType(registering ? .newPassword : .password)
                        if registering { SecureField("Confirma la contraseña", text: $confirmation).textContentType(.newPassword) }
                        Button(registering ? "Crear cuenta" : "Iniciar sesión") { Task { await submit() } }
                            .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                        Button(registering ? "Ya tengo una cuenta" : "Crear una cuenta") {
                            registering.toggle(); password = ""; confirmation = ""
                        }.frame(minHeight: 44)
                    }.textFieldStyle(.roundedBorder)
                }.foregroundStyle(SiaftTheme.ink)
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(SiaftTheme.login.ignoresSafeArea())
        .onDisappear { password = ""; confirmation = "" }
    }

    private func submit() async {
        if registering {
            guard [name, surname, email, username, password].allSatisfy({ !$0.trimmed.isEmpty }),
                  email.contains("@"), password == confirmation else {
                model.message = "Completa todos los campos y confirma la contraseña."; return
            }
            let success = await model.perform { repo in
                try await repo.register(name: name, surname: surname, email: email, username: username, password: password, confirmation: confirmation)
            }
            if success { registering = false; password = ""; confirmation = ""; model.message = "Cuenta creada. Ya puedes iniciar sesión." }
        } else { await model.login(username: username, password: password) }
    }
}
