#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct NotificationPreferencesView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: NotificationPreferencesViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.isLoading {
                        ProgressView()
                    }

                    Section {
                        ForEach(NotificationPreferenceGroup.allCases) { group in
                            Toggle(isOn: binding(for: group, viewModel: vm)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    MarkdownText(group.displayName)
                                        .font(.body.weight(.semibold))
                                    MarkdownText(group.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(vm.isMutating)
                            .accessibilityIdentifier("NotificationPreference-\(group.rawValue)")
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
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Notifications")
        .onAppear {
            if viewModel == nil {
                let vm = NotificationPreferencesViewModel(api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            guard let viewModel else { return }
            Task { await viewModel.load() }
        }
    }

    private func binding(
        for group: NotificationPreferenceGroup,
        viewModel vm: NotificationPreferencesViewModel
    ) -> Binding<Bool> {
        Binding(
            get: { vm.value(for: group) == .all },
            set: { enabled in
                Task { await vm.set(group, enabled: enabled) }
            }
        )
    }
}
#endif
