#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct RuntimesView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: RuntimesViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.isLoading && vm.runtimes.isEmpty {
                        ProgressView()
                    } else if vm.runtimes.isEmpty && vm.errorMessage == nil {
                        ContentUnavailableView("No Runtimes", systemImage: "server.rack", description: Text("This workspace has no runtimes yet."))
                    } else {
                        ForEach(vm.runtimes) { runtime in
                            RuntimeRow(runtime: runtime)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteRuntime(id: runtime.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .disabled(vm.isMutating)
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
                .listStyle(.plain)
                .refreshable { await vm.load() }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Runtimes")
        .onAppear {
            if viewModel == nil {
                let vm = RuntimesViewModel(api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            guard let viewModel else { return }
            Task { await viewModel.load() }
        }
    }
}

private struct RuntimeRow: View {
    let runtime: AgentRuntime

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "server.rack")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(runtime.name)
                    .font(.body.weight(.semibold))
                HStack(spacing: 8) {
                    MarkdownText(runtime.status.capitalized)
                    MarkdownText(runtime.provider.capitalized)
                    MarkdownText(runtime.runtimeMode.capitalized)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
