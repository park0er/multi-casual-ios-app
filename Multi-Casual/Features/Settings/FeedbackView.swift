#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct FeedbackView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: FeedbackViewModel?
    @State private var message = ""
    @State private var url = ""

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section {
                        TextEditor(text: $message)
                            .frame(minHeight: 150)
                            .accessibilityIdentifier("FeedbackMessageEditor")

                        TextField("URL (optional)", text: $url)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityIdentifier("FeedbackURLField")

                        Button {
                            Task {
                                await vm.submit(message: message, url: url)
                                if vm.errorMessage == nil {
                                    message = ""
                                    url = ""
                                }
                            }
                        } label: {
                            if vm.isSubmitting {
                                ProgressView()
                            } else {
                                Label("Send Feedback", systemImage: "paperplane")
                            }
                        }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSubmitting)
                    } footer: {
                        MarkdownText("Share bugs, rough edges, or parity gaps for the current workspace.")
                    }

                    if let successMessage = vm.successMessage {
                        Section {
                            MarkdownText(successMessage)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    if let errorMessage = vm.errorMessage {
                        Section {
                            MarkdownText(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Feedback")
        .onAppear {
            if viewModel == nil {
                viewModel = FeedbackViewModel(api: api, authSession: authSession)
            }
        }
    }
}
#endif
