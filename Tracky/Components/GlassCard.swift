import SwiftUI

/// Rounded, faintly metallic panel used for every grouped block in the app.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Theme.Metrics.cardRadius
    var padding: CGFloat = 16
    var highlight: Color?
    @ViewBuilder var content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        content()
            .padding(padding)
            .background {
                shape
                    .fill(Theme.Palette.surface)
                    .overlay(shape.fill(Theme.Gradients.glass))
                    .overlay(
                        shape.strokeBorder(
                            highlight.map {
                                LinearGradient(
                                    colors: [$0.opacity(0.7), $0.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } ?? Theme.Gradients.glassStroke,
                            lineWidth: highlight == nil ? 1 : 1.4
                        )
                    )
            }
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        VStack(spacing: 12) {
            GlassCard { Text("Plain card").foregroundStyle(Theme.Palette.textPrimary) }
            GlassCard(highlight: Theme.Palette.accent) {
                Text("Highlighted").foregroundStyle(Theme.Palette.textPrimary)
            }
        }
        .padding()
    }
}
