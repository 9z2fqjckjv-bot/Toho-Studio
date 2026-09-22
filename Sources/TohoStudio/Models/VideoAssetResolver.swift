import Foundation

/// 動画用フォルダ（/Volumes/ZSSD/動画用）内のキャラクター、手作り素材、背景画像と
/// Keynoteから得た画像名（例: 文（余裕）.png, 昭和レトロな茶の間（照明ON）.pxd）を照合・解決するエンジン
public final class VideoAssetResolver {
    public static let shared = VideoAssetResolver()
    
    public let videoRootURL = URL(fileURLWithPath: "/Volumes/ZSSD/動画用")
    public let characterURL = URL(fileURLWithPath: "/Volumes/ZSSD/動画用/キャラクター")
    public let handmadeURL = URL(fileURLWithPath: "/Volumes/ZSSD/動画用/手作り素材")
    public let backgroundURL = URL(fileURLWithPath: "/Volumes/ZSSD/動画用/背景")
    
    // キャッシュ: [ファイル名(小文字/正規化): [絶対パス]]
    private var fileCache: [String: [String]] = [:]
    private var isIndexed: Bool = false
    private let lock = NSLock()
    
    private init() {}
    
    /// インデックスを構築（必要に応じて自動呼び出し）
    public func ensureIndex() {
        lock.lock()
        defer { lock.unlock() }
        if isIndexed { return }
        buildIndexInternal()
        isIndexed = true
    }
    
    /// インデックスの強制再構築
    public func reloadIndex() {
        lock.lock()
        defer { lock.unlock() }
        buildIndexInternal()
        isIndexed = true
    }
    
    private func buildIndexInternal() {
        var newCache: [String: [String]] = [:]
        let fm = FileManager.default
        let searchDirs = [characterURL, handmadeURL, backgroundURL, videoRootURL]
        
        for dir in searchDirs {
            guard fm.fileExists(atPath: dir.path) else { continue }
            if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    let ext = fileURL.pathExtension.lowercased()
                    // 対象画像拡張子
                    guard ["png", "jpg", "jpeg", "pxd", "webp", "gif"].contains(ext) else { continue }
                    
                    let fullName = fileURL.lastPathComponent
                    let baseName = fileURL.deletingPathExtension().lastPathComponent
                    let normalizedFull = fullName.precomposedStringWithCanonicalMapping.lowercased()
                    let normalizedBase = baseName.precomposedStringWithCanonicalMapping.lowercased()
                    
                    newCache[normalizedFull, default: []].append(fileURL.path)
                    newCache[normalizedBase, default: []].append(fileURL.path)
                }
            }
        }
        self.fileCache = newCache
    }
    
    /// キャラクター画像を照合・検索
    public func resolveCharacterImage(named fileName: String, speaker: String? = nil) -> String? {
        ensureIndex()
        let cleanName = cleanImageName(fileName)
        let normalized = cleanName.precomposedStringWithCanonicalMapping.lowercased()
        let baseNormalized = URL(fileURLWithPath: cleanName).deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping.lowercased()
        
        lock.lock()
        let candidates = (fileCache[normalized] ?? []) + (fileCache[baseNormalized] ?? [])
        lock.unlock()
        
        // 1. キャラクターフォルダ内かつ話者名（例: 射命丸文、操夢など）がパスに含まれるものを最優先
        if let spk = speaker?.precomposedStringWithCanonicalMapping.lowercased(), !spk.isEmpty {
            for path in candidates {
                let lowerPath = path.lowercased()
                if lowerPath.contains("/キャラクター/") && lowerPath.contains(spk) {
                    return path
                }
            }
        }
        
        // 2. キャラクターフォルダ内のものを優先
        for path in candidates {
            if path.contains("/キャラクター/") {
                return path
            }
        }
        
        // 3. 拡張子png/jpgを優先
        for path in candidates {
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            if ext == "png" || ext == "jpg" || ext == "jpeg" {
                return path
            }
        }
        
        return candidates.first
    }
    
    /// 背景画像を照合・検索
    public func resolveBackgroundImage(named fileName: String) -> String? {
        ensureIndex()
        let cleanName = cleanImageName(fileName)
        let normalized = cleanName.precomposedStringWithCanonicalMapping.lowercased()
        let baseNormalized = URL(fileURLWithPath: cleanName).deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping.lowercased()
        
        lock.lock()
        let candidates = (fileCache[normalized] ?? []) + (fileCache[baseNormalized] ?? [])
        lock.unlock()
        
        // 1. 背景フォルダまたは手作り素材内のjpg/pngを最優先（.pxdの同名書き出し画像など）
        for path in candidates {
            let lowerPath = path.lowercased()
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            if (lowerPath.contains("/背景/") || lowerPath.contains("/手作り素材/")) && (ext == "jpg" || ext == "jpeg" || ext == "png") {
                return path
            }
        }
        
        // 2. 任意のjpg/png
        for path in candidates {
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            if ext == "jpg" || ext == "jpeg" || ext == "png" {
                return path
            }
        }
        
        return candidates.first
    }
    
    /// 画像名をクリーンアップ
    private func cleanImageName(_ name: String) -> String {
        return name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
    }
}
