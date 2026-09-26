import SwiftUI
import WebKit
import AppKit

public struct InAppBrowserView: View {
    public let initialURL: URL
    public let customTitle: String?
    @Binding public var isPresented: Bool

    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isLoading: Bool = false
    @State private var currentTitle: String = ""
    @State private var currentURLString: String = ""
    private let webView: WKWebView

    public init(url: URL, title: String? = nil, isPresented: Binding<Bool>) {
        self.initialURL = url
        self.customTitle = title
        self._isPresented = isPresented
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        self.webView = WKWebView(frame: .zero, configuration: config)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Browser Navigation Bar
            HStack(spacing: 12) {
                // Back Button
                Button(action: { webView.goBack() }) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 14, weight: .bold))
                }
                .disabled(!canGoBack)
                .buttonStyle(.plain)

                // Forward Button
                Button(action: { webView.goForward() }) {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 14, weight: .bold))
                }
                .disabled(!canGoForward)
                .buttonStyle(.plain)

                // Reload Button
                Button(action: { webView.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.plain)

                // Address & Title Bar
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(currentTitle.isEmpty ? (customTitle ?? initialURL.absoluteString) : currentTitle)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(currentURLString.isEmpty ? initialURL.host ?? "" : currentURLString)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.12)))

                // Open in External Safari
                Button(action: {
                    if let url = webView.url ?? URL(string: currentURLString) ?? initialURL as URL? {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "safari")
                        .font(.system(size: 15))
                        .foregroundColor(.blue)
                }
                .help("Safariで開く")
                .buttonStyle(.plain)

                // Close Button
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            if isLoading {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            } else {
                Divider()
            }

            // Web View
            BrowserWebRepresentable(
                url: initialURL,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                pageTitle: $currentTitle,
                pageURL: $currentURLString,
                webView: webView
            )
        }
        .frame(minWidth: 880, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
    }
}

public struct BrowserWebRepresentable: NSViewRepresentable {
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
        var parent: BrowserWebRepresentable

        init(_ parent: BrowserWebRepresentable) {
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
