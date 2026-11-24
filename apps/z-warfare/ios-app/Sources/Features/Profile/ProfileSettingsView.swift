import SwiftUI

// Port of OptionsMenu / SaveOptions (0x036e1d7c) + Star Road + 12-Language Switcher + Save JSON Tools
public struct ZWProfileSettingsView: View {
    @ObservedObject private var save = ZWSaveGameService.shared
    @ObservedObject private var loc = ZWLocalizationService.shared
    @ObservedObject private var sound = ZWSoundEngine.shared

    @State private var exportedJSON: String = ""
    @State private var showExportSheet = false
    @State private var confirmReset = false

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            // Left: Commander Profile, Star Road Milestones & Audio
            ZWTacticalPanel {
                VStack(alignment: .leading, spacing: 8) {
                    ZWOutlineText("COMMANDER PROFILE & STAR ROAD", palette: "GoldSolid", font: ZWTypography.impact(14))

                    HStack(spacing: 14) {
                        Text("Rank \(save.data.playerRank)")
                            .font(ZWTypography.impact(15))
                            .foregroundColor(ZWPalette.courageBlue)
                        Text("XP \(save.data.playerXP)/\(save.xpThreshold(forRank: save.data.playerRank))")
                            .font(ZWTypography.mono(10))
                            .foregroundColor(.white)
                        Text("★ \(save.totalStars) Stars")
                            .font(ZWTypography.mono(11))
                            .foregroundColor(ZWPalette.coinGold)
                    }

                    Divider().background(ZWPalette.panelBorder)

                    Toggle("Background Music (Original OST)", isOn: Binding(
                        get: { !sound.isMusicMuted },
                        set: { sound.isMusicMuted = !$0 }
                    ))
                    .font(ZWTypography.body(11))
                    .foregroundColor(.white)

                    Toggle("Haptic Combat Feedback", isOn: Binding(
                        get: { !sound.isSFXMuted },
                        set: { sound.isSFXMuted = !$0 }
                    ))
                    .font(ZWTypography.body(11))
                    .foregroundColor(.white)

                    Text("STAR ROAD MILESTONES")
                        .font(ZWTypography.mono(9))
                        .foregroundColor(.gray)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([10, 25, 50, 100, 200, 400], id: \.self) { target in
                                let claimed = save.data.claimedStarMilestones.contains(target)
                                let ready = save.totalStars >= target && !claimed
                                Button {
                                    guard ready else { return }
                                    save.data.claimedStarMilestones.append(target)
                                    save.data.cash += 15
                                    save.data.coins += target * 10
                                    save.save()
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("\(target)★")
                                            .font(ZWTypography.impact(12))
                                            .foregroundColor(ZWPalette.coinGold)
                                        Text(claimed ? "CLAIMED" : (ready ? "CLAIM +15$" : "LOCKED"))
                                            .font(ZWTypography.mono(8))
                                            .foregroundColor(ready ? ZWPalette.cashGreen : .gray)
                                    }
                                    .padding(7)
                                    .background(ZWPalette.tarmacDark)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Button("EXPORT SAVE JSON") {
                            exportedJSON = save.exportJSONString()
                            showExportSheet = true
                        }
                        .buttonStyle(ZWTacticalButtonStyle(tone: .blue, compact: true))

                        Button("RESET PROGRESS") {
                            confirmReset = true
                        }
                        .buttonStyle(ZWTacticalButtonStyle(tone: .red, compact: true))
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)

            // Right: All 12 Extracted Languages from 37_localization.txt
            ZWTacticalPanel {
                VStack(alignment: .leading, spacing: 6) {
                    ZWOutlineText("LANGUAGE (12 LOCALIZATIONS)", palette: "CyanSolid", font: ZWTypography.impact(13))
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(ZWLanguage.allCases) { lang in
                                let active = loc.language == lang
                                Button {
                                    loc.language = lang
                                    ZWSoundEngine.shared.playTapHaptic()
                                } label: {
                                    HStack {
                                        Text(lang.displayName)
                                            .font(ZWTypography.body(11))
                                            .foregroundColor(.white)
                                        Spacer()
                                        if active {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(ZWPalette.cashGreen)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(active ? ZWPalette.cashGreen.opacity(0.22) : ZWPalette.tarmacDark)
                                    .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: 280)
        }
        .sheet(isPresented: $showExportSheet) {
            VStack(spacing: 10) {
                Text("Z Warfare Save JSON Backup")
                    .font(ZWTypography.impact(16))
                TextEditor(text: $exportedJSON)
                    .font(ZWTypography.mono(10))
                HStack {
                    Button("Import Edited JSON") {
                        _ = save.importJSONString(exportedJSON)
                        showExportSheet = false
                    }
                    .buttonStyle(ZWTacticalButtonStyle(tone: .green))
                    Button("Close") {
                        showExportSheet = false
                    }
                    .buttonStyle(ZWTacticalButtonStyle(tone: .slate))
                }
            }
            .padding()
        }
        .alert("Reset All Save Data?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { save.resetSave() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This restores initial currencies, Campaign progress, and Survivor upgrades.")
        }
    }
}
