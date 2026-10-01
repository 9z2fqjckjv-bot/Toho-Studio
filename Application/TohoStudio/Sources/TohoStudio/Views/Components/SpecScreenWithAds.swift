import SwiftUI
import AppKit

// MARK: - 仕様書準拠 左右広告枠レイアウトコンテナ (スライド 179, 180, 193, 215-219, 229-231)
public struct SpecScreenWithAds<Content: View>: View {
    public let screenTitle: String
    public let content: Content

    @ObservedObject var appState = AppState.shared
    @ObservedObject var adManager = AdManager.shared

    public init(screenTitle: String, @ViewBuilder content: () -> Content) {
        self.screenTitle = screenTitle
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 仕様書上部ヘッダーバー (スライド上部再現)
            HStack(spacing: 0) {
                // 左上「コントロールバー」表記
                HStack {
                    Text("コントロールバー")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.black)
                }

                Spacer()

                // 日時とアカウント名
                HStack(spacing: 12) {
                    Text(currentDateFormatted())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Text("(\(appState.userName))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 20)

                // 画面タイトル (「ホーム画面」「読込画面」など)
                Text(screenTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.trailing, 28)
            }
            .frame(height: 38)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // メインエリア: [左側 広告枠] [中央 コンテンツ] [右側 広告枠]
            HStack(spacing: 0) {
                // 左側 Google広告枠 (仕様書指定箇所)
                GoogleAdBannerView(slot: .left, bannerTitle: "広告枠")
                    .frame(width: 260)

                // 中央メインコンテンツ領域 (仕様書準拠のダークスレートグレー背景)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.38, green: 0.40, blue: 0.42))

                // 右側 Google広告枠 (仕様書指定箇所)
                GoogleAdBannerView(slot: .right, bannerTitle: "広告枠")
                    .frame(width: 260)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func currentDateFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: Date())
    }
}

// MARK: - 仕様書スタイルの吹き出し付き選択ボタン
public struct SpecOptionButton: View {
    public let title: String
    public let description: String
    public var isBlack: Bool = false
    public var isPink: Bool = false
    public let action: () -> Void

    public init(
        title: String,
        description: String,
        isBlack: Bool = false,
        isPink: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.isBlack = isBlack
        self.isPink = isPink
        self.action = action
    }

    private var buttonColor: Color {
        if isBlack {
            return Color.black
        } else if isPink {
            return Color(red: 0.95, green: 0.25, blue: 0.55)
        } else {
            return Color(red: 0.0, green: 0.65, blue: 1.0) // 仕様書の鮮やかなスカイブルー
        }
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 左ボタン部分
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 200, height: 50)
                    .background(buttonColor)
                    .cornerRadius(4)

                // 吹き出し矢印 & 説明ボックス
                HStack(spacing: 0) {
                    // 吹き出し三角
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(buttonColor)
                        .rotationEffect(.degrees(-90))
                        .offset(x: 2)

                    // 説明テキスト
                    Text(description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minWidth: 260, alignment: .leading)
                        .background(buttonColor)
                        .cornerRadius(4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 仕様書 スライド 179: ムービーメーカー ホーム画面
public struct MovieMakerSpecHomeView: View {
    @ObservedObject var appState = AppState.shared
    public var onStartEmpty: () -> Void
    public var onImportSlideScenario: () -> Void
    public var onImportYmmp: () -> Void
    public var onLoadExisting: () -> Void

    public init(
        onStartEmpty: @escaping () -> Void,
        onImportSlideScenario: @escaping () -> Void,
        onImportYmmp: @escaping () -> Void,
        onLoadExisting: @escaping () -> Void
    ) {
        self.onStartEmpty = onStartEmpty
        self.onImportSlideScenario = onImportSlideScenario
        self.onImportYmmp = onImportYmmp
        self.onLoadExisting = onLoadExisting
    }

    public var body: some View {
        SpecScreenWithAds(screenTitle: "ホーム画面") {
            VStack(spacing: 24) {
                Spacer()

                Text("いずれかを選択")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 18) {
                    SpecOptionButton(
                        title: "スライド＆シナリオメー\nカーから読み込み",
                        description: "スライド＆シナリオメーカーの編集ファ\nイルを読み込み、動画を作成します。",
                        action: onImportSlideScenario
                    )

                    SpecOptionButton(
                        title: "YMMV4を直接読み込み",
                        description: "ゆっくりムービーメーカー（ymmp）の編集\nファイルから動画を作成します。",
                        action: onImportYmmp
                    )

                    SpecOptionButton(
                        title: "空のファイルを作成",
                        description: "タイムラインに何も入れずに、\n編集ファイルを１から作成します。",
                        action: onStartEmpty
                    )

                    SpecOptionButton(
                        title: "既存ファイルの読み込み",
                        description: "既存のファイル（tsvm）を読み込みます。",
                        action: onLoadExisting
                    )

                    SpecOptionButton(
                        title: "アプリ拡張を購入",
                        description: "設定＞有料機能＞アプリ拡張＞ムービーメー\nカーの項目に飛びます。",
                        isBlack: true,
                        action: {
                            appState.activeModal = .settings
                        }
                    )
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 仕様書 スライド 180 / 219: 読込中画面 (左右広告枠付き)
public struct SpecLoadingScreenWithAds: View {
    public let statusMessage: String
    public let onCancel: () -> Void

    @State private var spinAnimation: Double = 0.0

    public init(statusMessage: String = "読み込み中…", onCancel: @escaping () -> Void) {
        self.statusMessage = statusMessage
        self.onCancel = onCancel
    }

    public var body: some View {
        SpecScreenWithAds(screenTitle: "読込画面") {
            VStack(spacing: 36) {
                Spacer()

                VStack(spacing: 8) {
                    Text(statusMessage)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("（ステータス: 処理中）")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }

                // スライド180再現の点線スピナー
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(spinAnimation))
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                            spinAnimation = 360.0
                        }
                    }

                Button(action: onCancel) {
                    Text("Escでキャンセル")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Spacer()

                // 下部エラー時ガイダンス表示
                Text("異常検知時（エラー時）には、すぐに内容を\nポップアップで表示→ホーム画面に移動")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.black)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 仕様書 スライド 193: キャラクターメーカー ホーム画面
public struct CharacterMakerSpecHomeView: View {
    @ObservedObject var appState = AppState.shared
    public var onImportMaterial: () -> Void
    public var onImportJpg: () -> Void
    public var onStartEmpty: () -> Void
    public var onLoadExisting: () -> Void

    public init(
        onImportMaterial: @escaping () -> Void,
        onImportJpg: @escaping () -> Void,
        onStartEmpty: @escaping () -> Void,
        onLoadExisting: @escaping () -> Void
    ) {
        self.onImportMaterial = onImportMaterial
        self.onImportJpg = onImportJpg
        self.onStartEmpty = onStartEmpty
        self.onLoadExisting = onLoadExisting
    }

    public var body: some View {
        SpecScreenWithAds(screenTitle: "ホーム画面") {
            VStack(spacing: 24) {
                Spacer()

                Text("いずれかを選択")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 18) {
                    SpecOptionButton(
                        title: "素材スタジオから読み込む",
                        description: "素材スタジオからファイルを読み込みます。",
                        action: onImportMaterial
                    )

                    SpecOptionButton(
                        title: "jpgファイルを読み込む",
                        description: "JPEG画像を読み込みます。",
                        action: onImportJpg
                    )

                    SpecOptionButton(
                        title: "空のファイルを作成",
                        description: "空っぽのファイルを作成します。",
                        action: onStartEmpty
                    )

                    SpecOptionButton(
                        title: "既存ファイルの読み込み",
                        description: "既存のファイル（tscm）を読み込みます。",
                        action: onLoadExisting
                    )

                    SpecOptionButton(
                        title: "アプリ拡張を購入",
                        description: "設定＞有料機能＞アプリ拡張＞キャラクター\nメーカーの項目に飛びます。",
                        isBlack: true,
                        action: {
                            appState.activeModal = .settings
                        }
                    )
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 仕様書 スライド 215: サウンドメーカー ホーム画面
public struct SoundMakerSpecHomeView: View {
    @ObservedObject var appState = AppState.shared
    public var onImportMaterial: () -> Void
    public var onImportMp3: () -> Void
    public var onGenerateVoice: () -> Void
    public var onStartEmpty: () -> Void
    public var onLoadExisting: () -> Void

    public init(
        onImportMaterial: @escaping () -> Void,
        onImportMp3: @escaping () -> Void,
        onGenerateVoice: @escaping () -> Void,
        onStartEmpty: @escaping () -> Void,
        onLoadExisting: @escaping () -> Void
    ) {
        self.onImportMaterial = onImportMaterial
        self.onImportMp3 = onImportMp3
        self.onGenerateVoice = onGenerateVoice
        self.onStartEmpty = onStartEmpty
        self.onLoadExisting = onLoadExisting
    }

    public var body: some View {
        SpecScreenWithAds(screenTitle: "ホーム画面") {
            VStack(spacing: 24) {
                Spacer()

                Text("いずれかを選択")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 18) {
                    SpecOptionButton(
                        title: "素材スタジオから読み込む",
                        description: "素材スタジオからファイルを読み込みます。",
                        action: onImportMaterial
                    )

                    SpecOptionButton(
                        title: "mp3ファイルを読み込む",
                        description: "MP3の音声ファイルを読み込みます。",
                        action: onImportMp3
                    )

                    SpecOptionButton(
                        title: "セリフ音声ファイルを生成",
                        description: "セリフ音声ファイルを作成し、\n作成したファイルを編集します。",
                        isPink: true,
                        action: onGenerateVoice
                    )

                    SpecOptionButton(
                        title: "空のファイルを作成",
                        description: "空っぽのファイルを作成します。",
                        action: onStartEmpty
                    )

                    SpecOptionButton(
                        title: "既存ファイルの読み込み",
                        description: "既存のファイル（tssm）を読み込みます。",
                        action: onLoadExisting
                    )

                    SpecOptionButton(
                        title: "アプリ拡張を購入",
                        description: "設定＞有料機能＞アプリ拡張＞サウンドメーカー\nの項目に飛びます。",
                        isBlack: true,
                        action: {
                            appState.activeModal = .settings
                        }
                    )
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 仕様書 スライド 229: スライド＆シナリオメーカー ホーム画面
public struct SlideScenarioSpecHomeView: View {
    @ObservedObject var appState = AppState.shared
    public var onDirectExport: () -> Void
    public var onImportSlideOrScript: () -> Void
    public var onStartEmpty: () -> Void
    public var onLoadExisting: () -> Void

    public init(
        onDirectExport: @escaping () -> Void,
        onImportSlideOrScript: @escaping () -> Void,
        onStartEmpty: @escaping () -> Void,
        onLoadExisting: @escaping () -> Void
    ) {
        self.onDirectExport = onDirectExport
        self.onImportSlideOrScript = onImportSlideOrScript
        self.onStartEmpty = onStartEmpty
        self.onLoadExisting = onLoadExisting
    }

    public var body: some View {
        SpecScreenWithAds(screenTitle: "ホーム画面") {
            VStack(spacing: 24) {
                Spacer()

                Text("いずれかを選択")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 18) {
                    SpecOptionButton(
                        title: "既存ファイルの\n直接エクスポート",
                        description: "既存のtspmファイルを\n他のソフトにエクスポートします。",
                        action: onDirectExport
                    )

                    SpecOptionButton(
                        title: "スライドファイル、または\n台本ファイルの読み込み",
                        description: "PowerPoint,Keynote,Googleスライ\nド,txt,md,csvのいずれかを読み込みます。",
                        action: onImportSlideOrScript
                    )

                    SpecOptionButton(
                        title: "空のファイルを作成",
                        description: "ソフトに何も入れずに、\n編集ファイルを１から作成します。",
                        action: onStartEmpty
                    )

                    SpecOptionButton(
                        title: "既存ファイルの読み込み",
                        description: "既存のファイル（tspm）を読み込みます。",
                        action: onLoadExisting
                    )

                    SpecOptionButton(
                        title: "アプリ拡張を購入",
                        description: "設定＞有料機能＞アプリ拡張＞スライド＆シ\nナリオメーカーの項目に飛びます。",
                        isBlack: true,
                        action: {
                            appState.activeModal = .settings
                        }
                    )
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
