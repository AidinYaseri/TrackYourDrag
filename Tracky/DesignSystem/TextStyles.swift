import SwiftUI

/// Small all-caps label used above every numeric readout in the app.
struct MicroLabel: View {
    let text: String
    var color: Color = Theme.Palette.textTertiary
    var size: CGFloat = 11

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Typeface.label(size))
            .kerning(1.2)
            .foregroundStyle(color)
    }
}

extension View {
    /// Applies the app's default readout styling to a number.
    func readoutStyle(size: CGFloat, color: Color = Theme.Palette.textPrimary) -> some View {
        font(Theme.Typeface.readout(size))
            .foregroundStyle(color)
            .contentTransition(.numericText())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        MicroLabel(text: "G-Force")
        Text("0.82").readoutStyle(size: 64)
    }
    .padding()
    .background(Theme.Palette.base)
}
