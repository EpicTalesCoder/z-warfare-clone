import Foundation
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// Evidence: Audio/Music/*.mp3 recovered from bundles/music.ab + SoundManager in UnityFramework
public enum ZWMusicTrack: String, CaseIterable, Sendable {
    case menu = "menu_ost"
    case battle = "battle_ost"
    case finalWave = "final_wave"
    case pvp = "pvp_ost"
    case metro = "metro"
    case bridgeBattle = "bridge_battle"
    case dungeonBattle = "dungeon_battle"
    case weeklyEvent = "weekly_event"
}

// Port of SoundManager + Haptics owner (iOS 16 safe UIImpactFeedbackGenerator + AVAudioPlayer)
public final class ZWSoundEngine: ObservableObject {
    public static let shared = ZWSoundEngine()

    private static let musicMutedKey = "zw.musicMuted"
    private static let sfxMutedKey = "zw.sfxMuted"

    @Published public var isMusicMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMusicMuted, forKey: Self.musicMutedKey)
            player?.volume = isMusicMuted ? 0 : 0.65
        }
    }

    @Published public var isSFXMuted: Bool {
        didSet {
            UserDefaults.standard.set(isSFXMuted, forKey: Self.sfxMutedKey)
        }
    }

    @Published public private(set) var currentTrack: ZWMusicTrack?

    private var player: AVAudioPlayer?
    #if canImport(UIKit)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notifier = UINotificationFeedbackGenerator()
    #endif

    private init() {
        self.isMusicMuted = UserDefaults.standard.bool(forKey: Self.musicMutedKey)
        self.isSFXMuted = UserDefaults.standard.bool(forKey: Self.sfxMutedKey)
        configureAudioSession()
    }

    private func configureAudioSession() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    public func playMusic(_ track: ZWMusicTrack, bundle: Bundle = .main) {
        if currentTrack == track, player?.isPlaying == true {
            return
        }
        currentTrack = track
        let candidates: [URL?] = [
            bundle.url(forResource: track.rawValue, withExtension: "mp3", subdirectory: "Audio/Music"),
            bundle.url(forResource: track.rawValue, withExtension: "mp3")
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            return
        }
        do {
            let nextPlayer = try AVAudioPlayer(contentsOf: url)
            nextPlayer.numberOfLoops = -1
            nextPlayer.volume = isMusicMuted ? 0 : 0.65
            nextPlayer.prepareToPlay()
            nextPlayer.play()
            player?.stop()
            player = nextPlayer
        } catch {
            // Audio device unavailable in headless/test runs
        }
    }

    public func stopMusic() {
        player?.stop()
        currentTrack = nil
    }

    public func playTapHaptic() {
        guard !isSFXMuted else { return }
        #if canImport(UIKit)
        lightImpact.impactOccurred(intensity: 0.7)
        #endif
    }

    public func playDeployHaptic() {
        guard !isSFXMuted else { return }
        #if canImport(UIKit)
        mediumImpact.impactOccurred(intensity: 0.9)
        #endif
    }

    public func playExplosionHaptic() {
        guard !isSFXMuted else { return }
        #if canImport(UIKit)
        heavyImpact.impactOccurred(intensity: 1.0)
        #endif
    }

    public func playVictoryHaptic(won: Bool) {
        guard !isSFXMuted else { return }
        #if canImport(UIKit)
        notifier.notificationOccurred(won ? .success : .error)
        #endif
    }
}
