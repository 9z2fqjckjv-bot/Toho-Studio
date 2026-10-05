import SwiftUI
import WebKit
import AppKit

/// Google Colab GPU ブリッジ専用 アプリ内WebKitブラウザ
/// - Colab ノートブックを読み込み
/// - 「すべてのセルを実行」後の Cloudflare Tunnel URL (https://xxxx.trycloudflare.com) を DOM & クリップボードから自動検出
/// - エンドポイントへの自動挿入 ＆ 疎通テスト（ヘルスチェック）を全自動実行
public struct ColabGPUInAppBrowserView: View {
    @Binding public var isPresented: Bool
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var imageService = AIImageGeneratorService.shared

    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = false
    @State private var currentTitle: String = "Google Colab GPU Bridge"
    @State private var currentURLString: String = ""
    @State private var detectedURL: String = ""
    @State private var detectionStatus: DetectionState = .waiting
    @State private var statusMessage: String = "Colab で「ランタイム」>「すべてのセルを実行」(Cmd+F9) を押してください"
    @State private var timer: Timer? = nil

    private let webView: WKWebView

    public enum DetectionState {
        case waiting
        case detecting
        case connected
        case failed
    }

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default() // Google ログイン状態を保持
        self.webView = WKWebView(frame: .zero, configuration: config)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 上部ツールバー: タイトル・進捗・自動検出ステータス
            headerBar

            // ガイド ＆ 自動検出バナー
            detectionBanner

            if isLoading {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            } else {
                Divider()
            }

            // WebKit WebView 本体
            ColabWebRepresentable(
                url: URL(string: cloudLinuxService.colabBridge.notebookUrl) ?? URL(string: "https://colab.research.google.com/")!,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                pageTitle: $currentTitle,
                pageURL: $currentURLString,
                webView: webView
            )
        }
        .frame(minWidth: 960, minHeight: 680)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            startDetectionLoop()
        }
        .onDisappear {
            stopDetectionLoop()
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            // ナビゲーション操作
            Button(action: { webView.goBack() }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 14, weight: .bold))
            }
            .disabled(!canGoBack)
            .buttonStyle(.plain)

            Button(action: { webView.goForward() }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
            }
            .disabled(!canGoForward)
            .buttonStyle(.plain)

            Button(action: { webView.reload() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(.plain)

            // アドレス表示
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text("Google Colab GPU 自動連携ブラウザ")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(currentURLString.isEmpty ? cloudLinuxService.colabBridge.notebookUrl : currentURLString)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12)))

            // 「すべてのセルを実行」アシストボタン
            Button(action: { triggerRunAllCells() }) {
                Label("セル実行アシスト (Cmd+F9)", systemImage: "play.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange))
            }
            .buttonStyle(.plain)
            .help("Colabの『すべてのセルを実行』ショートカットを送信します")

            // 閉じるボタン
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Detection Status Banner
    private var detectionBanner: some View {
        HStack(spacing: 12) {
            switch detectionStatus {
            case .waiting:
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("🔍 GPU一時URLの自動検出待機中...")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.primary)
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            case .detecting:
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("⚡️ 一時URLを検出しました: \(detectedURL)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.blue)
                    Text("GPUサーバー (/health) への疎通接続テストを実行中...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            case .connected:
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("🎉 Google Colab GPU に自動接続完了！ (\(cloudLinuxService.colabBridge.gpuName))")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.green)
                    Text("接続URL: \(cloudLinuxService.colabBridge.endpoint) を自動挿入しました。高精度AI画像・動画・音楽生成が可能です。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("⚠️ 検出URLへの接続テストに失敗しました: \(detectedURL)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.orange)
                    Text("セルが最後まで正常に終了したか確認してください。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if detectionStatus == .connected {
                Button(action: {
                    isPresented = false
                }) {
                    Text("接続完了して画像生成へ戻る")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.green))
                }
                .buttonStyle(.plain)
            } else {
                // 手動ペースト支援ボタン
                Button(action: { checkClipboard() }) {
                    Label("コピーしたURLを適用", systemImage: "doc.on.clipboard")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            detectionStatus == .connected
                ? Color.green.opacity(0.12)
                : (detectionStatus == .detecting ? Color.blue.opacity(0.12) : Color.yellow.opacity(0.1))
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(
                    detectionStatus == .connected
                        ? Color.green.opacity(0.3)
                        : (detectionStatus == .detecting ? Color.blue.opacity(0.3) : Color.yellow.opacity(0.3))
                ),
            alignment: .bottom
        )
    }

    // MARK: - 自動検出ループ (DOM走査 ＆ クリップボード監視)
    private func startDetectionLoop() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            guard detectionStatus != .connected else { return }

            // 1. クリップボードを監視（ユーザーが手動でURLをコピーした場合でも即座にキャッチ）
            checkClipboard()

            // 2. WKWebView の DOM から trycloudflare.com を自動抽出
            let js = """
            (function() {
                var text = document.body ? document.body.innerText : '';
                var match = text.match(/https?:\\/\\/[a-zA-Z0-9-]+\\.trycloudflare\\.com/);
                if (match) return match[0];
                var iframes = document.getElementsByTagName('iframe');
                for (var i = 0; i < iframes.length; i++) {
                    try {
                        var doc = iframes[i].contentDocument || iframes[i].contentWindow.document;
                        if (doc && doc.body) {
                            var m2 = doc.body.innerText.match(/https?:\\/\\/[a-zA-Z0-9-]+\\.trycloudflare\\.com/);
                            if (m2) return m2[0];
                        }
                    } catch(e) {}
                }
                return '';
            })()
            """

            webView.evaluateJavaScript(js) { result, error in
                if let urlString = result as? String, !urlString.isEmpty {
                    handleFoundURL(urlString)
                }
            }
        }
    }

    private func stopDetectionLoop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        if let paste = NSPasteboard.general.string(forType: .string) {
            let pattern = "https?://[a-zA-Z0-9-]+\\.trycloudflare\\.com"
            if let range = paste.range(of: pattern, options: .regularExpression) {
                let urlString = String(paste[range])
                handleFoundURL(urlString)
            }
        }
    }

    private func handleFoundURL(_ urlString: String) {
        let clean = CloudVirtualLinuxService.sanitizeColabEndpoint(urlString)
        guard clean != detectedURL || detectionStatus != .connected else { return }

        detectedURL = clean
        detectionStatus = .detecting
        statusMessage = "URL: \(clean) へのヘルスチェックを実行しています..."

        // アプリケーションのエンドポイントに即時自動挿入
        cloudLinuxService.colabBridge.endpoint = clean

        // 疎通テストの自動実行
        cloudLinuxService.testColabBridgeConnection { success, message in
            DispatchQueue.main.async {
                if success {
                    self.detectionStatus = .connected
                    self.statusMessage = message
                    // サウンドを鳴らして通知
                    NSSound.beep()
                } else {
                    self.detectionStatus = .failed
                    self.statusMessage = message
                }
            }
        }
    }

    // MARK: - 「すべてのセルを実行」ショートカット送信
    private func triggerRunAllCells() {
        let js = """
        (function() {
            // Colab のショートカット Cmd+F9 / Ctrl+F9 イベントをディスパッチ
            var event = new KeyboardEvent('keydown', {
                key: 'F9',
                code: 'F9',
                keyCode: 120,
                which: 120,
                ctrlKey: true,
                metaKey: true,
                bubbles: true
            });
            document.dispatchEvent(event);

            // メニューバーからの実行を試行
            var runtimeMenu = document.querySelector('#runtime-menu-button');
            if (runtimeMenu) {
                runtimeMenu.click();
            }
        })()
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
        statusMessage = "実行リクエストを送信しました。出力セルに一時URLが表示されるのをお待ちください。"
    }
}

// MARK: - Colab WKWebView Representable
public struct ColabWebRepresentable: NSViewRepresentable {
    let url: URL
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var pageURL: String
    let webView: WKWebView

    public func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ColabWebRepresentable

        init(_ parent: ColabWebRepresentable) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.pageURL = webView.url?.absoluteString ?? ""
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                self.parent.pageTitle = webView.title ?? ""
                self.parent.pageURL = webView.url?.absoluteString ?? ""
            }
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
