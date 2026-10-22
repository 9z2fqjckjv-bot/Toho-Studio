import SwiftUI
import AppKit

/// 有料機能、クラウド連携、アカウントログイン機能、有料機能設定、ストア等の利用制限時に表示する画面
/// 指示書: "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/機能停止中画面.jpg"
public struct UnavailableFeatureView: View {
    @ObservedObject var appState = AppState.shared
    public var onBack: (() -> Void)? = nil

    private let imagePath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/機能停止中画面.jpg"
    private let contactURL = URL(string: "https://forms.gle/vNofNkf1WugvGNTe8")!

    @State private var isHoveringBack: Bool = false
    @State private var isHoveringContact: Bool = false

    public init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景：画像の外枠と調和するダークグレー
                Color(red: 0.28, green: 0.28, blue: 0.29)
                    .edgesIgnoringSafeArea(.all)

                if let nsImage = NSImage(contentsOfFile: imagePath) {
                    let imgW = nsImage.size.width
                    let imgH = nsImage.size.height
                    let aspect = imgW / (imgH > 0 ? imgH : 1)

                    let fitW = min(geometry.size.width, geometry.size.height * aspect)
                    let fitH = fitW / aspect

                    ZStack {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: fitW, height: fitH)

                        // 画像内の「前の画面に戻る」ボタン位置
                        // X: 17.4% 〜 38.4% (幅 21.0%、中心 27.9%)
                        // Y: 70.8% 〜 81.6% (高さ 10.8%、中心 76.2%)
                        Button(action: {
                            handleBack()
                        }) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isHoveringBack ? Color.white.opacity(0.18) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .frame(width: fitW * 0.21, height: fitH * 0.108)
                        .position(x: fitW * 0.279, y: fitH * 0.762)
                        .onHover { hovering in
                            isHoveringBack = hovering
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .help("前の画面に戻る")

                        // 画像内の「問い合わせる」ボタン位置
                        // X: 53.7% 〜 74.6% (幅 20.9%、中心 64.15%)
                        // Y: 70.8% 〜 81.6% (高さ 10.8%、中心 76.2%)
                        Button(action: {
                            handleContact()
                        }) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isHoveringContact ? Color.white.opacity(0.18) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .frame(width: fitW * 0.209, height: fitH * 0.108)
                        .position(x: fitW * 0.6415, y: fitH * 0.762)
                        .onHover { hovering in
                            isHoveringContact = hovering
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .help("お問い合わせ（アプリ内ブラウザを開く）")
                    }
                    .frame(width: fitW, height: fitH)
                } else {
                    // フォールバック表示
                    VStack(spacing: 20) {
                        Text("今現在、この機能は諸事情により利用できません。")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("お手数おかけしますが、v3.0.0への大型アップデートをお待ちいただくか、お問い合わせください。")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))

                        HStack(spacing: 40) {
                            Button(action: { handleBack() }) {
                                Text("前の画面に戻る")
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: { handleContact() }) {
                                Text("問い合わせる")
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.cyan)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleBack() {
        if let onBack = onBack {
            onBack()
        } else {
            if appState.activeModal != nil {
                appState.activeModal = nil
            } else {
                withAnimation {
                    appState.isShowingAppTop = true
                }
            }
        }
    }

    private func handleContact() {
        appState.openInAppBrowser(url: contactURL, title: "お問い合わせ")
    }
}
