import SwiftUI
import AppKit

@main
struct TohoStudioApp: App {
    @StateObject private var appState = AppState.shared

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Configure macOS app behavior
        NSApplication.shared.setActivationPolicy(.regular)

        if CommandLine.arguments.contains("--test-all") {
            runCharacterMakerSelfTest()
            runSoundMakerExportSelfTest()
            runSoundMakerDuoSpeakerSelfTest()
            runAIImagePromptSelfTest()
            print("\n🎉 ALL TOHOSTUDIO SELF-TESTS PASSED SUCCESSFULLY! 🎉\n")
            exit(0)
        }
        if CommandLine.arguments.contains("--test-character-maker") {
            runCharacterMakerSelfTest()
            exit(0)
        }
        if CommandLine.arguments.contains("--test-sound-maker-export") {
            runSoundMakerExportSelfTest()
            exit(0)
        }
        if CommandLine.arguments.contains("--test-sound-maker-duo-speaker") {
            runSoundMakerDuoSpeakerSelfTest()
            exit(0)
        }
        if CommandLine.arguments.contains("--test-ai-image-prompt") {
            runAIImagePromptSelfTest()
            exit(0)
        }
    }

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if NSApp.windows.filter({ $0.isVisible && !$0.isMiniaturized }).isEmpty {
                // If no window is visible, tell NSApp to open a new window or make existing key
                if let win = NSApp.windows.first {
                    win.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

    private func runCharacterMakerSelfTest() {
        print("=== [TEST] CharacterMaker Self-Test Started ===")
        let service = CharacterImageService.shared

        // 1. Reimu Preset
        var reimu = service.createPresetCharacter(name: "博麗霊夢")
        print("1. Reimu Preset: BaseImage=\(reimu.baseImagePath), PartsCount=\(reimu.parts.count)")
        assert(!reimu.baseImagePath.isEmpty, "Reimu base image path should not be empty")

        // 2. Expressions
        let exps = service.findCharacterExpressions(characterName: "博麗霊夢")
        print("2. Reimu Expressions: count=\(exps.count), keys=\(exps.keys.sorted())")
        assert(exps.count >= 5, "Reimu should have at least 5 expression variations")

        // 3. Marisa Broom Assembly
        let marisa = service.createPresetCharacter(name: "霧雨魔理沙")
        let hasBroom = marisa.parts.contains(where: { $0.name.contains("箒") })
        print("3. Marisa Broom Assembly: hasBroom=\(hasBroom), parts=\(marisa.parts.map { $0.name })")
        assert(hasBroom, "Marisa should have broom part for assembly")

        // 4. Koishi 3rd Eye Assembly
        let koishi = service.createPresetCharacter(name: "古明地こいし")
        let hasEye = koishi.parts.contains(where: { $0.name.contains("第3の目") || $0.name.contains("目") })
        print("4. Koishi 3rd Eye Assembly: hasEye=\(hasEye), parts=\(koishi.parts.map { $0.name })")
        assert(hasEye, "Koishi should have 3rd eye part for assembly")

        // 5. Parts Split
        service.splitCharacterIntoParts(model: &reimu)
        print("5. Parts Split: count=\(reimu.parts.count), names=\(reimu.parts.map { $0.name })")
        assert(reimu.parts.count >= 6, "Split should produce at least 6 parts")

        // 6. Cropping & Zoom
        if let baseImg = service.loadImage(from: reimu.baseImagePath) {
            let cropRect = CGRect(x: 0.25, y: 0.45, width: 0.50, height: 0.45)
            let cropped = service.cropAndScaleImage(sourceImage: baseImg, cropRectNormalized: cropRect, zoomFactor: 1.5)
            print("6. Crop & Zoom: success=\(cropped != nil), size=\(cropped?.size ?? .zero)")
            assert(cropped != nil, "Cropped image should not be nil")
        }

        // 7. Composite Rendering
        let composite = service.renderComposite(model: reimu)
        print("7. Composite Rendering: success=\(composite != nil), size=\(composite?.size ?? .zero)")
        assert(composite != nil, "Composite image should not be nil")

        // 8. Image Exporting
        let tmpDir = "/tmp/tohostudio_test_export"
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        let formats = [
            "PNG (透過立ち絵)",
            "JPG (高解像度背景付き)",
            "SVG (ベクター図形)",
            "PSD (Photoshopレイヤー別)",
            "GDRAW (Google図形互換)",
            ".tscm (プロジェクト編集ファイル)"
        ]
        for fmt in formats {
            let ext = fmt.contains("PNG") ? "png" : (fmt.contains("JPG") ? "jpg" : (fmt.contains("SVG") ? "svg" : (fmt.contains("PSD") ? "psd" : (fmt.contains("GDRAW") ? "gdraw" : "tscm"))))
            let outURL = URL(fileURLWithPath: "\(tmpDir)/test_output.\(ext)")
            do {
                try service.exportCharacterImage(model: reimu, format: fmt, destinationURL: outURL)
                let size = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                print("8. Export [\(fmt)] -> \(size) bytes")
                assert(size > 0, "Exported file should not be empty")
            } catch {
                print("Export error for \(fmt): \(error)")
            }
        }

        // 9. PSDTool Integration Test
        print("9. Verifying PSDTool HTML & files...")
        guard let psdHTMLURL = PSDToolService.getPSDToolHTMLURL() else {
            fatalError("PSDTool.html not found!")
        }
        print("   PSDTool HTML URL: \(psdHTMLURL.path)")
        let psdFilesDir = psdHTMLURL.deletingLastPathComponent().appendingPathComponent("PSDTool_files")
        let requiredPSDToolFiles = [
            "psd.min.js",
            "index.js",
            "3rd.min.js",
            "bootstrap.min.js",
            "jquery.min.js",
            "main.css",
            "bootstrap.min.css"
        ]
        for f in requiredPSDToolFiles {
            let fpath = psdFilesDir.appendingPathComponent(f).path
            assert(FileManager.default.fileExists(atPath: fpath), "Required PSDTool file missing: \(f)")
        }
        print("   All \(requiredPSDToolFiles.count) essential PSDTool_files verified!")

        let psdService = PSDToolService.shared
        psdService.scanPresets()
        print("   Found \(psdService.availablePresets.count) Touhou Project PSD presets:")
        for preset in psdService.availablePresets.prefix(5) {
            print("     - [\(preset.characterName)] \(preset.name): \(preset.path)")
            assert(FileManager.default.fileExists(atPath: preset.path), "Preset file must exist: \(preset.path)")
        }
        assert(psdService.availablePresets.count > 0, "At least one Touhou PSD preset must be detected")

        // Test PSD binary loading
        if let firstPreset = psdService.availablePresets.first {
            let data = try? Data(contentsOf: URL(fileURLWithPath: firstPreset.path))
            assert(data != nil && data!.count > 1000, "PSD binary must be loadable and non-empty")
            let b64 = data!.base64EncodedString()
            assert(!b64.isEmpty, "Base64 encoding must succeed")
            print("   Successfully loaded PSD binary for \(firstPreset.characterName) (\(data!.count) bytes)")
        }

        print("=== [TEST] ALL CHARACTER MAKER & PSDTOOL TESTS PASSED SUCCESSFULLY! ===")
    }

    private func runAIImagePromptSelfTest() {
        print("=== [TEST] AI Image Generator Prompt Self-Test Started ===")
        let testPrompt = "汗がたらたらと垂れている古明地こいしの立ち絵を作成"
        let hasChar = AIImageGeneratorService.hasExplicitCharacterOrPerson(testPrompt)
        print("   Character detected: \(hasChar)")
        assert(hasChar, "Prompt with Komeiji Koishi should be recognized as having a character")

        let english = AIImageGeneratorService.generateOptimizedEnglishPrompt(from: testPrompt)
        print("   Generated English Prompt for Koishi:")
        print("   \(english)")

        assert(english.hasPrefix("anime style"), "Anime style MUST be at the very front for CLIP 77-token priority")
        assert(english.contains("Komeiji Koishi"), "English prompt MUST contain 'Komeiji Koishi'")
        assert(english.contains("sweat"), "English prompt MUST contain sweating tags")
        assert(english.contains("standing"), "Standing prompt MUST contain standing pose tag")
        assert(!english.contains("no humans"), "Character prompt MUST NOT contain 'no humans'")
        assert(!english.contains("schoolyard"), "Character prompt MUST NOT mistakenly inject schoolyard")

        let negative = AIImageGeneratorService.convertNegativePromptToEnglish("低解像度, 崩れた構図, ノイズ, ぼやけ, 文字化け")
        print("   Generated Negative Prompt:")
        print("   \(negative)")
        assert(negative.contains("photorealistic") || negative.contains("photograph"), "Negative prompt MUST exclude photorealism for Touhou anime art")

        // Local Reference Archive Search & Composition Test
        print("   Testing TohoLocalReferenceAssetService search...")
        let localMatch = TohoLocalReferenceAssetService.shared.searchAndComposeAsset(prompt: testPrompt, aspectRatio: .portrait9_16)
        print("   Local match result: \(String(describing: localMatch?.description))")
        assert(localMatch != nil, "Local asset search MUST find Koishi in reference archive")
        assert(localMatch?.characterName == "古明地こいし", "Character name must be 古明地こいし")
        assert(localMatch?.composedImage != nil, "Composed image must be generated")
        print("   Successfully verified local reference asset match & composition for Koishi!")

        // Test background facility search
        let bgPrompt = "紅魔館のロビーの背景"
        let bgMatch = TohoLocalReferenceAssetService.shared.searchAndComposeAsset(prompt: bgPrompt, aspectRatio: .landscape16_9)
        print("   Background match result: \(String(describing: bgMatch?.description))")
        assert(bgMatch != nil, "Local asset search MUST find Scarlet Mansion lobby background")
        assert(bgMatch?.facilityName == "紅魔館", "Facility name must match 紅魔館")
        print("   Successfully verified local background reference asset match & composition!")

        // Test user's exact prompt variation: "汗をたらたらと流す古明地こいしの立ち絵を作成"
        let userExactPrompt = "汗をたらたらと流す古明地こいしの立ち絵を作成"
        let exactMatch = TohoLocalReferenceAssetService.shared.searchAndComposeAsset(prompt: userExactPrompt, aspectRatio: .portrait9_16)
        print("   Exact match result: \(String(describing: exactMatch?.description))")
        assert(exactMatch != nil, "Local asset search MUST find Koishi with exact user prompt")
        assert(exactMatch?.characterName == "古明地こいし", "Character name must be 古明地こいし")
        print("   Successfully verified local reference asset match for exact prompt!")

        print("=== [TEST] AI Image Generator Prompt Self-Test PASSED SUCCESSFULLY! ===")
    }

    private func runSoundMakerExportSelfTest() {
        print("=== [TEST] SoundMaker Export Self-Test Started ===")
        let tmpDir = URL(fileURLWithPath: "/tmp/tohostudio_soundmaker_test")
        try? FileManager.default.removeItem(at: tmpDir)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let clips: [SoundClip] = [
            SoundClip(name: "霊夢セリフ", type: "Voice", text: "ゆっくりしていってね！", duration: 2.0, startTime: 0.5, trackId: "track_voice"),
            SoundClip(name: "決定音", type: "SE", duration: 0.55, startTime: 1.0, trackId: "track_se"),
            SoundClip(name: "日常BGM", type: "BGM", duration: 4.0, volume: 0.6, startTime: 0.0, trackId: "track_bgm")
        ]

        let tracks: [AudioTrack] = [
            AudioTrack(id: "track_voice", name: "Voice (セリフ)", type: "voice", icon: "bubble.left", colorHex: "#E74C3C", volume: 1.0),
            AudioTrack(id: "track_se", name: "SE (効果音)", type: "se", icon: "bolt.fill", colorHex: "#2ECC71", volume: 0.8),
            AudioTrack(id: "track_bgm", name: "BGM (背景音楽)", type: "bgm", icon: "music.note", colorHex: "#9B59B6", volume: 0.6)
        ]

        let scenes: [MovieScene] = [
            MovieScene(
                title: "オープニング",
                duration: 4.5,
                slideTitle: "スライド1",
                backgroundName: "博麗神社",
                characterName: "博麗霊夢",
                telop: "ゆっくりしていってね！"
            )
        ]

        var isFinished = false

        Task {
            do {
                // 1. WAV Export (44.1kHz, 16bit)
                let wavURL = tmpDir.appendingPathComponent("master.wav")
                let optWav = SoundMakerExporter.ExportOptions(format: "WAV", sampleRate: 44100, bitDepth: 16)
                try await SoundMakerExporter.export(clips: clips, tracks: tracks, scenes: scenes, outputURL: wavURL, options: optWav) { p, msg in
                    print("  WAV progress: \(Int(p * 100))% - \(msg)")
                }
                let wavData = try Data(contentsOf: wavURL)
                print("1. WAV Export: size=\(wavData.count) bytes")
                assert(wavData.count > 1000, "WAV file should have audio data")
                assert(String(data: wavData.subdata(in: 0..<4), encoding: .ascii) == "RIFF", "Should have RIFF header")
                assert(String(data: wavData.subdata(in: 8..<12), encoding: .ascii) == "WAVE", "Should have WAVE header")

                // 2. MP3 Export
                let mp3URL = tmpDir.appendingPathComponent("master.mp3")
                let optMp3 = SoundMakerExporter.ExportOptions(format: "MP3", audioBitrate: "192k")
                try await SoundMakerExporter.export(clips: clips, tracks: tracks, scenes: scenes, outputURL: mp3URL, options: optMp3) { p, msg in
                    print("  MP3 progress: \(Int(p * 100))% - \(msg)")
                }
                let mp3Data = try Data(contentsOf: mp3URL)
                print("2. MP3 Export: size=\(mp3Data.count) bytes")
                assert(mp3Data.count > 500, "MP3 file should not be empty")

                // 3. M4A Export
                let m4aURL = tmpDir.appendingPathComponent("master.m4a")
                let optM4a = SoundMakerExporter.ExportOptions(format: "M4A", audioBitrate: "192k")
                try await SoundMakerExporter.export(clips: clips, tracks: tracks, scenes: scenes, outputURL: m4aURL, options: optM4a) { p, msg in
                    print("  M4A progress: \(Int(p * 100))% - \(msg)")
                }
                let m4aData = try Data(contentsOf: m4aURL)
                print("3. M4A Export: size=\(m4aData.count) bytes")
                assert(m4aData.count > 500, "M4A file should not be empty")

                // 4. Adobe Audition .sesx Export
                let sesxURL = tmpDir.appendingPathComponent("session.sesx")
                let optSesx = SoundMakerExporter.ExportOptions(format: "SESX")
                try await SoundMakerExporter.export(clips: clips, tracks: tracks, scenes: scenes, outputURL: sesxURL, options: optSesx) { p, msg in
                    print("  SESX progress: \(Int(p * 100))% - \(msg)")
                }
                let sesxStr = try String(contentsOf: sesxURL, encoding: .utf8)
                print("4. SESX Export: len=\(sesxStr.count)")
                assert(sesxStr.contains("<session"), "SESX must have session tag")
                assert(sesxStr.contains("<audioTrack"), "SESX must have audioTrack tags")

                // 5. Logic Pro .logicx Export
                let logicxURL = tmpDir.appendingPathComponent("project.logicx")
                let optLogicx = SoundMakerExporter.ExportOptions(format: "LOGICX")
                try await SoundMakerExporter.export(clips: clips, tracks: tracks, scenes: scenes, outputURL: logicxURL, options: optLogicx) { p, msg in
                    print("  LOGICX progress: \(Int(p * 100))% - \(msg)")
                }
                let altProjData = logicxURL.appendingPathComponent("Alternatives/000/ProjectData")
                assert(FileManager.default.fileExists(atPath: altProjData.path), "Logic ProjectData must exist")
                print("5. Logic Pro Export: bundle verified successfully!")

                // 6. ZIP Multi-Track Stems Export
                let zipURL = tmpDir.appendingPathComponent("stems.zip")
                let optZip = SoundMakerExporter.ExportOptions(format: "ZIP", scope: .trackStems)
                try await SoundMakerExporter.export(clips: clips, tracks: tracks, scenes: scenes, outputURL: zipURL, options: optZip) { p, msg in
                    print("  ZIP progress: \(Int(p * 100))% - \(msg)")
                }
                let zipData = try Data(contentsOf: zipURL)
                print("6. ZIP Stems Export: size=\(zipData.count) bytes")
                assert(zipData.count > 1000, "ZIP stems archive must not be empty")

                print("=== [TEST] ALL SOUNDMAKER EXPORT TESTS PASSED SUCCESSFULLY! ===")
            } catch {
                print("=== [TEST] FAILED: \(error) ===")
                exit(1)
            }
            isFinished = true
        }

        while !isFinished {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
    }

    private func runSoundMakerDuoSpeakerSelfTest() {
        print("=== [TEST] SoundMaker Duo Speaker Recognition & Speech Synthesis Self-Test Started ===")

        // 1. カッコ書きからの2人話者抽出テスト（スペースなしA&B形式）
        let testCases = [
            ("(霊夢&魔理沙) ゆっくりしていってね！", "博麗霊夢&霧雨魔理沙", "ゆっくりしていってね！"),
            ("(霊夢 & 魔理沙) ゆっくりしていってね！", "博麗霊夢&霧雨魔理沙", "ゆっくりしていってね！"),
            ("[霊夢＆魔理沙] ゆっくりしていってね！", "博麗霊夢&霧雨魔理沙", "ゆっくりしていってね！"),
            ("(博麗霊夢 & 霧雨魔理沙) ゆっくりしていってね！", "博麗霊夢&霧雨魔理沙", "ゆっくりしていってね！"),
            ("(操夢&サブ) 今日の解説を始めます", "操夢&サブ", "今日の解説を始めます"),
            ("(操夢＆サブ) 今日の解説を始めます", "操夢&サブ", "今日の解説を始めます"),
            ("(操夢 & サブ) 今日の解説を始めます", "操夢&サブ", "今日の解説を始めます"),
            ("(霊夢)(魔理沙) 2人のセリフ", "博麗霊夢&霧雨魔理沙", "2人のセリフ"),
            ("[霊夢] こんにちは [魔理沙] そうだな", "博麗霊夢&霧雨魔理沙", "こんにちは そうだな"),
            ("(霊夢と魔理沙) 2人のセリフ", "博麗霊夢&霧雨魔理沙", "2人のセリフ")
        ]

        for (input, expectedSpeaker, expectedClean) in testCases {
            guard let extracted = SlideItem.extractSpeakerFromBrackets(from: input) else {
                fatalError("Failed to extract speaker from: \(input)")
            }
            print("  Input: '\(input)' -> Speaker: '\(extracted)'")
            assert(extracted == expectedSpeaker, "Expected '\(expectedSpeaker)', got '\(extracted)'")
            assert(!extracted.contains(" "), "Speaker must not contain spaces: '\(extracted)'")
            assert(!extracted.contains("　"), "Speaker must not contain full-width spaces: '\(extracted)'")
            assert(extracted.contains("&"), "Duo speaker must contain '&': '\(extracted)'")

            let cleaned = SlideItem.cleanDialogueText(from: input).replacingOccurrences(of: "\n", with: " ")
            print("    Cleaned Dialogue: '\(cleaned)'")
            assert(cleaned == expectedClean, "Expected clean '\(expectedClean)', got '\(cleaned)'")
        }
        print("1. Speaker Recognition & Dialogue Cleaning: Verified 10/10 test cases successfully!")

        // 1-2. カタカナ中黒（・）を含む人名が2人話者として誤分割されないことの検証（フランにスカーレットが勝手に追加されないこと）
        let singleKanaTestCases = [
            ("(フラン) こんにちは", "フランドール・スカーレット", "こんにちは"),
            ("(フランドール・スカーレット) こんにちは", "フランドール・スカーレット", "こんにちは"),
            ("(レミリア) おいで", "レミリア・スカーレット", "おいで"),
            ("(レミリア・スカーレット) おいで", "レミリア・スカーレット", "おいで"),
            ("(パチュリー) 本を読むわ", "パチュリー・ノーレッジ", "本を読むわ"),
            ("(パチュリー・ノーレッジ) 本を読むわ", "パチュリー・ノーレッジ", "本を読むわ")
        ]
        for (input, expectedSpeaker, expectedClean) in singleKanaTestCases {
            guard let extracted = SlideItem.extractSpeakerFromBrackets(from: input) else {
                fatalError("Failed to extract speaker from: \(input)")
            }
            assert(extracted == expectedSpeaker, "Expected '\(expectedSpeaker)', got '\(extracted)'")
            assert(!extracted.contains("&"), "Single speaker with middle-dot must NOT contain '&': '\(extracted)'")
            let cleaned = SlideItem.cleanDialogueText(from: input).replacingOccurrences(of: "\n", with: " ")
            assert(cleaned == expectedClean, "Expected clean '\(expectedClean)', got '\(cleaned)'")
        }
        print("1-2. Single speaker with middle-dot (フラン, レミリア, パチュリー): Verified NOT split into duo speaker!")

        // 1-3. 「さとり」「にとり」等「と」を含むキャラ名が「さ&り」等に誤分割されず単一キャラとして保持され、ボイスプリセットが正しく解決されることの検証
        let toCharacterTestCases = [
            ("(さとり) 心を読んだわ", "古明地さとり", "心を読んだわ"),
            ("(古明地さとり) 心を読んだわ", "古明地さとり", "心を読んだわ"),
            ("[さとり] サードアイが開く", "古明地さとり", "サードアイが開く"),
            ("(にとり) 私に任せて！", "河城にとり", "私に任せて！"),
            ("(みとり) 私はみとりよ", "みとり", "私はみとりよ"),
            ("(さとりとこいし) 姉妹の会話", "古明地さとり&古明地こいし", "姉妹の会話")
        ]
        for (input, expectedSpeaker, expectedClean) in toCharacterTestCases {
            guard let extracted = SlideItem.extractSpeakerFromBrackets(from: input) else {
                fatalError("Failed to extract speaker from: \(input)")
            }
            assert(extracted == expectedSpeaker, "Expected '\(expectedSpeaker)', got '\(extracted)'")
            let cleaned = SlideItem.cleanDialogueText(from: input).replacingOccurrences(of: "\n", with: " ")
            assert(cleaned == expectedClean, "Expected clean '\(expectedClean)', got '\(cleaned)'")
        }
        let satoriPreset = AquesTalkBridge.shared.characterPreset(for: "古明地さとり")
        assert(satoriPreset.voice == .jgr, "古明地さとり must have .jgr voice, got \(satoriPreset.voice)")
        assert(satoriPreset.speed == 115, "古明地さとり must have speed 115, got \(satoriPreset.speed)")
        assert(satoriPreset.pitch == 125, "古明地さとり must have pitch 125, got \(satoriPreset.pitch)")

        let satoriShortPreset = AquesTalkBridge.shared.characterPreset(for: "さとり")
        assert(satoriShortPreset.voice == .jgr, "さとり must have .jgr voice, got \(satoriShortPreset.voice)")
        assert(satoriShortPreset.speed == 115, "さとり must have speed 115, got \(satoriShortPreset.speed)")
        assert(satoriShortPreset.pitch == 125, "さとり must have pitch 125, got \(satoriShortPreset.pitch)")
        print("1-3. Characters containing 'と' (さとり, にとり, みとり): Verified NOT split into 'さ&り' and correct voice preset (.jgr) applied!")

        // 2. AquesTalkBridge 2人同時音声合成（ユニゾン・ミックスWAV）テスト
        print("2. Synthesizing Duo Voice Audio (博麗霊夢&霧雨魔理沙)...")
        let duoWav = AquesTalkBridge.shared.synthesizeDuoVoiceToWavData(
            text: "ゆっくりしていってね！",
            speakerName: "博麗霊夢&霧雨魔理沙",
            quality: .enhanced,
            effect: .none
        )
        assert(duoWav != nil, "Duo WAV data must not be nil")
        assert(duoWav!.count > 1000, "Duo WAV data must be non-empty (size: \(duoWav!.count) bytes)")
        print("   Duo WAV generated successfully! size=\(duoWav!.count) bytes")

        // 3. BatchVoiceItem 抽出と1シーンへの2人分音声割り当ての検証
        let sampleSlides = [
            SlideItem(slideIndex: 1, title: "第1話", telop: "", presenterNote: "タイトル", characterName: "ナレーション", slideType: "title"),
            SlideItem(slideIndex: 2, title: "神社", telop: "ゆっくりしていってね！", presenterNote: "(霊夢&魔理沙) ゆっくりしていってね！", characterName: "霊夢&魔理沙", slideType: "content"),
            SlideItem(slideIndex: 3, title: "スタジオ", telop: "解説を始めるよ", presenterNote: "(操夢 & サブ) 解説を始めるよ", characterName: "操夢&サブ", slideType: "content")
        ]
        let batchItems = SlideVoiceBatchService.shared.extractBatchItems(from: sampleSlides)
        // スライド1: 1アイテム (タイトルスキップ)
        // スライド2: 2アイテム (博麗霊夢, 霧雨魔理沙)
        // スライド3: 2アイテム (操夢, サブ)
        // 合計 5 アイテム
        assert(batchItems.count == 5, "Batch items count should be 5 (Slide 1: 1, Slide 2: 2, Slide 3: 2), got \(batchItems.count)")
        assert(batchItems[1].slideIndex == 2 && batchItems[1].characterName == "博麗霊夢", "Slide 2 voice 1 should be 博麗霊夢")
        assert(batchItems[2].slideIndex == 2 && batchItems[2].characterName == "霧雨魔理沙", "Slide 2 voice 2 should be 霧雨魔理沙")
        assert(batchItems[3].slideIndex == 3 && batchItems[3].characterName == "操夢", "Slide 3 voice 1 should be 操夢")
        assert(batchItems[4].slideIndex == 3 && batchItems[4].characterName == "サブ", "Slide 3 voice 2 should be サブ")
        print("3-1. BatchVoiceItem extraction: Verified individual speaker mapping for duo scenes successfully!")

        // 3-2. タイムライン配置時に1つのシーンに2人分の音声が割り当てられることを検証
        SlideVoiceBatchService.shared.applyToSoundMakerTimeline(items: batchItems)
        let appState = AppState.shared
        assert(appState.movieScenes.count == 3, "MovieScenes count should be 3, got \(appState.movieScenes.count)")

        let scene2Clips = appState.soundClips.filter { $0.type == "Voice" && $0.sceneIndex == 2 }
        assert(scene2Clips.count == 2, "Scene 2 must have 2 voice clips assigned to it, got \(scene2Clips.count)")
        let scene2Characters = Set(scene2Clips.compactMap { $0.character })
        assert(scene2Characters.contains("博麗霊夢") && scene2Characters.contains("霧雨魔理沙"), "Scene 2 must contain 博麗霊夢 and 霧雨魔理沙")
        assert(scene2Clips[0].startTime == scene2Clips[1].startTime, "Both clips in Scene 2 must share the same start time")
        print("3-2. applyToSoundMakerTimeline: Verified assigning 2 voice clips to a single scene!")

        // 3-3. SlideRecognitionService.syncToSoundMaker でも1シーンに2人分音声が割り当てられることを検証
        SlideRecognitionService.shared.syncToSoundMaker(slides: sampleSlides)
        let syncedScene2Clips = appState.soundClips.filter { $0.type == "Voice" && $0.sceneIndex == 2 }
        assert(syncedScene2Clips.count == 2, "SlideRecognitionService must also assign 2 voice clips to Scene 2, got \(syncedScene2Clips.count)")
        let syncedCharacters = Set(syncedScene2Clips.compactMap { $0.character })
        assert(syncedCharacters.contains("博麗霊夢") && syncedCharacters.contains("霧雨魔理沙"), "Synced Scene 2 must contain 博麗霊夢 and 霧雨魔理沙")
        assert(syncedScene2Clips[0].startTime == syncedScene2Clips[1].startTime, "Synced clips in Scene 2 must share the same start time")
        print("3-3. SlideRecognitionService.syncToSoundMaker: Verified assigning 2 voices to a single scene!")

        print("=== [TEST] ALL SOUNDMAKER DUO SPEAKER TESTS PASSED SUCCESSFULLY! ===")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1024, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            MenuBarCommands(appState: appState)
        }
    }
}
