#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

public struct PersonalAccessTokensView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: PersonalAccessTokensViewModel?
    @State private var tokenName = ""
    @State private var expiry = TokenExpiryOption.ninetyDays
    @State private var pendingRevokeToken: PersonalAccessToken?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section {
                        TextField("Token name", text: $tokenName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()

                        Picker("Expires", selection: $expiry) {
                            ForEach(TokenExpiryOption.allCases) { option in
                                MarkdownText(option.title).tag(option)
                            }
                        }

                        Button {
                            Task {
                                await vm.createToken(name: tokenName, expiresInDays: expiry.days)
                                if vm.errorMessage == nil {
                                    tokenName = ""
                                    expiry = .ninetyDays
                                }
                            }
                        } label: {
                            if vm.isCreating {
                                ProgressView()
                            } else {
                                Label("Create Token", systemImage: "plus.circle")
                            }
                        }
                        .disabled(tokenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isCreating)
                    } footer: {
                        MarkdownText("Personal access tokens let CLI and external integrations authenticate with your account.")
                    }

                    Section("Tokens") {
                        if vm.isLoading && vm.tokens.isEmpty {
                            ProgressView()
                        } else if vm.tokens.isEmpty && vm.errorMessage == nil {
                            ContentUnavailableView("No API Tokens", systemImage: "key", description: Text("Create a token when you need CLI or integration access."))
                        } else {
                            ForEach(vm.tokens) { token in
                                PersonalAccessTokenRow(token: token)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            pendingRevokeToken = token
                                        } label: {
                                            Label("Revoke", systemImage: "trash")
                                        }
                                        .disabled(vm.revokingTokenId == token.id)
                                    }
                            }
                        }
                    }

                    if let errorMessage = vm.errorMessage {
                        Section {
                            ErrorRetryView(message: errorMessage) {
                                Task { await vm.load() }
                            }
                        }
                    }
                }
                .refreshable { await vm.load() }
                .sheet(
                    isPresented: Binding(
                        get: { vm.newToken != nil },
                        set: { isPresented in
                            if !isPresented { vm.clearNewToken() }
                        }
                    )
                ) {
                    if let token = vm.newToken {
                        CreatedTokenSheet(token: token) {
                            vm.clearNewToken()
                        }
                    }
                }
                .alert("Revoke token?", isPresented: revokeAlertBinding(vm)) {
                    Button("Cancel", role: .cancel) { pendingRevokeToken = nil }
                    Button("Revoke", role: .destructive) {
                        guard let token = pendingRevokeToken else { return }
                        Task {
                            await vm.revokeToken(id: token.id)
                            pendingRevokeToken = nil
                        }
                    }
                } message: {
                    Text("This token will stop working immediately. This cannot be undone.")
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("API Tokens")
        .onAppear {
            if viewModel == nil {
                let vm = PersonalAccessTokensViewModel(api: api)
                viewModel = vm
                Task { await vm.load() }
            }
        }
    }

    private func revokeAlertBinding(_ vm: PersonalAccessTokensViewModel) -> Binding<Bool> {
        Binding(
            get: { pendingRevokeToken != nil },
            set: { isPresented in
                if !isPresented { pendingRevokeToken = nil }
            }
        )
    }
}

private enum TokenExpiryOption: String, CaseIterable, Identifiable {
    case thirtyDays
    case ninetyDays
    case oneYear
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .oneYear: "1 year"
        case .never: "No expiry"
        }
    }

    var days: Int? {
        switch self {
        case .thirtyDays: 30
        case .ninetyDays: 90
        case .oneYear: 365
        case .never: nil
        }
    }
}

private struct PersonalAccessTokenRow: View {
    let token: PersonalAccessToken

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MarkdownText(token.name)
                .font(.body.weight(.semibold))

            MarkdownText(tokenSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }

    private var tokenSummary: String {
        var parts = [
            "\(token.tokenPrefix)...",
            "Created \(Self.displayDate(token.createdAt))",
        ]
        parts.append(token.lastUsedAt.map { "Last used \(Self.displayDate($0))" } ?? "Never used")
        if let expiresAt = token.expiresAt {
            parts.append("Expires \(Self.displayDate(expiresAt))")
        }
        return parts.joined(separator: " · ")
    }

    private static func displayDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct CreatedTokenSheet: View {
    let token: String
    let onDone: () -> Void
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MarkdownText(token)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } footer: {
                    MarkdownText("Copy this token now. It will not be shown again.")
                }

                Section {
                    Button {
                        UIPasteboard.general.string = token
                        copied = true
                    } label: {
                        MarkdownIconLabel(copied ? "Copied" : "Copy Token", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
            .navigationTitle("Token Created")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}
#endif
