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

    public init() {}

    public func connect(token: String) async {
        lastToken = token
        guard !isConnected else { return }
        openTask(token: token)
    }

    public func disconnect() {
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        isConnected = false
        isReconnecting = false
        reconnectAttempt = 0
        lastToken = nil
        finishAllStreams()
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

    private func openTask(token: String) {
        guard let url = URL(string: "wss://api.multica.ai/ws") else {
            finishAllStreams()
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let task = URLSession.shared.webSocketTask(with: request)
        wsTask = task
        isConnected = true
        task.resume()
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

        if transient, let token = lastToken, reconnectAttempt < 5 {
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
            guard lastToken != nil else { return }
            openTask(token: token)
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
        struct Envelope: Decodable {
            let type: String
            let task_id: String?
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
        let event = WSEvent(type: envelope.type, taskId: envelope.task_id, payload: data)
        let typed = continuations[envelope.type]?.values ?? Dictionary<UUID, AsyncStream<WSEvent>.Continuation>().values
        let wildcard = continuations["*"]?.values ?? Dictionary<UUID, AsyncStream<WSEvent>.Continuation>().values
        for c in typed { c.yield(event) }
        for c in wildcard { c.yield(event) }
    }
}
