# TohoStudio認証システム  
  
```
import SwiftUI
import WebKit

// WKScriptMessageHandlerを処理するクラス
class WebKitBridge: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "accountHandler", let dict = message.body as? [String: Any] {
            let email = dict["email"] as? String ?? ""
            let name = dict["name"] as? String ?? ""
            let phone = dict["phone"] as? String ?? ""
            let birthday = dict["birthday"] as? String ?? ""
            
            print("--- 受信したアカウント情報 ---")
            print("Email: \(email)")
            print("Name: \(name)")
            print("Phone: \(phone)")
            print("Birthday: \(birthday)")
            
            // TODO: アプリ内でのサインイン処理やデータ保持へ渡す
        }
    }
}

// macOS SwiftUI用 WKWebView ラッパー
struct WebView: NSViewRepresentable {
    let url: URL
    let bridge = WebKitBridge()

    func makeNSView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        // GAS側で呼び出す window.webkit.messageHandlers.accountHandler と名前を合わせる
        contentController.add(bridge, name: "accountHandler")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        nsView.load(request)
    }
}

```
