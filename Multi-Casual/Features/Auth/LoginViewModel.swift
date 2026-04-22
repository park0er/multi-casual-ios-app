#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import Observation

@Observable
@MainActor
public final class LoginViewModel {
    public enum Step { case email, otp }

    public var step: Step = .email
    public var email = ""
    public var code = ""
    public var errorMessage: String?
    public var isLoading = false
    public var cooldownSeconds = 0

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
    }

    public func sendCode() async {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Email is required"; return
        }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            try await api.sendCode(email: email)
            step = .otp
            startCooldown()
        } catch {
            errorMessage = "Failed to send code. Please try again."
        }
    }

    public func verifyCode() async {
        guard code.count == 6 else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let token = try await api.verifyCode(email: email, code: code)
            let user = try await api.getMe()
            let workspaces = try await api.listWorkspaces()
            try authSession.login(user: user, workspace: workspaces.first, token: token)
        } catch {
            errorMessage = "Invalid or expired code. Try again."
            code = ""
        }
    }

    public func resendCode() async {
        guard cooldownSeconds == 0 else { return }
        await sendCode()
    }

    public func completeGoogleLogin(code: String, redirectURI: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let token = try await api.googleLogin(code: code, redirectURI: redirectURI)
            let user = try await api.getMe()
            let workspaces = try await api.listWorkspaces()
            try authSession.login(user: user, workspace: workspaces.first, token: token)
        } catch {
            errorMessage = "Google sign-in failed. Please try again."
        }
    }

    public func backToEmail() { step = .email; code = ""; errorMessage = nil }

    private func startCooldown() {
        cooldownSeconds = 60
        Task {
            while cooldownSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                cooldownSeconds -= 1
            }
        }
    }
}
#endif
