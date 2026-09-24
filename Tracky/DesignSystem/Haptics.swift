import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper so feedback can be fired from view models without importing UIKit
/// everywhere, and so it can be silenced from Settings.
enum Haptics {
    static var isEnabled = true

    enum Kind {
        case light, medium, heavy, success, warning, failure
    }

    static func fire(_ kind: Kind) {
        guard isEnabled else { return }
        #if canImport(UIKit) && !os(watchOS)
        DispatchQueue.main.async {
            switch kind {
            case .light:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .heavy:
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .warning:
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .failure:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
        #endif
    }
}
