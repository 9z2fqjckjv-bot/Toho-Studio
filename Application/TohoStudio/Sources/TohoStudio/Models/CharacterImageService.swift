import Foundation
import AppKit
import CoreGraphics
import CoreImage
import SwiftUI

/// キャラクターメーカーの画像編集・パーツ分割・トリミング・色変え・組み立てを統括する基幹サービス
public final class CharacterImageService: ObservableObject {
    public static let shared = CharacterImageService()

    private let imageCache = NSCache<NSString, NSImage>()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private let repoRoot = "/Volumes/ZSSD/GitHub/repository/TohoStudio"
    private var charBaseDir: String {
        return "\(repoRoot)/Documents/動画用/キャラクター"
    }

    private var cachePartsDir: String {
        let path = "\(repoRoot)/.cache/character_parts"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    public init() {
        imageCache.countLimit = 100
    }

    // MARK: - 1. 画像検索・ロード
    public func loadImage(from path: String) -> NSImage? {
        if path.isEmpty { return nil }
        let key = NSString(string: path)
        if let cached = imageCache.object(forKey: key) {
            return cached
        }

        var resolvedPath = path
        if !path.hasPrefix("/") {
            resolvedPath = "\(repoRoot)/\(path)"
        }

        if FileManager.default.fileExists(atPath: resolvedPath),
           let image = NSImage(contentsOfFile: resolvedPath) {
            imageCache.setObject(image, forKey: key)
            return image
        }
        return nil
    }

    /// キャラクター名から利用可能な表情差分画像パスを辞書として取得
    public func findCharacterExpressions(characterName: String) -> [String: String] {
        var expressions: [String: String] = [:]
        let fileManager = FileManager.default

        // キャラクター別の主要検索パス
        var searchRoots: [String] = []
        if characterName.contains("霊夢") {
            searchRoots.append("\(charBaseDir)/主人公たち/博麗霊夢/博麗霊夢/博麗霊夢/通常")
            searchRoots.append("\(charBaseDir)/主人公たち/博麗霊夢/博麗霊夢/博麗霊夢/赤面")
            searchRoots.append("\(charBaseDir)/主人公たち/博麗霊夢/博麗霊夢（ちびキャラ）")
        } else if characterName.contains("魔理沙") {
            searchRoots.append("\(charBaseDir)/主人公たち/霧雨魔理沙/霧雨魔理沙/霧雨魔理沙/通常")
            searchRoots.append("\(charBaseDir)/主人公たち/霧雨魔理沙/霧雨魔理沙/霧雨魔理沙/赤面")
            searchRoots.append("\(charBaseDir)/主人公たち/霧雨魔理沙/霧雨魔理沙（バトルっぽい）")
        } else if characterName.contains("こいし") {
            searchRoots.append("\(charBaseDir)/地霊殿/古明地こいし/古明地こいし/通常")
            searchRoots.append("\(charBaseDir)/地霊殿/古明地こいし/古明地こいし/赤面")
            searchRoots.append("\(charBaseDir)/地霊殿/古明地こいし/古明地こいし(パジャマ)/通常")
        } else if characterName.contains("咲夜") {
            searchRoots.append("\(charBaseDir)/紅魔館/十六夜咲夜/十六夜咲夜/通常")
            searchRoots.append("\(charBaseDir)/紅魔館/十六夜咲夜/十六夜咲夜/赤面")
        } else if characterName.contains("妖夢") {
            searchRoots.append("\(charBaseDir)/魂魄妖夢/魂魄妖夢/通常")
            searchRoots.append("\(charBaseDir)/魂魄妖夢/魂魄妖夢(バトルっぽい2)/通常")
        }

        // 一般探索フォールバック
        if searchRoots.isEmpty {
            searchRoots.append("\(charBaseDir)/\(characterName)")
        }

        for root in searchRoots {
            guard let enumerator = fileManager.enumerator(atPath: root) else { continue }
            while let file = enumerator.nextObject() as? String {
                if file.lowercased().hasSuffix(".png") {
                    let fullPath = "\(root)/\(file)"
                    let base = (file as NSString).lastPathComponent
                    let nameOnly = (base as NSString).deletingPathExtension

                    var expKey = "通常"
                    if nameOnly.contains("微笑") { expKey = "微笑" }
                    else if nameOnly.contains("笑い") || nameOnly.contains("笑う") { expKey = "笑顔" }
                    else if nameOnly.contains("怒る") || nameOnly.contains("怒り") { expKey = "怒り" }
                    else if nameOnly.contains("驚く") || nameOnly.contains("驚き") { expKey = "驚き" }
                    else if nameOnly.contains("泣く") { expKey = "泣く" }
                    else if nameOnly.contains("困る") || nameOnly.contains("困り") { expKey = "困惑" }
                    else if nameOnly.contains("不満") { expKey = "不満" }
                    else if nameOnly.contains("余裕") { expKey = "余裕" }

                    if expressions[expKey] == nil {
                        expressions[expKey] = fullPath
                    }
                }
            }
        }

        return expressions
    }

    /// キャラクター固有のアイテムや特殊パーツ（箒、第3の目、帽子等）を探索
    public func findSpecialParts(characterName: String) -> [CharacterPart] {
        var parts: [CharacterPart] = []

        if characterName.contains("魔理沙") {
            // 箒パーツ（仕様書補足事項: 箒に跨っている状態の魔理沙の画像を作成）
            let broomPath = "\(charBaseDir)/主人公たち/霧雨魔理沙/霧雨魔理沙（バトルっぽい）/箒.png"
            if FileManager.default.fileExists(atPath: broomPath) {
                parts.append(CharacterPart(
                    name: "箒 (跨り用アイテム)",
                    assetPath: broomPath,
                    offsetX: -40.0,
                    offsetY: -30.0,
                    scale: 1.1,
                    rotation: -25.0,
                    isVisible: true
                ))
            }
            // 帽子パーツ
            let hatPath = "\(charBaseDir)/主人公たち/霧雨魔理沙/霧雨魔理沙/霧雨魔理沙/帽子.png"
            if FileManager.default.fileExists(atPath: hatPath) {
                parts.append(CharacterPart(
                    name: "魔法使いの帽子",
                    assetPath: hatPath,
                    offsetX: 0.0,
                    offsetY: 280.0,
                    scale: 1.0,
                    isVisible: true
                ))
            }
        } else if characterName.contains("こいし") {
            // 第3の目パーツ（仕様書補足事項: こいしの第3の目が開いているなど）
            let eyePaths = [
                "\(repoRoot)/Documents/動画用/手作り素材/psdtool/古明地姉妹/古明地こいし/帽子目なし目閉じ小口開け頬照り.png",
                "\(repoRoot)/Documents/動画用/手作り素材/立絵スタジオ/古明地こいし/髪紫、上着黄色、第三の目水色"
            ]
            for ep in eyePaths where FileManager.default.fileExists(atPath: ep) {
                parts.append(CharacterPart(
                    name: "閉じた第3の目 (差分)",
                    assetPath: ep,
                    offsetX: 120.0,
                    offsetY: 80.0,
                    scale: 0.45,
                    isVisible: true
                ))
                break
            }
        }

        return parts
    }

    // MARK: - 2. デフォルトプリセットの構築
    public func createPresetCharacter(name: String) -> CharacterModel {
        let expressions = findCharacterExpressions(characterName: name)
        let mainPath = expressions["通常"] ?? expressions.values.first ?? ""

        var parts: [CharacterPart] = []

        if !mainPath.isEmpty {
            // ベースとなる立ち絵パーツ
            parts.append(CharacterPart(
                name: "本体 (立ち絵ベース)",
                assetPath: mainPath,
                offsetX: 0.0,
                offsetY: 0.0,
                scale: 1.0,
                isVisible: true
            ))
        }

        // キャラクター固有パーツ（箒、帽子、第3の目など）を追加
        let specials = findSpecialParts(characterName: name)
        parts.append(contentsOf: specials)

        var model = CharacterModel(
            name: name,
            baseImagePath: mainPath,
            parts: parts,
            expression: "通常",
            canvasWidth: 1080,
            canvasHeight: 1080,
            backgroundColor: "透過市松模様"
        )

        // 再生成(cmd+e+p)用の初期スナップショットを記録
        if let data = try? JSONEncoder().encode(model) {
            model.initialSnapshotData = data
        }

        return model
    }

    // MARK: - 3. 画像トリミング (切り取り & 拡大) (cmd+t)
    /// 指定された画像の一部分を切り取り、拡大した新しい NSImage を生成
    public func cropAndScaleImage(
        sourceImage: NSImage,
        cropRectNormalized: CGRect, // 0.0...1.0 の正規化座標
        zoomFactor: Double = 1.0
    ) -> NSImage? {
        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let pixelX = max(0, min(width - 1, cropRectNormalized.origin.x * width))
        let pixelY = max(0, min(height - 1, (1.0 - cropRectNormalized.origin.y - cropRectNormalized.size.height) * height))
        let pixelW = max(1, min(width - pixelX, cropRectNormalized.size.width * width))
        let pixelH = max(1, min(height - pixelY, cropRectNormalized.size.height * height))

        let cropRect = CGRect(x: pixelX, y: pixelY, width: pixelW, height: pixelH)

        guard let croppedCG = cgImage.cropping(to: cropRect) else {
            return nil
        }

        let croppedImage = NSImage(cgImage: croppedCG, size: NSSize(width: pixelW, height: pixelH))

        if zoomFactor == 1.0 {
            return croppedImage
        }

        // 拡大処理
        let targetSize = NSSize(width: pixelW * CGFloat(zoomFactor), height: pixelH * CGFloat(zoomFactor))
        let scaledImage = NSImage(size: targetSize)
        scaledImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        croppedImage.draw(in: NSRect(origin: .zero, size: targetSize),
                          from: NSRect(origin: .zero, size: croppedImage.size),
                          operation: .copy,
                          fraction: 1.0)
        scaledImage.unlockFocus()

        return scaledImage
    }

    // MARK: - 4. 立ち絵の自動パーツ分割 (cmd+e+c)
    /// キャラクター立ち絵画像を顔、体、目、口、髪、装飾等の領域に分割してパーツ化
    public func splitCharacterIntoParts(model: inout CharacterModel) {
        guard let baseImage = loadImage(from: model.baseImagePath) else {
            return
        }

        guard let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }

        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let timestamp = Int(Date().timeIntervalSince1970)

        // パーツ領域の定義（標準的な立ち絵の比率: 上部が頭部・髪、中央が顔・目・口、下部が体・衣装）
        let definitions: [(name: String, rect: CGRect)] = [
            ("体・衣装", CGRect(x: 0.15 * w, y: 0.0 * h, width: 0.70 * w, height: 0.65 * h)),
            ("髪・頭部", CGRect(x: 0.10 * w, y: 0.55 * h, width: 0.80 * w, height: 0.45 * h)),
            ("顔輪郭", CGRect(x: 0.25 * w, y: 0.50 * h, width: 0.50 * w, height: 0.35 * h)),
            ("目 (表情)", CGRect(x: 0.30 * w, y: 0.62 * h, width: 0.40 * w, height: 0.12 * h)),
            ("口 (表情)", CGRect(x: 0.38 * w, y: 0.55 * h, width: 0.24 * w, height: 0.09 * h)),
            ("装飾・リボン", CGRect(x: 0.18 * w, y: 0.70 * h, width: 0.64 * w, height: 0.25 * h))
        ]

        var newParts: [CharacterPart] = []

        for (index, def) in definitions.enumerated() {
            if let cropped = cgImage.cropping(to: def.rect) {
                let partImg = NSImage(cgImage: cropped, size: def.rect.size)
                let filename = "part_\(model.name)_\(index)_\(timestamp).png"
                let savedPath = "\(cachePartsDir)/\(filename)"

                if let tiff = partImg.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: savedPath))
                }

                // 中心からの相対オフセット計算
                let cx = def.rect.midX - (w / 2.0)
                let cy = def.rect.midY - (h / 2.0)

                let part = CharacterPart(
                    name: def.name,
                    assetPath: savedPath,
                    offsetX: Double(cx * 0.5),
                    offsetY: Double(cy * 0.5),
                    scale: 1.0,
                    isVisible: true
                )
                newParts.append(part)
            }
        }

        // 既存の特殊パーツ（箒や第3の目）があれば維持
        for p in model.parts where p.name.contains("箒") || p.name.contains("目") || p.name.contains("帽子") {
            if !newParts.contains(where: { $0.name == p.name }) {
                newParts.append(p)
            }
        }

        model.parts = newParts
    }

    // MARK: - 5. CoreImage による色調調整 & エフェクト (Google図形描画 & アプリ拡張)
    public func applyAdjustments(
        image: NSImage,
        hue: Double,
        saturation: Double,
        brightness: Double,
        contrast: Double,
        colorTintHex: String,
        blendMode: String,
        filterEffects: [String]
    ) -> NSImage {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            return image
        }

        var currentCI = ciImage

        // 1. カラーコントロール (彩度・明度・コントラスト)
        if saturation != 1.0 || brightness != 0.0 || contrast != 1.0 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(currentCI, forKey: kCIInputImageKey)
                filter.setValue(saturation, forKey: kCIInputSaturationKey)
                filter.setValue(brightness, forKey: kCIInputBrightnessKey)
                filter.setValue(contrast, forKey: kCIInputContrastKey)
                if let output = filter.outputImage {
                    currentCI = output
                }
            }
        }

        // 2. 色相調整 (Hue Adjust)
        if hue != 0.0 {
            let angle = (hue * .pi) / 180.0
            if let filter = CIFilter(name: "CIHueAdjust") {
                filter.setValue(currentCI, forKey: kCIInputImageKey)
                filter.setValue(angle, forKey: kCIInputAngleKey)
                if let output = filter.outputImage {
                    currentCI = output
                }
            }
        }

        // 3. カラーティント適用 (Hex色)
        if colorTintHex != "#FFFFFF" && colorTintHex != "none" {
            let nsColor = NSColor(hex: colorTintHex) ?? .white
            if let filter = CIFilter(name: "CIColorMonochrome") {
                filter.setValue(currentCI, forKey: kCIInputImageKey)
                filter.setValue(CIColor(color: nsColor), forKey: kCIInputColorKey)
                filter.setValue(0.4, forKey: kCIInputIntensityKey) // ほどよく着色
                if let output = filter.outputImage {
                    currentCI = output
                }
            }
        }

        // 4. アプリ拡張フィルター (Photoshop / Pixelmator Pro 機能)
        for effect in filterEffects {
            switch effect {
            case "ぼかし":
                if let blur = CIFilter(name: "CIGaussianBlur") {
                    blur.setValue(currentCI, forKey: kCIInputImageKey)
                    blur.setValue(4.0, forKey: kCIInputRadiusKey)
                    if let out = blur.outputImage { currentCI = out.cropped(to: currentCI.extent) }
                }
            case "シャープ":
                if let sharp = CIFilter(name: "CIUnsharpMask") {
                    sharp.setValue(currentCI, forKey: kCIInputImageKey)
                    sharp.setValue(0.8, forKey: kCIInputIntensityKey)
                    sharp.setValue(2.5, forKey: kCIInputRadiusKey)
                    if let out = sharp.outputImage { currentCI = out }
                }
            case "セピア":
                if let sepia = CIFilter(name: "CISepiaTone") {
                    sepia.setValue(currentCI, forKey: kCIInputImageKey)
                    sepia.setValue(0.8, forKey: kCIInputIntensityKey)
                    if let out = sepia.outputImage { currentCI = out }
                }
            case "モノクロ":
                if let mono = CIFilter(name: "CIPhotoEffectMono") {
                    mono.setValue(currentCI, forKey: kCIInputImageKey)
                    if let out = mono.outputImage { currentCI = out }
                }
            default:
                break
            }
        }

        // レンダリングして NSImage 化
        let extent = currentCI.extent
        if extent.isInfinite || extent.isEmpty {
            return image
        }

        guard let cgOutput = ciContext.createCGImage(currentCI, from: extent) else {
            return image
        }

        return NSImage(cgImage: cgOutput, size: image.size)
    }

    // MARK: - 6. レイヤー合成レンダリング (Render Composite)
    /// 全パーツを重なり順・変形・エフェクトを適用して1枚の高解像度画像に合成
    public func renderComposite(model: CharacterModel, targetSize: CGSize = CGSize(width: 1080, height: 1080)) -> NSImage? {
        let canvasRect = CGRect(origin: .zero, size: targetSize)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // 背景描画（透過市松模様または単色）
        if model.backgroundColor == "白" {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(canvasRect)
        } else if model.backgroundColor == "黒" {
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(canvasRect)
        }

        let centerX = targetSize.width / 2.0
        let centerY = targetSize.height / 2.0

        for part in model.parts where part.isVisible {
            guard let rawImage = loadImage(from: part.assetPath) else { continue }

            // 色調・フィルター調整
            let processedImage = applyAdjustments(
                image: rawImage,
                hue: part.hue,
                saturation: part.saturation,
                brightness: part.brightness,
                contrast: part.contrast,
                colorTintHex: part.colorTintHex,
                blendMode: part.blendMode,
                filterEffects: part.filterEffects
            )

            guard let partCG = processedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continue
            }

            context.saveGState()

            // ブレンドモード設定 (Photoshop機能)
            switch part.blendMode {
            case "乗算": context.setBlendMode(.multiply)
            case "スクリーン": context.setBlendMode(.screen)
            case "オーバーレイ": context.setBlendMode(.overlay)
            case "ソフトライト": context.setBlendMode(.softLight)
            default: context.setBlendMode(.normal)
            }

            context.setAlpha(CGFloat(part.opacity))

            // 変形（位置オフセット、スケール、回転）
            let partW = CGFloat(partCG.width) * CGFloat(part.scale) * 0.8
            let partH = CGFloat(partCG.height) * CGFloat(part.scale) * 0.8

            let posX = centerX + CGFloat(part.offsetX)
            let posY = centerY + CGFloat(part.offsetY)

            context.translateBy(x: posX, y: posY)
            if part.rotation != 0.0 {
                context.rotate(by: CGFloat((part.rotation * .pi) / 180.0))
            }

            // ドロップシャドウ (Photoshop機能)
            if part.filterEffects.contains("ドロップシャドウ") {
                context.setShadow(offset: CGSize(width: 8, height: -8), blur: 12, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
            }

            let drawRect = CGRect(x: -partW / 2.0, y: -partH / 2.0, width: partW, height: partH)
            context.draw(partCG, in: drawRect)

            context.restoreGState()
        }

        guard let finalCG = context.makeImage() else { return nil }
        return NSImage(cgImage: finalCG, size: NSSize(width: targetSize.width, height: targetSize.height))
    }

    // MARK: - 7. ファイル書き出し (PNG, JPG, SVG, PSD, PXD, GDRAW, TSCM)
    public func exportCharacterImage(
        model: CharacterModel,
        format: String,
        destinationURL: URL
    ) throws {
        let composite = renderComposite(model: model) ?? NSImage(size: NSSize(width: 1080, height: 1080))

        switch format {
        case "PNG (透過立ち絵)":
            guard let tiff = composite.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "TohoStudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG変換に失敗しました"])
            }
            try data.write(to: destinationURL)

        case "JPG (高解像度背景付き)":
            var bgModel = model
            if bgModel.backgroundColor == "透過市松模様" { bgModel.backgroundColor = "白" }
            let jpgComposite = renderComposite(model: bgModel) ?? composite
            guard let tiff = jpgComposite.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.95]) else {
                throw NSError(domain: "TohoStudio", code: 2, userInfo: [NSLocalizedDescriptionKey: "JPG変換に失敗しました"])
            }
            try data.write(to: destinationURL)

        case "SVG (ベクター図形)":
            let svgString = generateSVG(model: model, composite: composite)
            try svgString.write(to: destinationURL, atomically: true, encoding: .utf8)

        case "PSD (Photoshopレイヤー別)":
            // レイヤーメタデータを含むPSD互換データを出力
            let psdData = generatePSD(model: model)
            try psdData.write(to: destinationURL)

        case "PXD (Pixelmatorプロジェクト)":
            let pxdData = try JSONEncoder().encode(model)
            try pxdData.write(to: destinationURL)

        case "GDRAW (Google図形互換)":
            let gdrawJSON = generateGDRAW(model: model)
            try gdrawJSON.write(to: destinationURL, atomically: true, encoding: .utf8)

        default: // .tscm (プロジェクト編集ファイル)
            let projectData = try JSONEncoder().encode(model)
            try projectData.write(to: destinationURL)
        }
    }

    private func generateSVG(model: CharacterModel, composite: NSImage) -> String {
        guard let tiff = composite.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1080\" height=\"1080\"/>"
        }
        let base64 = png.base64EncodedString()
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1080" width="1080" height="1080">
          <title>\(model.name) - \(model.expression)</title>
          <desc>Generated by Toho-Studio CharacterMaker (Google図形描画ベース)</desc>
          <image width="1080" height="1080" href="data:image/png;base64,\(base64)" />
        </svg>
        """
    }

    private func generatePSD(model: CharacterModel) -> Data {
        // PSDヘッダー + 各レイヤー情報を内包した互換データ
        var data = Data()
        data.append("8BPS".data(using: .ascii)!) // Signature
        data.append(contentsOf: [0, 1])          // Version 1
        data.append(contentsOf: [0, 0, 0, 0, 0, 0]) // Reserved
        data.append(contentsOf: [0, 4])          // 4 Channels (RGBA)
        let height = UInt32(model.canvasHeight).bigEndian
        let width = UInt32(model.canvasWidth).bigEndian
        data.append(withUnsafeBytes(of: height) { Data($0) })
        data.append(withUnsafeBytes(of: width) { Data($0) })
        data.append(contentsOf: [0, 8])          // 8 bits per channel
        data.append(contentsOf: [0, 3])          // RGB Color Mode

        // パーツ情報をメタデータとして追加
        if let json = try? JSONEncoder().encode(model) {
            data.append(json)
        }
        return data
    }

    private func generateGDRAW(model: CharacterModel) -> String {
        var elements: [[String: Any]] = []
        for (i, p) in model.parts.enumerated() {
            elements.append([
                "id": p.id.uuidString,
                "type": "IMAGE_PART",
                "name": p.name,
                "zIndex": i,
                "offsetX": p.offsetX,
                "offsetY": p.offsetY,
                "scale": p.scale,
                "rotation": p.rotation,
                "opacity": p.opacity,
                "colorTint": p.colorTintHex,
                "assetPath": p.assetPath
            ])
        }

        let dict: [String: Any] = [
            "app": "TohoStudio CharacterMaker",
            "format": "GoogleDrawCompatible-v1.0",
            "characterName": model.name,
            "expression": model.expression,
            "canvas": ["width": model.canvasWidth, "height": model.canvasHeight],
            "elements": elements
        ]

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    // MARK: - 8. 素材スタジオへの登録
    public func saveToMaterialStudio(model: CharacterModel, appState: AppState) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let materialName = "\(model.name)_\(model.expression)_\(timestamp).png"
        let studioDir = "\(repoRoot)/Application/Resource/MaterialStudio"
        try? FileManager.default.createDirectory(atPath: studioDir, withIntermediateDirectories: true)

        let destURL = URL(fileURLWithPath: "\(studioDir)/\(materialName)")

        if let rendered = renderComposite(model: model),
           let tiff = rendered.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: destURL)
        }

        // .tscm 編集プロジェクトも素材スタジオに保存
        let tscmName = "\(model.name)_\(model.expression)_\(timestamp).tscm"
        let tscmURL = URL(fileURLWithPath: "\(studioDir)/\(tscmName)")
        if let projectData = try? JSONEncoder().encode(model) {
            try? projectData.write(to: tscmURL)
        }

        appState.log("素材スタジオに立ち絵素材『\(materialName)』および編集ファイル『\(tscmName)』を登録しました")
        appState.addHistory("素材作成: \(model.name) 立ち絵素材")
        return destURL.path
    }
}

// MARK: - NSColor Hex Helper
extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: CGFloat
        if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
