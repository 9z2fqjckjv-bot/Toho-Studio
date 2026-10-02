import SwiftUI
import AppKit
import WebKit

/// アプリケーション内専用WebKitブラウザ (WKWebViewラッパー)
public struct InAppBillingWebView: NSViewRepresentable {
    public let url: URL
    @Binding public var canGoBack: Bool
    @Binding public var canGoForward: Bool
    @Binding public var isLoading: Bool

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url && !url.absoluteString.isEmpty {
            let request = URLRequest(url: url)
            nsView.load(request)
        }
    }

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: InAppBillingWebView
        weak var webView: WKWebView?

        init(_ parent: InAppBillingWebView) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}

/// 仕様書「外部APIの請求をアプリケーション内の専用ブラウザで確認」プログラム
public struct InAppBillingBrowserProgramView: View {
    @State private var currentURLString: String = "https://aistudio.google.com/"
    @State private var activeURL: URL = URL(string: "https://aistudio.google.com/")!
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // ショートカットバー
            portalShortcutsBar

            Divider()

            // ブラウザ操作バー (URL, 戻る, 進む, リロード, SSL鍵)
            browserAddressBar

            Divider()

            // WebKit WebView 本体
            ZStack {
                InAppBillingWebView(
                    url: activeURL,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    isLoading: $isLoading
                )

                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding()
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
                            .cornerRadius(12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Shortcuts Bar
    private var portalShortcutsBar: some View {
        HStack(spacing: 10) {
            Text("請求ポータル:")
                .font(.caption2)
                .bold()
                .foregroundColor(.secondary)

            portalButton(title: "Google AI Studio", urlString: "https://aistudio.google.com/", icon: "sparkles", color: .blue)
            portalButton(title: "Google Cloud Billing", urlString: "https://console.cloud.google.com/billing", icon: "cloud.fill", color: .blue)
            portalButton(title: "OpenAI Usage & Billing", urlString: "https://platform.openai.com/usage", icon: "brain", color: .green)
            portalButton(title: "Anthropic Plans & Cost", urlString: "https://console.anthropic.com/settings/plans", icon: "cpu", color: .purple)
            portalButton(title: "何でも屋クラウド請求", urlString: "https://nanndemoya.online/billing", icon: "server.rack", color: .orange)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func portalButton(title: String, urlString: String, icon: String, color: Color) -> some View {
        let isSelected = currentURLString == urlString

        return Button(action: {
            currentURLString = urlString
            if let targetURL = URL(string: urlString) {
                activeURL = targetURL
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? color.opacity(0.18) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Address Bar
    private var browserAddressBar: some View {
        HStack(spacing: 12) {
            // ナビゲーション操作
            HStack(spacing: 4) {
                Button(action: {
                    // WebKitの戻るはCoordinator内部連携可能
                }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)

                Button(action: {
                    // WebKitの進む
                }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)

                Button(action: {
                    if let targetURL = URL(string: currentURLString) {
                        activeURL = targetURL
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.plain)

            // SSL保護アイコン & URLフィールド
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(.green)

                TextField("URLを入力...", text: $currentURLString)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .onSubmit {
                        var target = currentURLString
                        if !target.hasPrefix("http://") && !target.hasPrefix("https://") {
                            target = "https://" + target
                            currentURLString = target
                        }
                        if let url = URL(string: target) {
                            activeURL = url
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

            // 外部ブラウザ（Safari等）で開く
            Button(action: {
                if let url = URL(string: currentURLString) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.plain)
            .help("システムのデフォルトブラウザで開く")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
