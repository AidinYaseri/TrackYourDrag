import SwiftUI

struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                MicroLabel(text: title, color: Theme.Palette.textSecondary, size: 12)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typeface.body(12))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Label on the left, value on the right. Used in stats, results and settings.
struct StatRow: View {
    let label: String
    let value: String
    var detail: String?
    var accent: Color = Theme.Palette.textPrimary
    var isHighlighted = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.Typeface.body(15))
                    .foregroundStyle(Theme.Palette.textSecondary)
                if let detail {
                    Text(detail)
                        .font(Theme.Typeface.body(11))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            Spacer(minLength: 0)
            Text(value)
                .font(Theme.Typeface.value(18))
                .foregroundStyle(isHighlighted ? Theme.Palette.accent : accent)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        VStack(spacing: 0) {
            SectionHeader(title: "Acceleration", subtitle: "Personal bests")
            GlassCard {
                VStack(spacing: 0) {
                    StatRow(label: "0 – 60 mph", value: "4.51 s", isHighlighted: true)
                    Divider().overlay(Theme.Palette.stroke)
                    StatRow(label: "0 – 100 km/h", value: "4.82 s", detail: "2007 Mazdaspeed 3")
                }
            }
        }
        .padding()
    }
}
