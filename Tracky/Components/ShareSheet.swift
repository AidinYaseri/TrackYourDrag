import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// What to hand to the system share sheet.
struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

#if canImport(UIKit)
/// Thin wrapper around `UIActivityViewController`.
///
/// Used instead of `ShareLink` because the summary card is expensive to render:
/// this way the image is only produced when the user actually asks to share.
struct ShareSheet: UIViewControllerRepresentable {
    let payload: SharePayload

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: payload.items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
