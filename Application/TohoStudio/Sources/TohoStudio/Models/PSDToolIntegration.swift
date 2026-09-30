import Foundation
import SwiftUI
import AppKit
import WebKit
import UniformTypeIdentifiers

// MARK: - PSDTool プリセット情報
public struct PSDToolPreset: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let characterName: String
    public let detail: String
    public let path: String
}

// MARK: - PSDTool 統合サービス
public class PSDToolService: NSObject, ObservableObject {
    public static let shared = PSDToolService()

    @Published public var availablePresets: [PSDToolPreset] = []
    @Published public var currentPsdName: String = ""
    @Published public var isLoadingPSD: Bool = false
    @Published public var statusMessage: String = "PSDTool 準備完了"
    @Published public var isAutoTrimEnabled: Bool = true
    @Published public var isFlippedX: Bool = false
    @Published public var isFlippedY: Bool = false

    // WebKit 参照
    public weak var webView: WKWebView?

    public override init() {
        super.init()
        scanPresets()
    }

    // MARK: - リポジトリ内の PSD ファイル探索
    public func scanPresets() {
        let predefinedPresets: [(String, String, String, String)] = [
            ("古明地こいし (通常立ち絵)", "古明地こいし", "表情・サードアイ・服装差分完備", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/地霊殿/古明地こいし/古明地こいし/こいし.psd"),
            ("博麗霊夢 (バトルっぽい)", "博麗霊夢", "お札・御幣・表情差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/主人公たち/博麗霊夢/博麗霊夢（バトルっぽい）/霊夢.psd"),
            ("博麗霊夢 (水着)", "博麗霊夢", "夏仕様・各種差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/主人公たち/博麗霊夢/博麗霊夢(水着)/霊夢水着.psd"),
            ("霧雨魔理沙 (バトルっぽい)", "霧雨魔理沙", "ミニ八卦炉・表情・箒", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/主人公たち/霧雨魔理沙/霧雨魔理沙（バトルっぽい）/魔理沙.psd"),
            ("霧雨魔理沙 (獣王園)", "霧雨魔理沙", "獣王園衣装差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/主人公たち/霧雨魔理沙/霧雨魔理沙(獣王園)/魔理沙獣王園.psd"),
            ("河城にとり (通常立ち絵)", "河城にとり", "エンジニア服・リュック・表情差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/河童/河城にとり/河城にとり/にとり.psd"),
            ("河城にとり (バトルっぽい)", "河城にとり", "メカ・工具・戦闘ポーズ", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/河童/河城にとり/河城にとり(バトルっぽい)/にとり.psd"),
            ("河城みとり (通常立ち絵)", "河城みとり", "みとり差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/河童/河城みとり/みとり.psd"),
            ("八意永琳 (通常立ち絵)", "八意永琳", "弓矢・薬瓶・表情差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/永遠亭/八意永琳/八意永琳/永琳.psd"),
            ("八意永琳 (バトルっぽい)", "八意永琳", "戦闘ポーズ・エフェクト", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/永遠亭/八意永琳/八意永琳(バトルっぽい)/永琳.psd"),
            ("上白沢慧音 (通常立ち絵)", "上白沢慧音", "教科書・表情差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/永遠亭/上白沢慧音/上白沢慧音/慧音.psd"),
            ("上白沢慧音 (ハクタクver)", "上白沢慧音", "白沢化・満月・角差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/永遠亭/上白沢慧音/上白沢慧音(バトルっぽい)/慧音（ワーハクタク） .psd"),
            ("藤原妹紅 (通常立ち絵)", "藤原妹紅", "炎・ポケット手・表情差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/永遠亭/藤原妹紅/藤原妹紅/妹紅.psd"),
            ("藤原妹紅 (バトルっぽい)", "藤原妹紅", "不死鳥・戦闘エフェクト", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/永遠亭/藤原妹紅/藤原妹紅(バトルっぽい)/妹紅.psd"),
            ("冴月麟 (通常立ち絵)", "冴月麟", "二胡・幻の東方キャラ差分", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/冴月麟/冴月麟/冴月麟.psd"),
            ("SinGyoku (女ver)", "SinGyoku", "陰陽玉・神玉", "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/主人公たち/SinGyoku/SinGyoku/シンギョク（女）.psd")
        ]

        var found: [PSDToolPreset] = []
        for p in predefinedPresets {
            if FileManager.default.fileExists(atPath: p.3) {
                found.append(PSDToolPreset(name: p.0, characterName: p.1, detail: p.2, path: p.3))
            }
        }
        self.availablePresets = found
    }

    // MARK: - PSDTool.html の URL 取得
    public static func getPSDToolHTMLURL() -> URL? {
        let candidates = [
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Documents/PSDTool.html",
            Bundle.main.resourcePath.map { "\($0)/Documents/PSDTool.html" } ?? "",
            "\(FileManager.default.currentDirectoryPath)/Application/Documents/PSDTool.html",
            "\(FileManager.default.currentDirectoryPath)/Documents/PSDTool.html"
        ]

        for path in candidates {
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    // MARK: - 外部 PSD ファイル選択ダイアログ
    public func openLocalPSDFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        var types: [UTType] = []
        if let psdType = UTType(filenameExtension: "psd") { types.append(psdType) }
        if let psbType = UTType(filenameExtension: "psb") { types.append(psbType) }
        if let zipType = UTType(filenameExtension: "zip") { types.append(zipType) }
        if let pfvType = UTType(filenameExtension: "pfv") { types.append(pfvType) }
        panel.allowedContentTypes = types
        panel.title = "PSD / PSB / ZIP / PFV ファイルを選択"

        if panel.runModal() == .OK, let url = panel.url {
            loadPSD(filePath: url.path)
        }
    }

    // MARK: - 指定した PSD ファイルを PSDTool に読み込ませる
    public func loadPSD(filePath: String) {
        guard let url = URL(string: filePath.hasPrefix("/") ? "file://\(filePath)" : filePath) ?? URL(fileURLWithPath: filePath) as URL? else {
            self.statusMessage = "ファイルパスが無効です: \(filePath)"
            return
        }

        let filename = url.lastPathComponent
        self.isLoadingPSD = true
        self.statusMessage = "PSD読み込み中: \(filename)..."
        self.currentPsdName = filename

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try Data(contentsOf: url)
                let base64 = data.base64EncodedString()

                DispatchQueue.main.async {
                    self.executeJavaScriptLoadPSD(base64: base64, filename: filename)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingPSD = false
                    self.statusMessage = "PSDファイル読み込みエラー: \(error.localizedDescription)"
                }
            }
        }
    }

    private func executeJavaScriptLoadPSD(base64: String, filename: String) {
        guard let webView = self.webView else {
            self.isLoadingPSD = false
            self.statusMessage = "WebView が未初期化です"
            return
        }

        let escapedFilename = filename.replacingOccurrences(of: "\"", with: "\\\"")
        let js = "window.tohoStudioLoadPSD && window.tohoStudioLoadPSD(\"\(base64)\", \"\(escapedFilename)\");"

        webView.evaluateJavaScript(js) { [weak self] _, error in
            guard let self = self else { return }
            self.isLoadingPSD = false
            if let error = error {
                self.statusMessage = "PSD展開エラー: \(error.localizedDescription)"
            } else {
                self.statusMessage = "PSD展開完了: \(filename)"
            }
        }
    }

    // MARK: - PSDTool からの立ち絵エクスポート要求
    public func requestExport(target: String = "characterMaker") {
        guard let webView = self.webView else { return }
        let js = "window.tohoStudioExportComposite && window.tohoStudioExportComposite('\(target)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - 自動トリミング切り替え
    public func toggleAutoTrim() {
        guard let webView = self.webView else { return }
        let js = """
        (function() {
            var el = document.getElementById('option-auto-trim');
            if (el) {
                el.checked = !el.checked;
                el.dispatchEvent(new Event('change', { bubbles: true }));
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
        isAutoTrimEnabled.toggle()
    }

    // MARK: - 左右反転切り替え
    public func toggleFlipX() {
        guard let webView = self.webView else { return }
        let js = """
        (function() {
            var el = document.getElementById('flip-x');
            if (el) {
                el.checked = !el.checked;
                el.dispatchEvent(new Event('change', { bubbles: true }));
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
        isFlippedX.toggle()
    }

    // MARK: - WebKit メッセージ受信ハンドラー
    public func handleMessage(body: Any) {
        guard let dict = body as? [String: Any],
              let action = dict["action"] as? String else { return }

        switch action {
        case "exportComposite":
            guard let dataUrl = dict["dataUrl"] as? String,
                  let target = dict["target"] as? String else { return }
            handleExportedComposite(dataUrl: dataUrl, target: target)

        case "status":
            if let msg = dict["message"] as? String {
                self.statusMessage = msg
            }

        default:
            break
        }
    }

    // MARK: - エクスポート画像処理
    private func handleExportedComposite(dataUrl: String, target: String) {
        guard let commaIndex = dataUrl.firstIndex(of: ",") else { return }
        let base64String = String(dataUrl[dataUrl.index(after: commaIndex)...])
        guard let imageData = Data(base64Encoded: base64String),
              NSImage(data: imageData) != nil else {
            self.statusMessage = "画像デコードに失敗しました"
            return
        }

        // 保存用ディレクトリ (キャッシュ or プロジェクト)
        let outputDir = "/tmp/TohoStudio/PSDToolExports"
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        let filename = "psd_\(currentPsdName.replacingOccurrences(of: ".psd", with: "").replacingOccurrences(of: ".psb", with: ""))_\(Int(Date().timeIntervalSince1970)).png"
        let savedPath = "\(outputDir)/\(filename)"
        try? imageData.write(to: URL(fileURLWithPath: savedPath))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let appState = AppState.shared

            switch target {
            case "characterMaker":
                // 1. キャラクターメーカーのベース立ち絵または新規パーツとして適用
                appState.currentCharacter.baseImagePath = savedPath

                // レイヤーパーツとしても自動登録
                let newPart = CharacterPart(
                    name: "PSD立ち絵 (\(self.currentPsdName.isEmpty ? "合成" : self.currentPsdName))",
                    assetPath: savedPath
                )
                appState.currentCharacter.parts.append(newPart)
                self.statusMessage = "立ち絵をキャラクターメーカーに適用しました (レイヤー追加完了)"

            case "timeline":
                // 2. タイムラインに立ち絵シーンとして配置
                let scene = MovieScene(
                    title: "立ち絵シーン: \(self.currentPsdName.isEmpty ? "PSD差分" : self.currentPsdName)",
                    duration: 5.0,
                    slideTitle: "PSD立ち絵演出",
                    backgroundName: "透過背景",
                    characterName: self.currentPsdName,
                    telop: "",
                    characterImagePath: savedPath
                )
                appState.movieScenes.append(scene)
                self.statusMessage = "タイムラインに立ち絵シーンを追加しました"

            case "materialStudio":
                // 3. 素材スタジオに登録
                let item = MaterialItem(
                    id: UUID(),
                    title: "PSD立ち絵: \(self.currentPsdName)",
                    type: "画像",
                    category: "キャラクター",
                    filePath: savedPath,
                    fileSize: Int64(imageData.count),
                    createdAt: Date(),
                    isCloudSynced: false,
                    rightsStatus: "二次創作ガイドライン準拠"
                )
                appState.materials.append(item)
                self.statusMessage = "素材スタジオに登録しました: \(item.title)"

            default:
                break
            }
        }
    }
}

// MARK: - PSDTool NSViewRepresentable (WebKit)
public struct PSDToolWebView: NSViewRepresentable {
    @ObservedObject var service = PSDToolService.shared

    public init() {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        // 連携用スクリプトを注入
        let bridgeScriptSource = """
        // --- TohoStudio ↔ PSDTool Bridge ---
        window.tohoStudioLoadPSD = function(base64Data, filename) {
            try {
                var binaryString = atob(base64Data);
                var len = binaryString.length;
                var bytes = new Uint8Array(len);
                for (var i = 0; i < len; i++) {
                    bytes[i] = binaryString.charCodeAt(i);
                }
                var blob = new Blob([bytes], { type: 'image/x-photoshop' });
                var file = new File([blob], filename, { type: 'image/x-photoshop' });

                var dt = new DataTransfer();
                dt.items.add(file);
                var input = document.querySelector('#dropzone input[type=file]');
                if (input) {
                    input.files = dt.files;
                    input.dispatchEvent(new Event('change', { bubbles: true }));
                    console.log('TohoStudio: PSD loaded successfully via change event:', filename);
                } else {
                    console.error('TohoStudio: #dropzone input not found');
                }
            } catch(e) {
                console.error('TohoStudio: error loading PSD:', e);
            }
        };

        window.tohoStudioExportComposite = function(target) {
            try {
                var canvas = document.getElementById('preview');
                if (canvas) {
                    var dataUrl = canvas.toDataURL('image/png');
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tohoStudio) {
                        window.webkit.messageHandlers.tohoStudio.postMessage({
                            action: 'exportComposite',
                            target: target || 'characterMaker',
                            dataUrl: dataUrl,
                            width: canvas.width,
                            height: canvas.height
                        });
                    }
                } else {
                    console.warn('TohoStudio: preview canvas not ready');
                }
            } catch(e) {
                console.error('TohoStudio exportComposite error:', e);
            }
        };

        function tohoStudioInjectButtons() {
            var header = document.querySelector('.psdtool-header') || document.querySelector('#misc-ui');
            if (header && !document.getElementById('tohostudio-bridge-btn-group')) {
                var group = document.createElement('span');
                group.id = 'tohostudio-bridge-btn-group';
                group.style.marginLeft = '12px';
                group.style.display = 'inline-block';
                group.innerHTML = `
                    <button class="btn btn-sm btn-success" onclick="window.tohoStudioExportComposite('characterMaker')" style="margin-right:4px; font-weight:bold;">
                        ⭐ キャラクターメーカーに適用
                    </button>
                    <button class="btn btn-sm btn-info" onclick="window.tohoStudioExportComposite('timeline')" style="margin-right:4px;">
                        🎬 タイムラインに配置
                    </button>
                    <button class="btn btn-sm btn-warning" onclick="window.tohoStudioExportComposite('materialStudio')">
                        📦 素材スタジオに追加
                    </button>
                `;
                header.appendChild(group);
            }
        }
        setInterval(tohoStudioInjectButtons, 1200);
        """

        let bridgeScript = WKUserScript(source: bridgeScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(bridgeScript)
        config.userContentController.add(context.coordinator, name: "tohoStudio")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        service.webView = webView

        // HTML のロード
        if let htmlURL = PSDToolService.getPSDToolHTMLURL() {
            let accessDir = htmlURL.deletingLastPathComponent() // Application/Documents
            webView.loadFileURL(htmlURL, allowingReadAccessTo: accessDir)
        }

        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {}

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: PSDToolWebView

        init(_ parent: PSDToolWebView) {
            self.parent = parent
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "tohoStudio" {
                self.parent.service.handleMessage(body: message.body)
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.service.statusMessage = "PSDTool 起動完了"
            }
        }
    }
}
