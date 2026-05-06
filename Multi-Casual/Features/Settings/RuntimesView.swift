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
                            NavigationLink {
                                RuntimeDetailView(runtime: runtime)
                            } label: {
                                RuntimeRow(runtime: runtime)
                            }
                            .accessibilityIdentifier("RuntimeRow")
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
                    if let lastSeen = runtime.lastSeenAt {
                        MarkdownText("Seen \(lastSeen.formatted(.relative(presentation: .named)))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RuntimeDetailView: View {
    let runtime: AgentRuntime

    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: RuntimeDetailViewModel?
    @State private var updateTargetVersion = ""

    var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section("Runtime") {
                        MarkdownLabeledContent("Name", value: runtime.name)
                        MarkdownLabeledContent("Health", value: healthLabel)
                        MarkdownLabeledContent("Provider", value: runtime.provider.capitalized)
                        MarkdownLabeledContent("Mode", value: runtime.runtimeMode.capitalized)
                        if let ownerName = vm.ownerName {
                            MarkdownLabeledContent("Owner", value: ownerName)
                        }
                        if !runtime.deviceInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            MarkdownLabeledContent("Device", value: formattedDeviceInfo(runtime.deviceInfo))
                        }
                        if let cliVersion = vm.cliVersion {
                            MarkdownLabeledContent("CLI", value: cliVersion)
                        }
                        if let launchedBy = vm.launchedBy {
                            MarkdownLabeledContent("Launched By", value: launchedBy)
                        }
                        if let lastSeenAt = runtime.lastSeenAt {
                            MarkdownLabeledContent("Last Seen", value: lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let daemonId = runtime.daemonId, !daemonId.isEmpty {
                            MarkdownLabeledContent("Daemon", value: shortDaemonId(daemonId))
                        }
                    }

                    if let usage = vm.usageSummary {
                        Section("Usage · 30D") {
                            MarkdownLabeledContent("Tokens", value: usage.totalTokens.formatted())
                            MarkdownLabeledContent("Input", value: usage.totalInputTokens.formatted())
                            MarkdownLabeledContent("Output", value: usage.totalOutputTokens.formatted())
                            MarkdownLabeledContent("Cache Read", value: usage.totalCacheReadTokens.formatted())
                            MarkdownLabeledContent("Cache Write", value: usage.totalCacheWriteTokens.formatted())
                        }
                    } else if vm.isLoading {
                        Section("Usage · 30D") {
                            ProgressView()
                        }
                    }

                    if !vm.usageByAgent.isEmpty {
                        Section("Usage by Agent · 30D") {
                            ForEach(vm.usageByAgent.prefix(5)) { row in
                                VStack(alignment: .leading, spacing: 4) {
                                    MarkdownText(row.agentName ?? row.agentId)
                                        .font(.body.weight(.medium))
                                    MarkdownText("\(row.totalTokens.formatted()) tokens")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !vm.usageByHour.isEmpty {
                        Section("Usage by Hour · 30D") {
                            ForEach(vm.usageByHour.prefix(5)) { row in
                                MarkdownLabeledContent(row.hour, value: "\(row.totalTokens.formatted()) tokens")
                            }
                        }
                    }

                    if !vm.activity.isEmpty {
                        Section("Task Activity") {
                            ForEach(vm.activity.prefix(5)) { row in
                                MarkdownLabeledContent(row.hour, value: "\(row.totalTasks.formatted()) tasks")
                            }
                        }
                    }

                    Section("Runtime Update") {
                        TextField("Target version", text: $updateTargetVersion)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("RuntimeUpdateTargetField")

                        Button {
                            Task { await vm.startUpdate(targetVersion: updateTargetVersion) }
                        } label: {
                            Label(vm.isUpdatingRuntime ? "Updating Runtime" : "Update Runtime", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(vm.isUpdatingRuntime || updateTargetVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("RuntimeUpdateButton")

                        if let update = vm.updateRequest {
                            RuntimeUpdateStatusView(update: update)

                            Button {
                                Task { await vm.refreshUpdateResult() }
                            } label: {
                                Label(vm.isUpdatingRuntime ? "Refreshing Update Status" : "Refresh Update Status", systemImage: "arrow.clockwise")
                            }
                            .disabled(vm.isUpdatingRuntime)
                            .accessibilityIdentifier("RuntimeRefreshUpdateStatusButton")
                        }
                    }

                    Section("Runtime Capabilities") {
                        Button {
                            Task { await vm.refreshModels() }
                        } label: {
                            Label(vm.isRefreshingModels ? "Refreshing Models" : "Refresh Models", systemImage: "cpu")
                        }
                        .disabled(vm.isRefreshingModels)

                        if let modelList = vm.modelList {
                            MarkdownLabeledContent("Model Request", value: modelList.status.capitalized)
                            if let supported = modelList.supported {
                                MarkdownLabeledContent("Models Supported", value: supported ? "Yes" : "No")
                            }
                            if let error = modelList.error, !error.isEmpty {
                                MarkdownText(error)
                                    .foregroundStyle(.red)
                            }
                            if modelList.models.isEmpty {
                                MarkdownText("No models returned.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(modelList.models.prefix(8)) { model in
                                    VStack(alignment: .leading, spacing: 3) {
                                        MarkdownText(model.name)
                                            .font(.body.weight(.medium))
                                        if let provider = model.provider, !provider.isEmpty {
                                            MarkdownText(provider)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            Task { await vm.refreshLocalSkills() }
                        } label: {
                            Label(vm.isRefreshingLocalSkills ? "Refreshing Local Skills" : "Refresh Local Skills", systemImage: "wand.and.stars")
                        }
                        .disabled(vm.isRefreshingLocalSkills)

                        if let localSkillList = vm.localSkillList {
                            MarkdownLabeledContent("Local Skills Request", value: localSkillList.status.capitalized)
                            if let supported = localSkillList.supported {
                                MarkdownLabeledContent("Local Skills Supported", value: supported ? "Yes" : "No")
                            }
                            if let error = localSkillList.error, !error.isEmpty {
                                MarkdownText(error)
                                    .foregroundStyle(.red)
                            }
                            if localSkillList.skills.isEmpty {
                                MarkdownText("No local skills returned.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(localSkillList.skills.prefix(8)) { skill in
                                    RuntimeLocalSkillRow(skill: skill, isImporting: vm.isImportingLocalSkill) {
                                        Task {
                                            await vm.importLocalSkill(
                                                skillKey: skill.key,
                                                name: skill.name,
                                                description: skill.description
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        if let localSkillImport = vm.localSkillImport {
                            RuntimeLocalSkillImportStatusView(request: localSkillImport)

                            Button {
                                Task { await vm.refreshLocalSkillImportResult() }
                            } label: {
                                Label(vm.isImportingLocalSkill ? "Refreshing Import Status" : "Refresh Import Status", systemImage: "arrow.clockwise")
                            }
                            .disabled(vm.isImportingLocalSkill)
                            .accessibilityIdentifier("RuntimeRefreshLocalSkillImportButton")
                        }
                    }

                    Section("Serving Agents") {
                        if vm.isLoading && vm.servingAgents.isEmpty {
                            ProgressView()
                        } else if vm.servingAgents.isEmpty {
                            MarkdownText("No agents are assigned to this runtime.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.servingAgents) { agent in
                                VStack(alignment: .leading, spacing: 3) {
                                    MarkdownText(agent.name)
                                        .font(.body.weight(.medium))
                                    HStack(spacing: 8) {
                                        MarkdownText(agent.status.capitalized)
                                        if let model = agent.model, !model.isEmpty {
                                            MarkdownText(model)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                .accessibilityIdentifier("RuntimeDetailList")
                .refreshable { await vm.load() }
            } else {
                ProgressView()
            }
        }
        .markdownNavigationTitle(runtime.name)
        .onAppear {
            if viewModel == nil {
                let vm = RuntimeDetailViewModel(runtime: runtime, api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
    }

    private var healthLabel: String {
        if runtime.status == "online" {
            return "Online"
        }
        guard let lastSeenAt = runtime.lastSeenAt else {
            return "Offline"
        }
        let offlineFor = Date().timeIntervalSince(lastSeenAt)
        if offlineFor < 5 * 60 {
            return "Recently Lost"
        }
        if offlineFor > 6 * 24 * 60 * 60 {
            return "About To GC"
        }
        return "Offline"
    }

    private func formattedDeviceInfo(_ raw: String) -> String {
        raw.split(separator: " · ")
            .map { prettifyOSArch(String($0)) }
            .joined(separator: " · ")
    }

    private func prettifyOSArch(_ raw: String) -> String {
        switch raw.lowercased() {
        case "darwin-arm64": return "macOS (arm64)"
        case "darwin-amd64": return "macOS (x86_64)"
        case "linux-arm64": return "Linux (arm64)"
        case "linux-amd64": return "Linux (x86_64)"
        case "windows-amd64": return "Windows (x86_64)"
        default: return raw
        }
    }

    private func shortDaemonId(_ id: String) -> String {
        guard id.count > 10 else { return id }
        return "\(id.prefix(6))..\(id.suffix(2))"
    }
}

private struct RuntimeUpdateStatusView: View {
    let update: RuntimeUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MarkdownLabeledContent("Update Status", value: update.status.capitalized)
            MarkdownLabeledContent("Target Version", value: update.targetVersion)
            if let output = update.output, !output.isEmpty {
                MarkdownText(output)
                    .font(.caption)
            }
            if let error = update.error, !error.isEmpty {
                MarkdownText(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let updatedAt = update.updatedAt {
                MarkdownText("Updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RuntimeLocalSkillRow: View {
    let skill: RuntimeLocalSkillInfo
    let isImporting: Bool
    let importAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    MarkdownText(skill.name)
                        .font(.body.weight(.medium))
                    if let description = skill.description, !description.isEmpty {
                        MarkdownText(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                Button(action: importAction) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(isImporting || skill.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("RuntimeImportLocalSkillButton")
            }

            if let provider = skill.provider, !provider.isEmpty {
                MarkdownLabeledContent("Provider", value: provider)
                    .font(.caption)
            }
            if let fileCount = skill.fileCount {
                MarkdownLabeledContent("Files", value: fileCount.formatted())
                    .font(.caption)
            }
            if let path = skill.path, !path.isEmpty {
                MarkdownText(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RuntimeLocalSkillImportStatusView: View {
    let request: RuntimeLocalSkillImportRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MarkdownLabeledContent("Import Status", value: request.status.capitalized)
            MarkdownLabeledContent("Skill Key", value: request.skillKey)
            if let name = request.name, !name.isEmpty {
                MarkdownLabeledContent("Name", value: name)
            }
            if let importedSkill = request.skill {
                MarkdownLabeledContent("Created Skill", value: importedSkill.name)
            }
            if let error = request.error, !error.isEmpty {
                MarkdownText(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let updatedAt = request.updatedAt {
                MarkdownText("Updated \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
