import SwiftUI

extension Color {
    /// Creates a colour from a 0xRRGGBB literal, e.g. `Color(hex: 0x37E3FF)`.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    /// Creates a colour from a `#RRGGBB` string. Falls back to grey for malformed input.
    init(hexString: String) {
        var cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self.init(hex: 0x8A9099)
            return
        }
        self.init(hex: value)
    }
}
