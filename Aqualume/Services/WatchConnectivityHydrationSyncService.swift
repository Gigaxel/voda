#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

public final class WatchConnectivityHydrationSyncService: NSObject, HydrationSyncing, WCSessionDelegate, @unchecked Sendable {
    private let session: WCSession?
    private let onLog: ((HydrationLog) -> Void)?
    private let onSettings: ((UserHydrationSettings) -> Void)?

    public init(
        onLog: ((HydrationLog) -> Void)? = nil,
        onSettings: ((UserHydrationSettings) -> Void)? = nil
    ) {
        self.session = WCSession.isSupported() ? WCSession.default : nil
        self.onLog = onLog
        self.onSettings = onSettings
        super.init()
        self.session?.delegate = self
    }

    public func activate() async {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        #endif
        session?.activate()
    }

    public func sendLog(_ log: HydrationLog) async {
        guard let data = try? JSONEncoder.aqualume.encode(log) else { return }
        send(["kind": "log", "payload": data])
    }

    public func sendSettings(_ settings: UserHydrationSettings) async {
        guard let data = try? JSONEncoder.aqualume.encode(settings) else { return }
        send(["kind": "settings", "payload": data])
    }

    private func send(_ message: [String: Any]) {
        guard let session else { return }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    private func handle(_ message: [String: Any]) {
        guard let kind = message["kind"] as? String,
              let payload = message["payload"] as? Data else {
            return
        }
        switch kind {
        case "log":
            if let log = try? JSONDecoder.aqualume.decode(HydrationLog.self, from: payload) {
                onLog?(log)
            }
        case "settings":
            if let settings = try? JSONDecoder.aqualume.decode(UserHydrationSettings.self, from: payload) {
                onSettings?(settings)
            }
        default:
            break
        }
    }

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        #endif
        session.activate()
    }
    #endif
}

extension JSONEncoder {
    static var aqualume: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var aqualume: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
#endif
