import SwiftUI

// Evidence: LaunchScreen-iPhone.nib + Unity CanvasScaler Landscape design for iPhone XS Max (896x414 pt @3x)
// Safe area in Landscape: Left/Right = 44 pt, Bottom = 21 pt, Top = 0 pt.
public enum ZWLayout {
    public static let topHUDHeight: CGFloat = 40
    public static let bottomDockHeight: CGFloat = 52
    public static let cardCornerRadius: CGFloat = 6
    public static let panelCornerRadius: CGFloat = 8
    public static let borderWidth: CGFloat = 1.5
}

public enum ZWTypography {
    // Mirrors extracted fonts: Eu_Impact30, Eu_Impact15, Eu_PSK8, Eu_Arial10
    public static func impact(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    public static func header(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    public static func body(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    public static func mono(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

public struct ZWOutlineText: View {
    public let text: String
    public let paletteName: String
    public let font: Font

    public init(_ text: String, palette: String = "WhiteSolid", font: Font = ZWTypography.impact(14)) {
        self.text = text
        self.paletteName = palette
        self.font = font
    }

    public var body: some View {
        let entry = ZWPaletteStore.shared.entry(named: paletteName)
        Text(text)
            .font(font)
            .foregroundColor(entry.fillColor)
            .shadow(color: entry.outlineColor, radius: 0, x: 1, y: 1)
            .shadow(color: entry.outlineColor, radius: 0, x: -1, y: 1)
            .shadow(color: entry.outlineColor, radius: 0, x: 1, y: -1)
    }
}

public enum ZWButtonTone {
    case green
    case gold
    case blue
    case red
    case slate
    case purple

    var topColor: Color {
        switch self {
        case .green: return Color(.displayP3, red: 0.30, green: 0.72, blue: 0.25, opacity: 1)
        case .gold: return Color(.displayP3, red: 0.96, green: 0.73, blue: 0.16, opacity: 1)
        case .blue: return Color(.displayP3, red: 0.20, green: 0.56, blue: 0.90, opacity: 1)
        case .red: return Color(.displayP3, red: 0.84, green: 0.24, blue: 0.22, opacity: 1)
        case .slate: return Color(.displayP3, red: 0.26, green: 0.29, blue: 0.34, opacity: 1)
        case .purple: return Color(.displayP3, red: 0.56, green: 0.28, blue: 0.86, opacity: 1)
        }
    }

    var bottomColor: Color {
        switch self {
        case .green: return Color(.displayP3, red: 0.16, green: 0.46, blue: 0.14, opacity: 1)
        case .gold: return Color(.displayP3, red: 0.72, green: 0.48, blue: 0.05, opacity: 1)
        case .blue: return Color(.displayP3, red: 0.10, green: 0.32, blue: 0.62, opacity: 1)
        case .red: return Color(.displayP3, red: 0.56, green: 0.11, blue: 0.11, opacity: 1)
        case .slate: return Color(.displayP3, red: 0.15, green: 0.17, blue: 0.21, opacity: 1)
        case .purple: return Color(.displayP3, red: 0.36, green: 0.15, blue: 0.58, opacity: 1)
        }
    }
}

public struct ZWTacticalButtonStyle: ButtonStyle {
    public let tone: ZWButtonTone
    public let compact: Bool

    public init(tone: ZWButtonTone = .green, compact: Bool = false) {
        self.tone = tone
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 5 : 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: ZWLayout.cardCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [tone.topColor, tone.bottomColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: ZWLayout.cardCornerRadius)
                        .strokeBorder(Color.black.opacity(0.85), lineWidth: 1.5)
                    RoundedRectangle(cornerRadius: ZWLayout.cardCornerRadius - 1)
                        .inset(by: 1.5)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                }
            )
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
    }
}

public struct ZWTacticalPanel<Content: View>: View {
    public let borderColor: Color
    public let content: () -> Content

    public init(borderColor: Color = ZWPalette.panelBorder, @ViewBuilder content: @escaping () -> Content) {
        self.borderColor = borderColor
        self.content = content
    }

    public var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: ZWLayout.panelCornerRadius)
                    .fill(ZWPalette.panelSlate.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ZWLayout.panelCornerRadius)
                    .strokeBorder(borderColor, lineWidth: ZWLayout.borderWidth)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 3)
    }
}
