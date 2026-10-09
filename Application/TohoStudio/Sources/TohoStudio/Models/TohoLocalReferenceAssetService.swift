import Foundation
import AppKit
import CoreGraphics

/// 東方動画制作用 参考資料アーカイブ素材自動探索＆合成サービス
/// ユーザーのプロンプトからキャラクターや施設（背景）のキーワードを抽出し、
/// `/Volumes/ZSSD/GitHub/repository/TohoStudio/New/Application/Documents/参考資料/動画用`
/// などのローカル参考資料フォルダを最優先で探索。
/// 見つかった場合は高品質な立ち絵・背景・演出効果（汗たらたら等）を合成して生成します。
public final class TohoLocalReferenceAssetService {
    public static let shared = TohoLocalReferenceAssetService()

    public struct MatchResult {
        public let characterName: String?
        public let facilityName: String?
        public let characterImagePath: String?
        public let backgroundImagePath: String?
        public let composedImage: NSImage
        public let fileURL: URL
        public let description: String
    }

    // 優先探索ディレクトリ候補
    private let primaryRootPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/New/Application/Documents/参考資料/動画用"

    private init() {}

    // MARK: - ルートディレクトリ解決
    public func locateReferenceRootDirectory() -> URL? {
        let fm = FileManager.default
        let candidates: [String] = [
            primaryRootPath,
            fm.currentDirectoryPath + "/New/Application/Documents/参考資料/動画用",
            fm.currentDirectoryPath + "/Documents/参考資料/動画用",
            fm.currentDirectoryPath + "/../../New/Application/Documents/参考資料/動画用",
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("New/Application/Documents/参考資料/動画用").path,
            NSHomeDirectory() + "/Documents/参考資料/動画用",
            NSHomeDirectory() + "/New/Application/Documents/参考資料/動画用"
        ]

        for path in candidates {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    // MARK: - プロンプトから探索＆合成実行
    public func searchAndComposeAsset(
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio = .portrait9_16
    ) -> MatchResult? {
        guard let rootURL = locateReferenceRootDirectory() else {
            return nil
        }

        let normalizedPrompt = prompt.precomposedStringWithCanonicalMapping

        // 1. キーワード抽出 (キャラクター、施設/背景)
        let matchedCharacter = extractCharacterKeyword(from: normalizedPrompt)
        let matchedFacility = extractFacilityKeyword(from: normalizedPrompt)

        // キャラクターも施設も見つからなければ通常AIへ委譲
        if matchedCharacter == nil && matchedFacility == nil {
            return nil
        }

        // 2. キャラクター素材の探索
        var characterImg: NSImage? = nil
        var characterPath: String? = nil
        var resolvedCharName: String? = nil
        var resolvedExprName: String? = nil

        if let charKeyword = matchedCharacter {
            if let found = findCharacterAsset(keyword: charKeyword, prompt: normalizedPrompt, rootURL: rootURL) {
                characterImg = NSImage(contentsOf: found.url)
                characterPath = found.url.path
                resolvedCharName = found.characterName
                resolvedExprName = found.expressionName
            }
        }

        // 3. 施設・背景素材の探索
        var backgroundImg: NSImage? = nil
        var backgroundPath: String? = nil
        var resolvedFacilityName: String? = nil

        if let facilityKeyword = matchedFacility {
            if let foundBg = findBackgroundAsset(keyword: facilityKeyword, prompt: normalizedPrompt, rootURL: rootURL) {
                backgroundImg = NSImage(contentsOf: foundBg.url)
                backgroundPath = foundBg.url.path
                resolvedFacilityName = foundBg.facilityName
            }
        }

        // 素材がどちらも見つからなかった場合
        if characterImg == nil && backgroundImg == nil {
            return nil
        }

        // 4. 画像合成 (キャラクター + 背景を自然に合成・追加エフェクトなし)
        let dimensions = aspectRatio.dimensions
        let targetSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))

        guard let finalImage = composeFinalImage(
            characterImage: characterImg,
            backgroundImage: backgroundImg,
            targetSize: targetSize,
            aspectRatio: aspectRatio
        ) else {
            return nil
        }

        // 5. 一時ファイルへ保存
        guard let savedURL = saveImageToTemporaryFile(image: finalImage, prefix: "toho_ref") else {
            return nil
        }

        // 説明文の組み立て (追加エフェクトなしの純粋な公式素材情報)
        var descComponents: [String] = []
        if let c = resolvedCharName {
            var cDesc = "キャラクター: \(c)"
            if let expr = resolvedExprName {
                cDesc += "（\(expr)）"
            }
            descComponents.append(cDesc)
        }
        if let f = resolvedFacilityName {
            descComponents.append("背景: \(f)")
        }
        let fullDesc = descComponents.joined(separator: " / ")

        return MatchResult(
            characterName: resolvedCharName,
            facilityName: resolvedFacilityName,
            characterImagePath: characterPath,
            backgroundImagePath: backgroundPath,
            composedImage: finalImage,
            fileURL: savedURL,
            description: fullDesc
        )
    }

    // MARK: - キャラクター名キーワード抽出
    private func extractCharacterKeyword(from prompt: String) -> String? {
        // 長い一致を優先
        let candidates: [(keyword: String, aliases: [String])] = [
            ("古明地こいし", ["こいし"]),
            ("古明地さとり", ["さとり"]),
            ("博麗霊夢", ["霊夢", "れいむ"]),
            ("霧雨魔理沙", ["魔理沙", "まりさ"]),
            ("東風谷早苗", ["早苗", "さなえ"]),
            ("十六夜咲夜", ["咲夜", "さくや"]),
            ("レミリア・スカーレット", ["レミリア"]),
            ("フランドール・スカーレット", ["フランドール", "フラン"]),
            ("パチュリー・ノーレッジ", ["パチュリー"]),
            ("紅美鈴", ["美鈴", "めいりん"]),
            ("小悪魔", ["こあくま"]),
            ("チルノ", ["ちるの"]),
            ("大妖精", ["大ちゃん"]),
            ("ルーミア", []),
            ("アリス・マーガトロイド", ["アリス"]),
            ("魂魄妖夢", ["妖夢", "みょん"]),
            ("西行寺幽々子", ["幽々子", "ゆゆ様"]),
            ("八雲紫", ["紫", "ゆかり"]),
            ("八雲藍", ["藍", "らん"]),
            ("橙", ["ちぇん"]),
            ("射命丸文", ["射命丸", "文"]),
            ("犬走椛", ["椛", "もみじ"]),
            ("四季映姫", ["映姫"]),
            ("小野塚小町", ["小町"]),
            ("鍵山雛", ["雛"]),
            ("河城にとり", ["にとり"]),
            ("河城みとり", ["みとり"]),
            ("多々良小傘", ["小傘"]),
            ("風見幽香", ["幽香"]),
            ("鈴仙・優曇華・イナバ", ["鈴仙", "優曇華", "うどんげ"]),
            ("八意永琳", ["永琳", "えーりん"]),
            ("上白沢慧音", ["慧音", "けーね"]),
            ("藤原妹紅", ["妹紅", "もこたん"]),
            ("因幡てゐ", ["てゐ"]),
            ("蓬莱山輝夜", ["輝夜"]),
            ("火焔猫燐", ["お燐", "燐"]),
            ("霊烏路空", ["お空", "空"]),
            ("森近霖之助", ["霖之助", "こーりん"]),
            ("二ッ岩マミゾウ", ["マミゾウ"]),
            ("摩多羅隠岐奈", ["隠岐奈"]),
            ("山城たかね", ["たかね"]),
            ("飯綱丸龍", ["飯縄丸龍", "龍"]),
            ("冴月麟", []),
            ("SinGyoku", [])
        ]

        // 1. 完全名一致を走査
        for candidate in candidates {
            if prompt.contains(candidate.keyword) {
                return candidate.keyword
            }
        }

        // 2. エイリアス一致を走査
        for candidate in candidates {
            for alias in candidate.aliases {
                if prompt.contains(alias) {
                    return candidate.keyword
                }
            }
        }

        return nil
    }

    // MARK: - 施設・背景キーワード抽出
    private func extractFacilityKeyword(from prompt: String) -> String? {
        let facilityKeywords = [
            "地霊殿", "紅魔館", "大図書館", "図書館", "ロビー",
            "病院", "診察室", "病室", "受付", "廊下",
            "会議室", "商店街", "駅", "屋敷", "華扇の屋敷",
            "リビング", "寝室", "和モダン", "浴室", "食堂",
            "書斎", "宴会場", "屋上", "ビル", "都市", "家屋",
            "ロッカールーム", "居酒屋", "ゲームセンター", "映画館",
            "ショッピングモール", "バー", "裏通り", "マンション",
            "廃墟", "屋台", "鯨呑亭", "土手", "階段", "都会",
            "街中", "学校", "教室", "縁側", "研究室", "峡谷",
            "神社", "博麗神社", "守矢神社"
        ]

        for fac in facilityKeywords {
            if prompt.contains(fac) {
                return fac
            }
        }
        return nil
    }

    // MARK: - キャラクター素材探索
    private func findCharacterAsset(
        keyword: String,
        prompt: String,
        rootURL: URL
    ) -> (url: URL, characterName: String, expressionName: String)? {
        let charsDir = rootURL.appendingPathComponent("キャラクター")
        let fm = FileManager.default
        guard fm.fileExists(atPath: charsDir.path) else { return nil }

        // サブディレクトリから対象キャラクターフォルダを探索
        var targetCharDirURL: URL? = nil
        if let enumerator = fm.enumerator(at: charsDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let name = fileURL.lastPathComponent.precomposedStringWithCanonicalMapping
                if name == keyword || name.contains(keyword) {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
                        targetCharDirURL = fileURL
                        break
                    }
                }
            }
        }

        guard let charDir = targetCharDirURL else { return nil }

        // 表情判定
        let promptLower = prompt.lowercased()
        let isBattle = promptLower.contains("バトル") || promptLower.contains("戦闘") || promptLower.contains("攻撃") || promptLower.contains("構え")
        let isDamaged = promptLower.contains("やられ") || promptLower.contains("服ビリ") || promptLower.contains("負け") || promptLower.contains("ボロボロ")
        let isBlushing = promptLower.contains("赤面") || promptLower.contains("照れ") || promptLower.contains("恥ずかし")
        let isSweat = promptLower.contains("汗") || promptLower.contains("たらたら") || promptLower.contains("冷や汗") || promptLower.contains("焦") || promptLower.contains("苦笑") || promptLower.contains("困") || promptLower.contains("流す") || promptLower.contains("垂れ")

        // 全PNGファイルを収集
        var allPNGs: [URL] = []
        if let charEnumerator = fm.enumerator(at: charDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in charEnumerator {
                if fileURL.pathExtension.lowercased() == "png" {
                    allPNGs.append(fileURL)
                }
            }
        }

        guard !allPNGs.isEmpty else { return nil }

        // スコアリングで最適なPNGを選出
        var bestURL = allPNGs[0]
        var maxScore = -1

        for url in allPNGs {
            let pathStr = url.path.precomposedStringWithCanonicalMapping
            let filename = url.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
            var score = 0

            // バトル/やられ/赤面ディレクトリ適性
            if isBattle && pathStr.contains("バトル") { score += 20 }
            if isDamaged && pathStr.contains("やられ") { score += 25 }
            if isBlushing && pathStr.contains("赤面") { score += 20 }
            if !isBlushing && pathStr.contains("通常") { score += 10 }

            // 表情名適性
            if isSweat {
                if filename.contains("苦笑") { score += 40 }
                else if filename.contains("困る") { score += 35 }
                else if filename.contains("困惑") { score += 30 }
                else if filename.contains("驚く") { score += 20 }
            } else if promptLower.contains("笑") || promptLower.contains("嬉") {
                if filename.contains("笑い") { score += 35 }
                else if filename.contains("微笑") { score += 30 }
            } else if promptLower.contains("怒") {
                if filename.contains("怒る") || filename.contains("怒り") { score += 35 }
                else if filename.contains("不満") { score += 25 }
            } else if promptLower.contains("泣") || promptLower.contains("涙") {
                if filename.contains("泣く") { score += 35 }
            } else if promptLower.contains("驚") {
                if filename.contains("驚く") { score += 35 }
            } else if promptLower.contains("余裕") {
                if filename.contains("余裕") { score += 35 }
            }

            // デフォルトの基本表情加点
            if filename.contains("微笑") || filename.contains("通常") || filename.contains("普通") {
                score += 5
            }

            if score > maxScore {
                maxScore = score
                bestURL = url
            }
        }

        let exprName = bestURL.deletingPathExtension().lastPathComponent
        return (bestURL, keyword, exprName)
    }

    // MARK: - 施設・背景素材探索
    private func findBackgroundAsset(
        keyword: String,
        prompt: String,
        rootURL: URL
    ) -> (url: URL, facilityName: String)? {
        let bgDir = rootURL.appendingPathComponent("背景")
        let fm = FileManager.default
        guard fm.fileExists(atPath: bgDir.path) else { return nil }

        var allImages: [URL] = []
        if let enumerator = fm.enumerator(at: bgDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "webp"].contains(ext) {
                    allImages.append(fileURL)
                }
            }
        }

        guard !allImages.isEmpty else { return nil }

        let promptLower = prompt.lowercased()
        let isNight = promptLower.contains("夜") || promptLower.contains("深夜") || promptLower.contains("暗")
        let isEvening = promptLower.contains("夕") || promptLower.contains("夕方") || promptLower.contains("日没")
        let isDay = promptLower.contains("昼") || promptLower.contains("日中") || promptLower.contains("朝")

        var bestURL: URL? = nil
        var maxScore = -1

        for url in allImages {
            let fullPath = url.path.precomposedStringWithCanonicalMapping
            var score = 0

            if fullPath.contains(keyword) {
                score += 30
            }

            // 時間帯マッチング
            if isNight && (fullPath.contains("夜") || fullPath.contains("深夜")) { score += 10 }
            if isEvening && (fullPath.contains("夕") || fullPath.contains("夕方")) { score += 10 }
            if isDay && (fullPath.contains("昼") || fullPath.contains("日中")) { score += 10 }

            if score > maxScore && score > 0 {
                maxScore = score
                bestURL = url
            }
        }

        guard let resolvedURL = bestURL else { return nil }
        return (resolvedURL, keyword)
    }

    // MARK: - 画像合成 (CoreGraphics - 自然なレイアウト合成・追加エフェクト全廃)
    private func composeFinalImage(
        characterImage: NSImage?,
        backgroundImage: NSImage?,
        targetSize: CGSize,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio
    ) -> NSImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 高品位補間設定 (画質劣化を防ぎ、原画の滑らかな輪郭を保持)
        context.interpolationQuality = .high
        context.setShouldAntialias(true)

        // 1. 背景描画 (背景画像が存在する場合)
        if let bg = backgroundImage, let bgCG = bg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let bgW = CGFloat(bgCG.width)
            let bgH = CGFloat(bgCG.height)
            let scale = max(targetSize.width / bgW, targetSize.height / bgH)
            let scaledW = bgW * scale
            let scaledH = bgH * scale
            let bgRect = CGRect(
                x: (targetSize.width - scaledW) / 2.0,
                y: (targetSize.height - scaledH) / 2.0,
                width: scaledW,
                height: scaledH
            )
            context.draw(bgCG, in: bgRect)
        }

        // 2. キャラクター描画 (追加のオブジェクト描画なし。絵師の原画・表情を純粋に配置)
        if let char = characterImage, let charCG = char.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let charW = CGFloat(charCG.width)
            let charH = CGFloat(charCG.height)

            // アスペクト比を維持してキャンバス内に自然に収める
            let maxCharH = targetSize.height * 0.92
            let maxCharW = targetSize.width * 0.88
            let fitScale = min(maxCharH / charH, maxCharW / charW)

            let drawW = charW * fitScale
            let drawH = charH * fitScale
            let posX = (targetSize.width - drawW) / 2.0
            let posY = (targetSize.height - drawH) * 0.20 // 自然な接地感

            let charTargetRect = CGRect(x: posX, y: posY, width: drawW, height: drawH)
            context.draw(charCG, in: charTargetRect)
        }

        guard let outputCG = context.makeImage() else { return nil }
        return NSImage(cgImage: outputCG, size: targetSize)
    }

    // MARK: - ファイル保存
    private func saveImageToTemporaryFile(image: NSImage, prefix: String) -> URL? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return nil }

        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tohostudio_ai_output")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let filename = "\(prefix)_\(formatter.string(from: Date())).png"
        let fileURL = tmpDir.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save composed image: \(error)")
            return nil
        }
    }
}
