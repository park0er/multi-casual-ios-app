#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import AuthenticationServices

public struct LoginView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: LoginViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                switch vm.step {
                case .email: emailStep(vm: vm)
                case .otp: OTPView(viewModel: vm)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LoginViewModel(api: APIClient(authSession: authSession), authSession: authSession)
            }
        }
    }

    private func emailStep(vm: LoginViewModel) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bolt.circle.fill").font(.system(size: 64))
            Text("Sign in to Multica").font(.title.bold())
            Text("Enter your email to get a login code").font(.subheadline).foregroundStyle(.secondary)

            VStack(spacing: 12) {
                TextField("you@example.com", text: Binding(get: { vm.email }, set: { vm.email = $0 }))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                if let error = vm.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                Button { Task { await vm.sendCode() } } label: {
                    Group {
                        if vm.isLoading { ProgressView() }
                        else { Text("Continue") }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(.primary, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.background)
                }
                .disabled(vm.email.isEmpty || vm.isLoading)

                HStack {
                    Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                }

                Button { startGoogleOAuth(vm: vm) } label: {
                    Label("Continue with Google", systemImage: "globe")
                        .frame(maxWidth: .infinity).padding()
                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func startGoogleOAuth(vm: LoginViewModel) {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String,
              let bundleId = Bundle.main.bundleIdentifier else { return }
        let state = PKCE.generateRandomString(byteLength: 32)
        let redirectURI = "\(bundleId)://auth/callback"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "select_account"),
            .init(name: "state", value: state),
        ]
        guard let url = components.url else { return }
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: bundleId) { callbackURL, error in
            guard let callbackURL, error == nil else { return }
            let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
            guard let code = items?.first(where: { $0.name == "code" })?.value,
                  let returnedState = items?.first(where: { $0.name == "state" })?.value,
                  returnedState == state else { return }
            Task { @MainActor in
                await vm.completeGoogleLogin(code: code, redirectURI: redirectURI)
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
}
#endif
