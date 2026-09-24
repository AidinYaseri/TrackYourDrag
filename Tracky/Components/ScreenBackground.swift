import SwiftUI

/// The dark carbon backdrop every screen sits on, with a single soft accent
/// glow so the flat black does not look like a void.
struct ScreenBackground: View {
    var accent: Color = Theme.Palette.accent

    var body: some View {
        ZStack {
            Theme.Palette.base
            LinearGradient(
                colors: [Theme.Palette.backdrop, Theme.Palette.base],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [accent.opacity(0.14), .clear],
                center: .init(x: 0.5, y: -0.05),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Applies the app backdrop behind a screen's content.
    func trackyBackground(accent: Color = Theme.Palette.accent) -> some View {
        background(ScreenBackground(accent: accent))
    }
}

#Preview {
    ScreenBackground()
}
