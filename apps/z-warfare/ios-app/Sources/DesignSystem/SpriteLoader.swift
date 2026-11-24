import Foundation
import SwiftUI
import SpriteKit
import UIKit

// Evidence: GameSprites/UnitSheets/unit_sheets_manifest.json (157 animated sheets)
public struct ZWSpriteFrameSlice: Codable, Sendable {
    public let start: Int
    public let count: Int
}

public struct ZWUnitSheetInfo: Codable, Sendable {
    public let frameWidth: Int
    public let frameHeight: Int
    public let totalFrames: Int
    public let states: [String: ZWSpriteFrameSlice]
}

// Thread-safe resource owner for all extracted GameSprites folders.
// Indexes lowercased stems -> exact on-disk URL so iOS 16.1.1 case-sensitive APFS never misses files.
public final class ZWSpriteLoader: @unchecked Sendable {
    public static let shared = ZWSpriteLoader()

    public enum SpriteFolder: String, CaseIterable {
        case portraits = "GameSprites/Portraits"
        case ui = "GameSprites/UI"
        case unitSheets = "GameSprites/UnitSheets"
        case bus = "GameSprites/Bus"
        case backgrounds = "GameSprites/Backgrounds"
        case battle = "GameSprites/Battle"
    }

    private let lock = NSLock()
    private let imageCache = NSCache<NSString, UIImage>()
    private var fileIndex: [String: [String: URL]] = [:]
    public private(set) var sheetManifest: [String: ZWUnitSheetInfo] = [:]

    private init() {
        // Guard against Jetsam on 4 GB RAM iPhone XS Max
        imageCache.countLimit = 220
        imageCache.totalCostLimit = 64 * 1024 * 1024
        rebuildIndex()
    }

    public func rebuildIndex(bundle: Bundle = .main) {
        lock.lock()
        defer { lock.unlock() }

        let fm = FileManager.default
        var indexed: [String: [String: URL]] = [:]

        for folder in SpriteFolder.allCases {
            var map: [String: URL] = [:]
            if let base = bundle.resourceURL?.appendingPathComponent(folder.rawValue, isDirectory: true),
               let items = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for url in items {
                    let key = url.deletingPathExtension().lastPathComponent.lowercased()
                    map[key] = url
                }
            }
            indexed[folder.rawValue] = map
        }
        self.fileIndex = indexed

        let manifestURLs: [URL?] = [
            bundle.url(forResource: "unit_sheets_manifest", withExtension: "json", subdirectory: "GameSprites/UnitSheets"),
            bundle.url(forResource: "unit_sheets_manifest", withExtension: "json")
        ]
        for case let mURL? in manifestURLs {
            if let data = try? Data(contentsOf: mURL),
               let parsed = try? JSONDecoder().decode([String: ZWUnitSheetInfo].self, from: data) {
                self.sheetManifest = parsed
                break
            }
        }
    }

    public func url(for name: String, in folder: SpriteFolder) -> URL? {
        let normalized = (name as NSString).deletingPathExtension.lowercased()
        lock.lock()
        defer { lock.unlock() }
        if let direct = fileIndex[folder.rawValue]?[normalized] {
            return direct
        }
        return nil
    }

    public func uiImage(named name: String, in folder: SpriteFolder) -> UIImage? {
        let key = "\(folder.rawValue)/\(name.lowercased())" as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let url = url(for: name, in: folder),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        let cost = Int(image.size.width * image.size.height * 4)
        imageCache.setObject(image, forKey: key, cost: cost)
        return image
    }

    public func availableFileNames(in folder: SpriteFolder) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(fileIndex[folder.rawValue]?.keys ?? [:].keys).sorted()
    }

    public func sheetInfo(for id: String) -> ZWUnitSheetInfo? {
        let lower = id.lowercased()
        if let exact = sheetManifest[lower] {
            return exact
        }
        return sheetManifest[id]
    }

    // Crops one animation state ("idle", "move", "attack", "death") from horizontal sprite strip
    public func frames(for sheetId: String, state: String) -> [SKTexture] {
        guard let sheetImage = uiImage(named: sheetId, in: .unitSheets),
              let cg = sheetImage.cgImage,
              let info = sheetInfo(for: sheetId) else {
            return []
        }
        let slice = info.states[state] ?? info.states["idle"] ?? ZWSpriteFrameSlice(start: 0, count: 1)
        let total = max(1, info.totalFrames)
        let frameW = cg.width / total
        let frameH = cg.height
        guard frameW > 0, frameH > 0 else { return [] }

        var textures: [SKTexture] = []
        let endIdx = min(total, slice.start + max(1, slice.count))
        for idx in slice.start..<endIdx {
            let rect = CGRect(x: idx * frameW, y: 0, width: frameW, height: frameH)
            if let cropped = cg.cropping(to: rect) {
                let tex = SKTexture(cgImage: cropped)
                tex.filteringMode = .nearest
                textures.append(tex)
            }
        }
        if textures.isEmpty, let cropped = cg.cropping(to: CGRect(x: 0, y: 0, width: frameW, height: frameH)) {
            let tex = SKTexture(cgImage: cropped)
            tex.filteringMode = .nearest
            textures.append(tex)
        }
        return textures
    }

    public func uiFrames(for sheetId: String, state: String = "idle") -> [UIImage] {
        guard let sheetImage = uiImage(named: sheetId, in: .unitSheets),
              let cg = sheetImage.cgImage,
              let info = sheetInfo(for: sheetId) else {
            return []
        }
        let slice = info.states[state] ?? info.states["idle"] ?? ZWSpriteFrameSlice(start: 0, count: 1)
        let total = max(1, info.totalFrames)
        let frameW = cg.width / total
        let frameH = cg.height
        guard frameW > 0, frameH > 0 else { return [] }

        var frames: [UIImage] = []
        let endIdx = min(total, slice.start + max(1, slice.count))
        for idx in slice.start..<endIdx {
            let rect = CGRect(x: idx * frameW, y: 0, width: frameW, height: frameH)
            if let cropped = cg.cropping(to: rect) {
                frames.append(UIImage(cgImage: cropped, scale: 1.0, orientation: .up))
            }
        }
        return frames
    }

    public func skTexture(named name: String, in folder: SpriteFolder) -> SKTexture? {
        guard let img = uiImage(named: name, in: folder) else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
    }
}

public struct ZWPixelSpriteView: View {
    public let name: String
    public let folder: ZWSpriteLoader.SpriteFolder
    public var fallbackSymbol: String = "shield.fill"
    public var contentMode: ContentMode = .fit

    public init(
        _ name: String,
        folder: ZWSpriteLoader.SpriteFolder,
        fallbackSymbol: String = "shield.fill",
        contentMode: ContentMode = .fit
    ) {
        self.name = name
        self.folder = folder
        self.fallbackSymbol = fallbackSymbol
        self.contentMode = contentMode
    }

    public var body: some View {
        if let img = ZWSpriteLoader.shared.uiImage(named: name, in: folder) {
            Image(uiImage: img)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Image(systemName: fallbackSymbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(ZWPalette.coinGold.opacity(0.75))
                .padding(6)
        }
    }
}

public struct ZWAnimatedUnitView: View {
    public let sheetId: String
    public let state: String
    public var fps: Double = 6.0

    public init(sheetId: String, state: String = "idle", fps: Double = 6.0) {
        self.sheetId = sheetId
        self.state = state
        self.fps = fps
    }

    public var body: some View {
        let frames = ZWSpriteLoader.shared.uiFrames(for: sheetId, state: state)
        if frames.isEmpty {
            ZWPixelSpriteView(sheetId, folder: .portraits, fallbackSymbol: "person.fill")
        } else if frames.count == 1 {
            Image(uiImage: frames[0])
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            TimelineView(.periodic(from: .now, by: 1.0 / max(1.0, fps))) { context in
                let idx = Int(context.date.timeIntervalSinceReferenceDate * fps) % frames.count
                Image(uiImage: frames[idx])
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}
