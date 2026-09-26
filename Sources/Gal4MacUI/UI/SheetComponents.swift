import SwiftUI
import AppKit

enum GalUITheme {
    static let accent = Color(red: 0.40, green: 0.30, blue: 0.98)
    static let chartPalette: [Color] = [
        accent,
        Color(red: 0.30, green: 0.70, blue: 0.98),
        Color(red: 0.30, green: 0.78, blue: 0.62),
        Color(red: 0.98, green: 0.66, blue: 0.32),
        Color(red: 0.95, green: 0.43, blue: 0.56),
        Color(red: 0.30, green: 0.78, blue: 0.82)
    ]
}

/// Shared sheet language: clear titles and restrained acrylic surfaces.
struct GalSheetHeader: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(GalUITheme.accent)
                .frame(width: 44, height: 44)
                .background(GalUITheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func galSheetCard(cornerRadius: CGFloat = 13) -> some View {
        background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }
}
