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
            ZStack(alignment: .top) {
                // 背景：画像の外枠と調和するダークグレー
                Color(red: 0.28, green: 0.28, blue: 0.29)
                    .edgesIgnoringSafeArea(.all)

                // メインコンテンツエリア
                VStack(spacing: 0) {
                    // 上部クイック操作バー（どの画面サイズでも確実にすぐ戻れる補助バー）
                    HStack(spacing: 12) {
                        Button(action: {
                            handleBack()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.backward.circle.fill")
                                    .font(.system(size: 15))
                                Text("前の画面に戻る")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("前の画面に戻る (Esc)")

                        Spacer()

                        Button(action: {
                            handleContact()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 15))
                                Text("お問い合わせ")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("お問い合わせフォームを開く")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))

                    // 画像描画＆ボタンオーバーレイ領域
                    let availableHeight = max(100, geometry.size.height - 45)
                    ZStack {
                        if let nsImage = NSImage(contentsOfFile: imagePath) {
                            let imgW = nsImage.size.width
                            let imgH = nsImage.size.height
                            let aspect = imgW / (imgH > 0 ? imgH : 1)

                            let fitW = min(geometry.size.width, availableHeight * aspect)
                            let fitH = fitW / aspect

                            // 画像本体
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: fitW, height: fitH)
                                .overlay(
                                    // 画像内のボタン位置にぴったり重なるオーバーレイ
                                    // Left Button ("前の画面に戻る"): X: 17.4% ~ 38.4%, Y: 70.8% ~ 81.6%
                                    // Right Button ("問い合わせる"): X: 53.7% ~ 74.6%, Y: 70.8% ~ 81.6%
                                    ZStack(alignment: .topLeading) {
                                        // 1. 前の画面に戻る ボタン
                                        Button(action: {
                                            handleBack()
                                        }) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(isHoveringBack ? 0.28 : 0.001))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(isHoveringBack ? Color.white.opacity(0.85) : Color.clear, lineWidth: 2)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Rectangle())
                                        .frame(width: fitW * 0.210, height: fitH * 0.108)
                                        .offset(x: fitW * 0.174, y: fitH * 0.708)
                                        .onHover { hovering in
                                            isHoveringBack = hovering
                                        }
                                        .help("前の画面に戻る")

                                        // 2. 問い合わせる ボタン
                                        Button(action: {
                                            handleContact()
                                        }) {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(isHoveringContact ? 0.28 : 0.001))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(isHoveringContact ? Color.white.opacity(0.85) : Color.clear, lineWidth: 2)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .contentShape(Rectangle())
                                        .frame(width: fitW * 0.209, height: fitH * 0.108)
                                        .offset(x: fitW * 0.537, y: fitH * 0.708)
                                        .onHover { hovering in
                                            isHoveringContact = hovering
                                        }
                                        .help("お問い合わせ（アプリ内ブラウザを開く）")
                                    }
                                    .frame(width: fitW, height: fitH)
                                )
                        } else {
                            // フォールバック表示
                            VStack(spacing: 24) {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .keyboardShortcut(.cancelAction) // Escキーで前の画面に戻る
    }

    private func handleBack() {
        if let onBack = onBack {
            onBack()
        } else {
            appState.navigateBackFromUnavailable()
        }
    }

    private func handleContact() {
        appState.openInAppBrowser(url: contactURL, title: "お問い合わせ")
    }
}
