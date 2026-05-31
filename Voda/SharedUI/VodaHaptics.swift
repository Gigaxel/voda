#if os(iOS)
import UIKit

enum VodaHaptics {
    @MainActor
    static func log() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @MainActor
    static func goal() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
#else
enum VodaHaptics {
    @MainActor
    static func log() {}
    @MainActor
    static func goal() {}
}
#endif
