import SwiftUI
import UIKit

// Port of UnityAppController / DAZW Entry Point
// Locks Landscape orientations & status bar hidden matching original Info.plist on iPhone XS Max iOS 16.1.1.
public final class ZWAppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .landscape
    }
}

@main
public struct ZWarfareApp: App {
    @UIApplicationDelegateAdaptor(ZWAppDelegate.self) private var appDelegate

    public init() {
        _ = ZWPaletteStore.shared
        _ = ZWSpriteLoader.shared
        _ = ZWLocalizationService.shared
        _ = ZWGameCatalog.shared
    }

    public var body: some Scene {
        WindowGroup {
            ZWMainRootView()
                .preferredColorScheme(.dark)
        }
    }
}
