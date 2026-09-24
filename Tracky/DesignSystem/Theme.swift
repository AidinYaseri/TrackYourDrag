import SwiftUI

/// Central design tokens for Tracky.
///
/// The palette is deliberately its own thing: a near-black carbon base with an
/// ice-blue instrument accent, so the app reads like a digital cluster rather
/// than a stock iOS utility (and doesn't borrow any other tracker's identity).
enum Theme {

    // MARK: - Colour

    enum Palette {
        /// Deepest background, behind everything.
        static let base = Color(hex: 0x05070A)
        /// Slightly lifted backdrop used behind scroll content.
        static let backdrop = Color(hex: 0x0A0E13)
        /// Card / panel fill.
        static let surface = Color(hex: 0x11161D)
        /// Card fill one step higher in the stack.
        static let surfaceRaised = Color(hex: 0x181F28)
        /// Hairline borders on glass surfaces.
        static let stroke = Color(hex: 0x2A323D)
        static let strokeStrong = Color(hex: 0x3B4552)

        static let textPrimary = Color(hex: 0xF2F6FA)
        static let textSecondary = Color(hex: 0x9BA7B4)
        static let textTertiary = Color(hex: 0x66727F)

        /// Primary instrument accent.
        static let accent = Color(hex: 0x37E3FF)
        /// Secondary accent, used for gradients and comparison "run B".
        static let accentAlt = Color(hex: 0x7C5CFF)

        static let positive = Color(hex: 0x3DDC97)
        static let warning = Color(hex: 0xFFB020)
        static let danger = Color(hex: 0xFF5A5F)

        /// Longitudinal acceleration (pushing you back into the seat).
        static let gAccel = Color(hex: 0x3DDC97)
        /// Braking.
        static let gBrake = Color(hex: 0xFF5A5F)
        /// Cornering.
        static let gLateral = Color(hex: 0xFFB020)

        static func quality(_ quality: GPSQuality) -> Color {
            switch quality {
            case .excellent: return positive
            case .good: return accent
            case .fair: return warning
            case .poor: return danger
            }
        }
    }

    // MARK: - Gradients

    enum Gradients {
        static let accent = LinearGradient(
            colors: [Palette.accent, Palette.accentAlt],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let screen = LinearGradient(
            colors: [Palette.base, Palette.backdrop, Palette.base],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Subtle metallic sheen used on glass cards.
        static let glass = LinearGradient(
            colors: [Color.white.opacity(0.07), Color.white.opacity(0.015)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let glassStroke = LinearGradient(
            colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Metrics

    enum Metrics {
        static let cardRadius: CGFloat = 20
        static let tileRadius: CGFloat = 16
        static let controlRadius: CGFloat = 14
        static let screenPadding: CGFloat = 20
        static let tileSpacing: CGFloat = 12
        /// Minimum tappable height. Everything interactive in Tracky is at
        /// least this tall so it can be hit without looking at the screen.
        static let touchTarget: CGFloat = 56
    }

    // MARK: - Typography

    enum Typeface {
        /// Giant instrument readout (speed, result time).
        static func readout(_ size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
        }

        /// Numeric value inside a telemetry tile.
        static func value(_ size: CGFloat = 26) -> Font {
            .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
        }

        /// Small all-caps label above a value.
        static func label(_ size: CGFloat = 11) -> Font {
            .system(size: size, weight: .semibold, design: .rounded)
        }

        static func body(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .regular, design: .rounded)
        }

        static func title(_ size: CGFloat = 20) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
    }

    // MARK: - Motion

    enum Motion {
        /// Used for value changes that happen many times a second.
        static let telemetry: Animation = .interpolatingSpring(stiffness: 180, damping: 22)
        /// Standard UI transition.
        static let standard: Animation = .spring(response: 0.38, dampingFraction: 0.86)
        /// Bigger state changes (armed -> running -> result).
        static let stage: Animation = .spring(response: 0.5, dampingFraction: 0.82)
    }
}
