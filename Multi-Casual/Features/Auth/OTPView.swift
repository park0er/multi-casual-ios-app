#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct OTPView: View {
    let viewModel: LoginViewModel

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "envelope.open").font(.system(size: 64))
            Text("Check your email").font(.title.bold())
            Text("We sent a code to **\(viewModel.email)**")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

            OTPInputField(
                code: Binding(get: { viewModel.code }, set: { viewModel.code = $0 }),
                onComplete: { Task { await viewModel.verifyCode() } }
            )
            .disabled(viewModel.isLoading)

            if let error = viewModel.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if viewModel.isLoading { ProgressView() }

            Button {
                Task { await viewModel.resendCode() }
            } label: {
                if viewModel.cooldownSeconds > 0 {
                    Text("Resend in \(viewModel.cooldownSeconds)s").foregroundStyle(.secondary)
                } else {
                    Text("Resend code").foregroundStyle(.blue)
                }
            }
            .disabled(viewModel.cooldownSeconds > 0)

            Button("Back") { viewModel.backToEmail() }.foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct OTPInputField: View {
    @Binding var code: String
    let onComplete: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<6) { i in
                let char = code.count > i ? String(Array(code)[i]) : ""
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? Color.primary : Color.secondary.opacity(0.4), lineWidth: 2)
                        .frame(width: 48, height: 56)
                    Text(char).font(.title2.bold())
                }
            }
        }
        .overlay(
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .opacity(0.01)
                .focused($isFocused)
                .onChange(of: code) { _, new in
                    let filtered = String(new.filter(\.isNumber).prefix(6))
                    if filtered != new { code = filtered }
                    if filtered.count == 6 { onComplete() }
                }
        )
        .onAppear { isFocused = true }
    }
}
#endif
