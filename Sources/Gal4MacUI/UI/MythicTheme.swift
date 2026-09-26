import SwiftUI

enum MythicTheme {
    static let background = Color(red: 0.105, green: 0.105, blue: 0.11)
    static let sidebar = Color(red: 0.16, green: 0.16, blue: 0.17)
    static let surface = Color(red: 0.145, green: 0.145, blue: 0.15)
    static let surfaceRaised = Color(red: 0.205, green: 0.205, blue: 0.215)
    static let border = Color.white.opacity(0.08)
    static let accent = Color(red: 0.48, green: 0.22, blue: 0.87)
    static let accentLight = Color(red: 0.69, green: 0.50, blue: 0.98)
    static let heroTop = Color(red: 0.24, green: 0.18, blue: 0.37)
    static let heroBottom = Color(red: 0.13, green: 0.13, blue: 0.16)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.34)
}

extension View {
    func mythicPanel(cornerRadius: CGFloat = 14) -> some View {
        background(MythicTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(MythicTheme.border, lineWidth: 1)
            }
    }
}
