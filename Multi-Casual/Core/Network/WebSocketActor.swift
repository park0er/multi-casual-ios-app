import Foundation

public actor WebSocketActor {
    public static let shared = WebSocketActor()

    // Keyed by (event type, subscription UUID) so individual subscribers can be
    // removed on stream termination without sweeping everything.
    private var continuations: [String: [UUID: AsyncStream<WSEvent>.Continuation]] = [:]
    private var wsTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var isReconnecting = false
    private var reconnectAttempt = 0
    private var lastToken: String?
    private var lastWorkspaceId: String?

    public init() {}

    public func connect(token: String, workspaceId: String) async {
        if isConnected, lastToken == token, lastWorkspaceId == workspaceId {
            return
        }
        if isConnected {
            wsTask?.cancel(with: .normalClosure, reason: nil)
            wsTask = nil
            isConnected = false
            reconnectAttempt = 0
            finishAllStreams()
        }
        lastToken = token
        lastWorkspaceId = workspaceId
        await openTask(token: token, workspaceId: workspaceId)
    }

    public func disconnect() {
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        isConnected = false
        isReconnecting = false
        reconnectAttempt = 0
        lastToken = nil
        lastWorkspaceId = nil
        finishAllStreams()
    }

    static func decodeEventFrame(data: Data) -> WSEvent? {
        struct Envelope: Decodable {
            let type: String
            let payload: Data?

            enum CodingKeys: String, CodingKey { case type, payload }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                type = try container.decode(String.self, forKey: .type)
                if container.contains(.payload) {
                    let rawPayload = try container.decode(JSONValue.self, forKey: .payload)
                    payload = try JSONEncoder().encode(rawPayload)
                } else {
                    payload = nil
                }
            }
        }

        struct TaskPayloadProbe: Decodable {
            let taskId: String?
            enum CodingKeys: String, CodingKey { case taskId = "task_id" }
        }

        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return nil }
        guard envelope.type != "auth_ack" else { return nil }

        let payload = envelope.payload ?? data
        let taskId = (try? JSONDecoder().decode(TaskPayloadProbe.self, from: payload))?.taskId
        return WSEvent(type: envelope.type, taskId: taskId, payload: payload)
    }

    /// AsyncStream of WSEvents matching the given event type. Pass "*" for all events.
    /// Stream terminates when disconnect() is called or a non-transient error is hit.
    public func subscribe(to eventType: String) -> AsyncStream<WSEvent> {
        AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            let id = UUID()
            Task {
                await self.addContinuation(continuation, id: id, forType: eventType)
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id, forType: eventType) }
            }
        }
    }

    // MARK: - Internals

    private func openTask(token: String, workspaceId: String) async {
        guard var components = URLComponents(string: "wss://api.multica.ai/ws") else {
            finishAllStreams()
            return
        }
        components.queryItems = [
            URLQueryItem(name: "workspace_id", value: workspaceId),
            URLQueryItem(name: "client_platform", value: "ios"),
        ]
        guard let url = components.url else {
            finishAllStreams()
            return
        }
        let request = URLRequest(url: url)
        let task = URLSession.shared.webSocketTask(with: request)
        wsTask = task
        isConnected = true
        task.resume()
        do {
            let auth = #"{"type":"auth","payload":{"token":"\#(token)"}}"#
            try await task.send(.string(auth))
        } catch {
            wsTask = nil
            isConnected = false
            finishAllStreams()
            return
        }
        Task { await receiveLoop(task: task) }
    }

    private func addContinuation(
        _ cont: AsyncStream<WSEvent>.Continuation,
        id: UUID,
        forType type: String
    ) {
        continuations[type, default: [:]][id] = cont
    }

    private func removeContinuation(id: UUID, forType type: String) {
        continuations[type]?.removeValue(forKey: id)
        if continuations[type]?.isEmpty == true {
            continuations.removeValue(forKey: type)
        }
    }

    private func finishAllStreams() {
        for (_, bucket) in continuations {
            for (_, cont) in bucket { cont.finish() }
        }
        continuations = [:]
    }

    private func receiveLoop(task: URLSessionWebSocketTask) async {
        while isConnected && wsTask === task {
            do {
                let message = try await task.receive()
                reconnectAttempt = 0
                switch message {
                case .data(let data):
                    dispatch(data: data)
                case .string(let text):
                    if let data = text.data(using: .utf8) { dispatch(data: data) }
                @unknown default:
                    break
                }
            } catch {
                // Only reconnect for this task if it is still the active one — otherwise
                // disconnect() or a newer task has superseded us.
                guard wsTask === task else { return }
                await handleReceiveError(error)
                return
            }
        }
    }

    private func handleReceiveError(_ error: Error) async {
        let nsError = error as NSError
        let transient = Self.isTransient(error: error)

        if transient, let token = lastToken, let workspaceId = lastWorkspaceId, reconnectAttempt < 5 {
            isReconnecting = true
            reconnectAttempt += 1
            // Exponential backoff: 0.5s, 1s, 2s, 4s, 8s (capped)
            let delayNs = UInt64(min(8.0, 0.5 * pow(2.0, Double(reconnectAttempt - 1)))
                                 * 1_000_000_000)
            wsTask?.cancel()
            wsTask = nil
            isConnected = false
            try? await Task.sleep(nanoseconds: delayNs)
            isReconnecting = false
            // Another caller may have disconnect()'d in the meantime.
            guard lastToken != nil, lastWorkspaceId != nil else { return }
            await openTask(token: token, workspaceId: workspaceId)
        } else {
            // Terminal: tear down and notify subscribers.
            _ = nsError // kept for future logging
            wsTask = nil
            isConnected = false
            reconnectAttempt = 0
            finishAllStreams()
        }
    }

    private static func isTransient(error: Error) -> Bool {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .cancelled:
                return true
            default:
                return false
            }
        }
        // POSIXErrorDomain 57 (ENOTCONN) etc — treat generic URLSession hiccups as transient.
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }
        return false
    }

    private func dispatch(data: Data) {
        guard let event = Self.decodeEventFrame(data: data) else { return }
        let typed = continuations[event.type]?.values ?? Dictionary<UUID, AsyncStream<WSEvent>.Continuation>().values
        let wildcard = continuations["*"]?.values ?? Dictionary<UUID, AsyncStream<WSEvent>.Continuation>().values
        for c in typed { c.yield(event) }
        for c in wildcard { c.yield(event) }
    }
}
