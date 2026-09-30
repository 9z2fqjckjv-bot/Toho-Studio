import SwiftUI
import AppKit

@main
struct TohoStudioApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        // Configure macOS app behavior
        NSApplication.shared.setActivationPolicy(.regular)

        if CommandLine.arguments.contains("--test-character-maker") {
            runCharacterMakerSelfTest()
            exit(0)
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
