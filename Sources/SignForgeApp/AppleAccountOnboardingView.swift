import AuthenticationServices
import SwiftUI

struct AppleAccountOnboardingView: View {
    @Environment(VaultStore.self) private var store
    @State private var appleUserID = ""
    @State private var status = ""
    @State private var showCredentialSheet = false

    var body: some View {
        Form {
            Section("Apple account") {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleSignIn(result)
                }
                .frame(height: 48)
                Text("This verifies the person using SignForge. Apple does not grant Developer Portal provisioning access through Sign in with Apple.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !appleUserID.isEmpty { Text("Apple user linked").font(.caption).foregroundStyle(.secondary) }
            }

            Section("Provisioning access") {
                Link("Open API keys page", destination: URL(string: "https://appstoreconnect.apple.com/access/integrations/api")!)
                Button("Add API key") { showCredentialSheet = true }
                Text("Provisioning calls use an App Store Connect API key: issuer ID, key ID, team ID, and the one-time .p8 download.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Status") {
                Label(store.state.credentials.isEmpty ? "API key required" : "Ready for Apple API", systemImage: store.state.credentials.isEmpty ? "exclamationmark.triangle" : "checkmark.seal")
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Connect Apple")
        .sheet(isPresented: $showCredentialSheet) { NavigationStack { CredentialView() } }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                appleUserID = credential.user
                store.state.audit.insert(AuditEvent(message: "Linked Apple account identity"), at: 0)
                store.save()
                status = "Apple account linked"
            }
        case .failure(let error):
            status = error.localizedDescription
        }
    }
}
