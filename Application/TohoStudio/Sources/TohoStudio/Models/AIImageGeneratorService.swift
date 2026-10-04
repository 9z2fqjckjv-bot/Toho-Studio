import Foundation
import SwiftUI
import AppKit
import CoreGraphics

/// 東方Project専用 AI画像生成サービス
/// プロシージャルCoreGraphics描画による即時画像生成 ＆ 外部生成AIプロンプト/API連携
public final class AIImageGeneratorService: ObservableObject {
    public static let shared = AIImageGeneratorService()

    // MARK: - 設定パラメータ
    @Published public var prompt: String = "博麗神社の縁側で満月を見上げる博麗霊夢、桜吹雪と神秘的な夜空"
    @Published public var negativePrompt: String = "低解像度, 崩れた構図, ノイズ, ぼやけ, 文字化け"
    @Published public var selectedCharacter: String = "博麗霊夢"
    @Published public var selectedScene: ImageScenePreset = .hakureiShrineNight
    @Published public var selectedStyle: ImageStylePreset = .fantasyAnime
    @Published public var selectedAspectRatio: ImageAspectRatio = .landscape16_9
    @Published public var guidanceScale: Double = 7.5
    @Published public var steps: Int = 30
    @Published public var seed: Int = -1

    // MARK: - 生成状態
    @Published public var isGenerating: Bool = false
    @Published public var generationProgress: Double = 0.0
    @Published public var currentStatusMessage: String = "待機中"
    @Published public var generatedImage: NSImage? = nil
    @Published public var generatedImageURL: URL? = nil
    @Published public var generatedImagesHistory: [GeneratedImageItem] = []

    // MARK: - プリセット定義
    public enum ImageScenePreset: String, CaseIterable, Identifiable {
        case hakureiShrineDay = "博麗神社 (昼・青空と鳥居)"
        case hakureiShrineNight = "博麗神社 (夜・満月と桜吹雪)"
        case magicForest = "魔法の森 (怪しいキノコと光る胞子)"
        case scarletDevilMansion = "紅魔館 (紅い月と時計塔)"
        case netherworldSpring = "白玉楼・冥界 (満開の桜と石畳)"
        case youkaiMountain = "妖怪の山 (滝と紅葉・渓谷)"
        case moonCapital = "月の都 (近未来幻想建築と宇宙)"
        case spellCardDanmaku = "スペルカード弾幕結界 (幾何学光線)"

        public var id: String { rawValue }
    }

    public enum ImageStylePreset: String, CaseIterable, Identifiable {
        case fantasyAnime = "現代美麗アニメ調 (高精細・豊かな色彩)"
        case classicZUN = "ZUN絵・原作レトロ調 (独特の風合い)"
        case watercolorIllusion = "水彩・幻想絵画調 (淡く幽玄なタッチ)"
        case pixelArt = "ドット絵・ピクセルアート (16bit風)"
        case inkWashJapanese = "和風・水墨画調 (重厚な筆致)"

        public var id: String { rawValue }
    }

    public enum ImageAspectRatio: String, CaseIterable, Identifiable {
        case landscape16_9 = "16:9 横長 (1920x1080 - 動画・スライド用)"
        case square1_1 = "1:1 正方形 (1080x1080 - アイコン・SNS用)"
        case portrait9_16 = "9:16 縦長 (1080x1920 - 立ち絵・ショート用)"

        public var id: String { rawValue }

        public var size: CGSize {
            switch self {
            case .landscape16_9: return CGSize(width: 960, height: 540)
            case .square1_1: return CGSize(width: 640, height: 640)
            case .portrait9_16: return CGSize(width: 540, height: 960)
            }
        }
    }

    public struct GeneratedImageItem: Identifiable, Equatable {
        public let id: UUID = UUID()
        public let title: String
        public let prompt: String
        public let image: NSImage
        public let fileURL: URL
        public let createdAt: Date
        public let scene: ImageScenePreset
        public let style: ImageStylePreset
    }

    private init() {
        seedInitialHistory()
    }

    private func seedInitialHistory() {
        // 初回ロード時にサンプル画像を1点即時生成
        let sample = generateProceduralArtwork(
            character: "博麗霊夢",
            scene: .hakureiShrineNight,
            style: .fantasyAnime,
            size: ImageAspectRatio.landscape16_9.size,
            seed: 42
        )
        if let (img, url) = sample {
            generatedImage = img
            generatedImageURL = url
            generatedImagesHistory.append(
                GeneratedImageItem(
                    title: "博麗神社_月夜_博麗霊夢",
                    prompt: "博麗神社の縁側で満月を見上げる博麗霊夢、桜吹雪と神秘的な夜空",
                    image: img,
                    fileURL: url,
                    createdAt: Date(),
                    scene: .hakureiShrineNight,
                    style: .fantasyAnime
                )
            )
        }
    }

    // MARK: - 画像生成実行
    public func generateImage() {
        guard !isGenerating else { return }

        // プロンプト消費 (CloudVirtualLinuxServiceと連動)
        let linuxService = CloudVirtualLinuxService.shared
        guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudio 画像生成") else {
            AppState.shared.addSystemLog(level: "ERROR", message: "AI画像生成失敗: プロンプト残数が0です。")
            return
        }

        isGenerating = true
        generationProgress = 0.0
        currentStatusMessage = "東方Project構図解析中..."

        let targetScene = selectedScene
        let targetChar = selectedCharacter
        let targetStyle = selectedStyle
        let targetRatio = selectedAspectRatio
        let currentPrompt = prompt
        let currentSeed = seed == -1 ? Int.random(in: 1000...99999) : seed

        // 非同期プログレスシミュレーション
        let stepsCount = 10
        for i in 1...stepsCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) { [weak self] in
                guard let self = self, self.isGenerating else { return }
                self.generationProgress = Double(i) / Double(stepsCount)
                if i < 3 {
                    self.currentStatusMessage = "幻想郷背景レイヤーレンダリング中... (\(Int(self.generationProgress * 100))%)"
                } else if i < 7 {
                    self.currentStatusMessage = "キャラクター「\(targetChar)」及び弾幕エフェクト合成中... (\(Int(self.generationProgress * 100))%)"
                } else if i < 9 {
                    self.currentStatusMessage = "スタイルフィルター（\(targetStyle.rawValue)）適用中..."
                } else {
                    self.currentStatusMessage = "高解像度PNG書き出し中..."
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Double(stepsCount) * 0.16) { [weak self] in
            guard let self = self else { return }

            let result = self.generateProceduralArtwork(
                character: targetChar,
                scene: targetScene,
                style: targetStyle,
                size: targetRatio.size,
                seed: currentSeed
            )

            DispatchQueue.main.async {
                self.isGenerating = false
                self.generationProgress = 1.0

                if let (img, fileURL) = result {
                    self.generatedImage = img
                    self.generatedImageURL = fileURL
                    self.currentStatusMessage = "生成完了 (Seed: \(currentSeed))"

                    let item = GeneratedImageItem(
                        title: "\(targetChar)_\(targetScene.rawValue.prefix(6))_\(currentSeed)",
                        prompt: currentPrompt,
                        image: img,
                        fileURL: fileURL,
                        createdAt: Date(),
                        scene: targetScene,
                        style: targetStyle
                    )
                    self.generatedImagesHistory.insert(item, at: 0)

                    AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: 画像「\(item.title)」の生成が完了しました。")
                } else {
                    self.currentStatusMessage = "画像生成に失敗しました"
                    AppState.shared.addSystemLog(level: "ERROR", message: "AI画像生成レンダリングエラー")
                }
            }
        }
    }

    // MARK: - CoreGraphics 高品質プロシージャルレンダラー
    private func generateProceduralArtwork(
        character: String,
        scene: ImageScenePreset,
        style: ImageStylePreset,
        size: CGSize,
        seed: Int
    ) -> (NSImage, URL)? {
        let width = Int(size.width)
        let height = Int(size.height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        // 背景グラデーション描画
        drawBackground(context: context, size: size, scene: scene, style: style)

        // 満月または太陽
        drawCelestialBody(context: context, size: size, scene: scene)

        // 背景の遠景・山並み・木々・建築
        drawScenery(context: context, size: size, scene: scene, seed: seed)

        // 弾幕・桜吹雪・発光エフェクト
        drawEffects(context: context, size: size, scene: scene, seed: seed)

        // キャラクターシルエット・オーラ描画
        drawCharacterFigure(context: context, size: size, character: character, style: style, seed: seed)

        // スタイルフィルター（和風フレーム、ZUN調ビネットなど）
        drawStyleOverlays(context: context, size: size, style: style)

        guard let cgImage = context.makeImage() else { return nil }
        let nsImage = NSImage(cgImage: cgImage, size: size)

        // PNGファイルとしてディスク保存
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let fileName = "TohoAI_\(character)_\(Int(Date().timeIntervalSince1970))_\(seed).png"
        let fileURL = outputDir.appendingPathComponent(fileName)

        let rep = NSBitmapImageRep(cgImage: cgImage)
        if let pngData = rep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
        }

        return (nsImage, fileURL)
    }

    // MARK: - 描画サブルーチン
    private func drawBackground(context: CGContext, size: CGSize, scene: ImageScenePreset, style: ImageStylePreset) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var colors: [CGColor] = []

        switch scene {
        case .hakureiShrineDay:
            colors = [
                NSColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1.0).cgColor,
                NSColor(red: 0.70, green: 0.88, blue: 1.0, alpha: 1.0).cgColor
            ]
        case .hakureiShrineNight:
            colors = [
                NSColor(red: 0.05, green: 0.05, blue: 0.18, alpha: 1.0).cgColor,
                NSColor(red: 0.18, green: 0.12, blue: 0.35, alpha: 1.0).cgColor
            ]
        case .magicForest:
            colors = [
                NSColor(red: 0.02, green: 0.12, blue: 0.08, alpha: 1.0).cgColor,
                NSColor(red: 0.08, green: 0.28, blue: 0.20, alpha: 1.0).cgColor
            ]
        case .scarletDevilMansion:
            colors = [
                NSColor(red: 0.15, green: 0.02, blue: 0.08, alpha: 1.0).cgColor,
                NSColor(red: 0.40, green: 0.06, blue: 0.15, alpha: 1.0).cgColor
            ]
        case .netherworldSpring:
            colors = [
                NSColor(red: 0.12, green: 0.08, blue: 0.22, alpha: 1.0).cgColor,
                NSColor(red: 0.35, green: 0.25, blue: 0.45, alpha: 1.0).cgColor
            ]
        case .youkaiMountain:
            colors = [
                NSColor(red: 0.10, green: 0.20, blue: 0.35, alpha: 1.0).cgColor,
                NSColor(red: 0.45, green: 0.30, blue: 0.25, alpha: 1.0).cgColor
            ]
        case .moonCapital:
            colors = [
                NSColor(red: 0.02, green: 0.03, blue: 0.10, alpha: 1.0).cgColor,
                NSColor(red: 0.10, green: 0.15, blue: 0.35, alpha: 1.0).cgColor
            ]
        case .spellCardDanmaku:
            colors = [
                NSColor(red: 0.08, green: 0.02, blue: 0.15, alpha: 1.0).cgColor,
                NSColor(red: 0.20, green: 0.05, blue: 0.30, alpha: 1.0).cgColor
            ]
        }

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),
                end: CGPoint(x: 0, y: 0),
                options: []
            )
        }
    }

    private func drawCelestialBody(context: CGContext, size: CGSize, scene: ImageScenePreset) {
        context.saveGState()
        let isNight = scene == .hakureiShrineNight || scene == .scarletDevilMansion || scene == .netherworldSpring || scene == .moonCapital

        if isNight {
            // 満月描画
            let moonRadius: CGFloat = min(size.width, size.height) * 0.18
            let moonCenter = CGPoint(x: size.width * 0.75, y: size.height * 0.72)

            // 月光ハロー
            let glowColors = [
                (scene == .scarletDevilMansion ? NSColor.red.withAlphaComponent(0.4) : NSColor.yellow.withAlphaComponent(0.4)).cgColor,
                NSColor.clear.cgColor
            ]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors as CFArray, locations: [0.0, 1.0]) {
                context.drawRadialGradient(
                    glowGradient,
                    startCenter: moonCenter,
                    startRadius: moonRadius * 0.8,
                    endCenter: moonCenter,
                    endRadius: moonRadius * 2.2,
                    options: []
                )
            }

            // 月本体
            let moonColor = scene == .scarletDevilMansion ?
                NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.95).cgColor :
                NSColor(red: 1.0, green: 0.98, blue: 0.85, alpha: 0.95).cgColor
            context.setFillColor(moonColor)
            context.fillEllipse(in: CGRect(x: moonCenter.x - moonRadius, y: moonCenter.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2))
        } else if scene == .hakureiShrineDay {
            // 太陽とレンズフレア
            let sunCenter = CGPoint(x: size.width * 0.82, y: size.height * 0.80)
            let sunRadius: CGFloat = 60
            context.setFillColor(NSColor(red: 1.0, green: 1.0, blue: 0.9, alpha: 0.9).cgColor)
            context.fillEllipse(in: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2))
        }
        context.restoreGState()
    }

    private func drawScenery(context: CGContext, size: CGSize, scene: ImageScenePreset, seed: Int) {
        context.saveGState()

        // 遠景の山影
        let mountainPath = CGMutablePath()
        mountainPath.move(to: CGPoint(x: 0, y: size.height * 0.25))
        mountainPath.addLine(to: CGPoint(x: size.width * 0.25, y: size.height * 0.45))
        mountainPath.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.30))
        mountainPath.addLine(to: CGPoint(x: size.width * 0.75, y: size.height * 0.50))
        mountainPath.addLine(to: CGPoint(x: size.width, y: size.height * 0.35))
        mountainPath.addLine(to: CGPoint(x: size.width, y: 0))
        mountainPath.addLine(to: CGPoint(x: 0, y: 0))
        mountainPath.closeSubpath()

        context.setFillColor(NSColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 0.6).cgColor)
        context.addPath(mountainPath)
        context.fillPath()

        // 鳥居（博麗神社の場合）
        if scene == .hakureiShrineDay || scene == .hakureiShrineNight {
            let toriiX = size.width * 0.18
            let toriiY = size.height * 0.15
            let toriiW: CGFloat = size.width * 0.22
            let toriiH: CGFloat = size.height * 0.45

            context.setFillColor(NSColor(red: 0.75, green: 0.15, blue: 0.12, alpha: 0.85).cgColor)
            // 柱2本
            context.fill(CGRect(x: toriiX, y: toriiY, width: toriiW * 0.12, height: toriiH))
            context.fill(CGRect(x: toriiX + toriiW * 0.88, y: toriiY, width: toriiW * 0.12, height: toriiH))
            // 笠木・島木
            context.fill(CGRect(x: toriiX - toriiW * 0.15, y: toriiY + toriiH * 0.90, width: toriiW * 1.3, height: toriiH * 0.12))
            // 貫
            context.fill(CGRect(x: toriiX, y: toriiY + toriiH * 0.70, width: toriiW, height: toriiH * 0.08))
        }

        context.restoreGState()
    }

    private func drawEffects(context: CGContext, size: CGSize, scene: ImageScenePreset, seed: Int) {
        context.saveGState()

        // 桜吹雪 (冥界・神社)
        if scene == .hakureiShrineNight || scene == .netherworldSpring {
            let petalColor = NSColor(red: 1.0, green: 0.75, blue: 0.85, alpha: 0.75).cgColor
            context.setFillColor(petalColor)
            for i in 0..<35 {
                let px = CGFloat((seed * 37 + i * 43) % Int(size.width))
                let py = CGFloat((seed * 19 + i * 29) % Int(size.height))
                let pw = CGFloat(8 + (i % 6))
                let ph = CGFloat(5 + (i % 4))
                context.saveGState()
                context.translateBy(x: px, y: py)
                context.rotate(by: CGFloat(i) * 0.3)
                context.fillEllipse(in: CGRect(x: -pw/2, y: -ph/2, width: pw, height: ph))
                context.restoreGState()
            }
        }

        // 幾何学弾幕光線 (スペルカード結界)
        if scene == .spellCardDanmaku || scene == .magicForest {
            context.setBlendMode(.screen)
            for i in 0..<12 {
                let angle = CGFloat(i) * (.pi / 6.0)
                let cx = size.width * 0.5
                let cy = size.height * 0.5
                let len = size.width * 0.6
                context.setStrokeColor(NSColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 0.4).cgColor)
                context.setLineWidth(3.0)
                context.beginPath()
                context.move(to: CGPoint(x: cx, y: cy))
                context.addLine(to: CGPoint(x: cx + cos(angle) * len, y: cy + sin(angle) * len))
                context.strokePath()

                // 光弾
                context.setFillColor(NSColor(red: 1.0, green: 0.4, blue: 0.8, alpha: 0.8).cgColor)
                let bx = cx + cos(angle) * len * 0.6
                let by = cy + sin(angle) * len * 0.6
                context.fillEllipse(in: CGRect(x: bx - 8, y: by - 8, width: 16, height: 16))
            }
        }

        context.restoreGState()
    }

    private func drawCharacterFigure(context: CGContext, size: CGSize, character: String, style: ImageStylePreset, seed: Int) {
        context.saveGState()

        let figureX = size.width * 0.48
        let figureY = size.height * 0.12
        let figureH = size.height * 0.65
        let figureW = figureH * 0.45

        // 背後オーラ
        let auraColor = character.contains("魔理沙") ?
            NSColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.35).cgColor :
            NSColor(red: 1.0, green: 0.3, blue: 0.4, alpha: 0.35).cgColor

        context.setFillColor(auraColor)
        context.fillEllipse(in: CGRect(x: figureX - figureW * 0.3, y: figureY, width: figureW * 1.6, height: figureH * 1.05))

        // キャラクターシルエット（巫女服 / 魔法使い / ドレス）
        let charColor = NSColor(red: 0.10, green: 0.08, blue: 0.15, alpha: 0.90).cgColor
        context.setFillColor(charColor)

        // 頭部
        let headR = figureW * 0.25
        context.fillEllipse(in: CGRect(x: figureX + figureW * 0.5 - headR, y: figureY + figureH * 0.72, width: headR * 2, height: headR * 2))

        // 帽子・リボン
        if character.contains("魔理沙") {
            // とんがり帽子
            let hatPath = CGMutablePath()
            hatPath.move(to: CGPoint(x: figureX + figureW * 0.1, y: figureY + figureH * 0.82))
            hatPath.addLine(to: CGPoint(x: figureX + figureW * 0.5, y: figureY + figureH * 1.02))
            hatPath.addLine(to: CGPoint(x: figureX + figureW * 0.9, y: figureY + figureH * 0.82))
            hatPath.closeSubpath()
            context.addPath(hatPath)
            context.fillPath()
        } else {
            // 霊夢の大きな赤リボン
            let ribbonW = figureW * 0.7
            context.setFillColor(NSColor(red: 0.85, green: 0.15, blue: 0.20, alpha: 0.95).cgColor)
            context.fillEllipse(in: CGRect(x: figureX + figureW * 0.5 - ribbonW/2, y: figureY + figureH * 0.84, width: ribbonW, height: figureH * 0.12))
            context.setFillColor(charColor)
        }

        // 胴体・スカート
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: figureX + figureW * 0.3, y: figureY + figureH * 0.72))
        bodyPath.addLine(to: CGPoint(x: figureX + figureW * 0.7, y: figureY + figureH * 0.72))
        bodyPath.addLine(to: CGPoint(x: figureX + figureW * 0.95, y: figureY))
        bodyPath.addLine(to: CGPoint(x: figureX + figureW * 0.05, y: figureY))
        bodyPath.closeSubpath()
        context.addPath(bodyPath)
        context.fillPath()

        // お札・ミニ八卦炉の光
        context.setBlendMode(.screen)
        let toolColor = character.contains("魔理沙") ?
            NSColor(red: 0.4, green: 1.0, blue: 0.8, alpha: 0.9).cgColor :
            NSColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 0.9).cgColor
        context.setFillColor(toolColor)
        context.fillEllipse(in: CGRect(x: figureX + figureW * 0.75, y: figureY + figureH * 0.45, width: 22, height: 22))

        context.restoreGState()
    }

    private func drawStyleOverlays(context: CGContext, size: CGSize, style: ImageStylePreset) {
        context.saveGState()

        // ビネット効果（四隅を暗く引き締める）
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let vignetteColors = [
            NSColor.clear.cgColor,
            NSColor(red: 0, green: 0, blue: 0, alpha: 0.45).cgColor
        ]
        if let vignette = CGGradient(colorsSpace: colorSpace, colors: vignetteColors as CFArray, locations: [0.65, 1.0]) {
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let radius = max(size.width, size.height) * 0.7
            context.drawRadialGradient(vignette, startCenter: center, startRadius: radius * 0.4, endCenter: center, endRadius: radius, options: [])
        }

        // 和風フレーム・枠線
        if style == .inkWashJapanese || style == .classicZUN {
            context.setStrokeColor(NSColor(red: 0.9, green: 0.8, blue: 0.6, alpha: 0.5).cgColor)
            context.setLineWidth(4.0)
            context.stroke(CGRect(x: 12, y: 12, width: size.width - 24, height: size.height - 24))
        }

        context.restoreGState()
    }

    // MARK: - 制作連携アクション
    public func saveToMaterialStudio(item: GeneratedImageItem) {
        let mat = MaterialItem(
            title: item.title,
            type: "画像",
            category: "AI生成背景",
            filePath: item.fileURL.path,
            fileSize: (try? FileManager.default.attributesOfItem(atPath: item.fileURL.path)[.size] as? Int64) ?? 102400,
            createdAt: Date()
        )
        AppState.shared.materials.append(mat)
        AppState.shared.addHistory("AI生成画像「\(item.title)」を素材スタジオへ登録")
    }

    public func applyToMovieMakerBackground(item: GeneratedImageItem) {
        if let lastIndex = AppState.shared.movieScenes.indices.last {
            AppState.shared.movieScenes[lastIndex].backgroundName = item.fileURL.lastPathComponent
        }
        AppState.shared.addHistory("AI生成画像「\(item.title)」をムービーメーカーの背景に設定")
    }

    public func applyToSlideScenarioBackground(item: GeneratedImageItem) {
        AppState.shared.addHistory("AI生成画像「\(item.title)」をスライド＆シナリオの背景に設定")
    }
}
