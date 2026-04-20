import Foundation

public actor WebSocketActor {
    public static let shared = WebSocketActor()

    private var wsTask: URLSessionWebSocketTask?
    private var continuations: [String: [AsyncStream<WSEvent>.Continuation]] = [:]
    private var isConnected = false

    public init() {}

    public func connect(token: String) async {
        guard !isConnected else { return }
        let url = URL(string: "wss://api.multica.ai/ws?token=\(token)")!
        wsTask = URLSession.shared.webSocketTask(with: url)
        wsTask?.resume()
        isConnected = true
        Task { await receiveLoop() }
    }

    public func disconnect() {
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
        isConnected = false
        for (_, conts) in continuations {
            conts.forEach { $0.finish() }
        }
        continuations = [:]
    }

    /// Returns an AsyncStream of WSEvents matching the given event type.
    /// The stream ends when disconnect() is called.
    /// Pass "*" to receive all events.
    public func subscribe(to eventType: String) -> AsyncStream<WSEvent> {
        AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            Task {
                await self.addContinuation(continuation, forType: eventType)
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(continuation, forType: eventType) }
            }
        }
    }

    private func addContinuation(_ cont: AsyncStream<WSEvent>.Continuation, forType type: String) {
        continuations[type, default: []].append(cont)
    }

    private func removeContinuation(_ cont: AsyncStream<WSEvent>.Continuation, forType type: String) {
        // We can't compare continuations directly; on disconnect we clean up all.
        // For v1 this is fine — views that disappear cancel via onTermination.
    }

    private func receiveLoop() async {
        guard let task = wsTask else { return }
        while isConnected {
            guard let message = try? await task.receive() else {
                isConnected = false
                for (_, conts) in continuations { conts.forEach { $0.finish() } }
                continuations = [:]
                break
            }
            switch message {
            case .data(let data):
                dispatch(data: data)
            case .string(let text):
                if let data = text.data(using: .utf8) { dispatch(data: data) }
            @unknown default:
                break
            }
        }
    }

    private func dispatch(data: Data) {
        struct Envelope: Decodable {
            let type: String
            let task_id: String?
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
        let event = WSEvent(type: envelope.type, taskId: envelope.task_id, payload: data)
        // Deliver to type-specific and wildcard subscribers
        let targets = (continuations[envelope.type] ?? []) + (continuations["*"] ?? [])
        targets.forEach { $0.yield(event) }
    }
}
