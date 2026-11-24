import SwiftUI
import UIKit

// Evidence: TextColorsPalette extracted from Data/resources.assets (59 entries)
// Loaded at runtime from Data/text_colors_palette.json with verified RGBA defaults.
public struct ZWPaletteEntry: Decodable, Sendable {
    public let name: String
    public let fill: [Double]
    public let outline: [Double]

    public var fillColor: Color {
        Self.color(from: fill)
    }

    public var outlineColor: Color {
        Self.color(from: outline)
    }

    public var uiFillColor: UIColor {
        Self.uiColor(from: fill)
    }

    public var uiOutlineColor: UIColor {
        Self.uiColor(from: outline)
    }

    private static func color(from c: [Double]) -> Color {
        guard c.count >= 4 else { return .white }
        return Color(.displayP3, red: c[0], green: c[1], blue: c[2], opacity: c[3])
    }

    private static func uiColor(from c: [Double]) -> UIColor {
        guard c.count >= 4 else { return .white }
        return UIColor(displayP3Red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: CGFloat(c[3]))
    }
}

// Port of TextColorsPalette resource owner
public final class ZWPaletteStore: @unchecked Sendable {
    public static let shared = ZWPaletteStore()

    public private(set) var entriesByName: [String: ZWPaletteEntry] = [:]

    private init() {
        loadFromBundle()
    }

    public func loadFromBundle(bundle: Bundle = .main) {
        let urls: [URL?] = [
            bundle.url(forResource: "text_colors_palette", withExtension: "json", subdirectory: "Data"),
            bundle.url(forResource: "text_colors_palette", withExtension: "json")
        ]
        for case let url? in urls {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([ZWPaletteEntry].self, from: data) {
                var map: [String: ZWPaletteEntry] = [:]
                for item in decoded {
                    map[item.name] = item
                }
                self.entriesByName = map
                return
            }
        }
    }

    public func entry(named name: String) -> ZWPaletteEntry {
        if let found = entriesByName[name] {
            return found
        }
        return Self.fallbackEntries[name] ?? ZWPaletteEntry(
            name: name,
            fill: [1.0, 1.0, 1.0, 1.0],
            outline: [0.0, 0.0, 0.0, 0.85]
        )
    }

    // Exact fallback RGBA values observed in Data/text_colors_palette.json
    private static let fallbackEntries: [String: ZWPaletteEntry] = [
        "WhiteSolid": ZWPaletteEntry(name: "WhiteSolid", fill: [1.0, 1.0, 1.0, 1.0], outline: [0.0, 0.0, 0.0, 0.6]),
        "GoldSolid": ZWPaletteEntry(name: "GoldSolid", fill: [1.0, 0.84, 0.16, 1.0], outline: [0.15, 0.08, 0.0, 0.85]),
        "GreenSolid": ZWPaletteEntry(name: "GreenSolid", fill: [0.42, 0.92, 0.25, 1.0], outline: [0.0, 0.12, 0.0, 0.85]),
        "WaterColor": ZWPaletteEntry(name: "WaterColor", fill: [0.32, 0.85, 1.0, 1.0], outline: [0.04, 0.12, 0.25, 0.9]),
        "RageColor": ZWPaletteEntry(name: "RageColor", fill: [1.0, 0.22, 0.56, 1.0], outline: [0.2, 0.0, 0.12, 0.9]),
        "CyanSolid": ZWPaletteEntry(name: "CyanSolid", fill: [0.0, 1.0, 1.0, 1.0], outline: [0.0, 0.0, 0.0, 0.6]),
        "ExpSolid": ZWPaletteEntry(name: "ExpSolid", fill: [0.35, 0.78, 1.0, 1.0], outline: [0.05, 0.1, 0.2, 0.9]),
        "KeysColor": ZWPaletteEntry(name: "KeysColor", fill: [0.45, 0.82, 1.0, 1.0], outline: [0.05, 0.1, 0.2, 0.9]),
        "RedKeysColor": ZWPaletteEntry(name: "RedKeysColor", fill: [1.0, 0.34, 0.34, 1.0], outline: [0.22, 0.02, 0.02, 0.9]),
        "SkinCoins": ZWPaletteEntry(name: "SkinCoins", fill: [0.58, 0.72, 1.0, 1.0], outline: [0.08, 0.1, 0.25, 0.9]),
        "CharmPoints": ZWPaletteEntry(name: "CharmPoints", fill: [0.85, 0.52, 1.0, 1.0], outline: [0.18, 0.04, 0.25, 0.9]),
        "WarningMessage": ZWPaletteEntry(name: "WarningMessage", fill: [1.0, 0.28, 0.22, 1.0], outline: [0.2, 0.0, 0.0, 0.9]),
        "ZombiepediaDescr": ZWPaletteEntry(name: "ZombiepediaDescr", fill: [0.26, 0.19, 0.13, 1.0], outline: [0.26, 0.19, 0.13, 0.0]),
        "ZombiepediaKills": ZWPaletteEntry(name: "ZombiepediaKills", fill: [0.76, 0.17, 0.14, 1.0], outline: [0.15, 0.04, 0.03, 0.8]),
        "PvpSolid": ZWPaletteEntry(name: "PvpSolid", fill: [0.74, 0.86, 1.0, 1.0], outline: [0.08, 0.14, 0.26, 0.9]),
        "Difficulty0": ZWPaletteEntry(name: "Difficulty0", fill: [0.45, 0.9, 0.35, 1.0], outline: [0.06, 0.16, 0.04, 0.85]),
        "Difficulty1": ZWPaletteEntry(name: "Difficulty1", fill: [0.75, 0.92, 0.25, 1.0], outline: [0.15, 0.16, 0.02, 0.85]),
        "Difficulty2": ZWPaletteEntry(name: "Difficulty2", fill: [1.0, 0.84, 0.2, 1.0], outline: [0.22, 0.14, 0.0, 0.85]),
        "Difficulty3": ZWPaletteEntry(name: "Difficulty3", fill: [1.0, 0.56, 0.16, 1.0], outline: [0.24, 0.08, 0.0, 0.85]),
        "Difficulty4": ZWPaletteEntry(name: "Difficulty4", fill: [1.0, 0.26, 0.22, 1.0], outline: [0.25, 0.02, 0.02, 0.85]),
        "Difficulty5": ZWPaletteEntry(name: "Difficulty5", fill: [0.85, 0.18, 0.95, 1.0], outline: [0.18, 0.0, 0.24, 0.9])
    ]
}

// Evidence: Authentic pixel-outlined text styling matching DAZW Unity TextMeshPro / TextColorsPalette
public enum ZWPalette {
    public static func fill(_ name: String) -> Color {
        ZWPaletteStore.shared.entry(named: name).fillColor
    }

    public static func outline(_ name: String) -> Color {
        ZWPaletteStore.shared.entry(named: name).outlineColor
    }

    // Core UI Surface Colors (Display P3 tuned for 6.5" iPhone XS Max Super Retina OLED)
    public static let voidBlack = Color(.displayP3, red: 0.04, green: 0.045, blue: 0.055, opacity: 1)
    public static let tarmacDark = Color(.displayP3, red: 0.105, green: 0.115, blue: 0.135, opacity: 1)
    public static let panelSlate = Color(.displayP3, red: 0.155, green: 0.17, blue: 0.195, opacity: 1)
    public static let panelBorder = Color(.displayP3, red: 0.30, green: 0.33, blue: 0.37, opacity: 1)
    public static let hudBarBackground = Color(.displayP3, red: 0.08, green: 0.09, blue: 0.11, opacity: 0.90)

    public static let courageBlue = Color(.displayP3, red: 0.18, green: 0.78, blue: 1.0, opacity: 1)
    public static let ragePink = Color(.displayP3, red: 0.98, green: 0.20, blue: 0.54, opacity: 1)
    public static let cashGreen = Color(.displayP3, red: 0.24, green: 0.82, blue: 0.36, opacity: 1)
    public static let coinGold = Color(.displayP3, red: 1.0, green: 0.80, blue: 0.16, opacity: 1)
    public static let hazardOrange = Color(.displayP3, red: 0.96, green: 0.52, blue: 0.12, opacity: 1)
    public static let dangerRed = Color(.displayP3, red: 0.92, green: 0.22, blue: 0.20, opacity: 1)
    public static let notebookPaper = Color(.displayP3, red: 0.91, green: 0.85, blue: 0.73, opacity: 1)
    public static let notebookInk = Color(.displayP3, red: 0.24, green: 0.18, blue: 0.13, opacity: 1)
    public static let metroPurple = Color(.displayP3, red: 0.56, green: 0.26, blue: 0.88, opacity: 1)
}
