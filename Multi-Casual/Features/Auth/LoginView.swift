#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

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
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}
#endif
