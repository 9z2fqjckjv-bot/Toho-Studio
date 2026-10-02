import SwiftUI
import AppKit

/// 仕様書スライド 26 に記載された「アプリトップ」画面
public struct AppTopScreenView: View {
    @ObservedObject var appState = AppState.shared
    @State private var hoveredModule: SoftwareModule? = nil

    public init() {}

    public var body: some View {
        ZStack {
            // 仕様書スライド26準拠の鮮やかなスカイブルー背景
            Color(red: 0.0, green: 0.62, blue: 1.0)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // 1. タイトル「アプリトップ」 (スライド26中央上部)
                Text("アプリトップ")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.35, blue: 0.65))
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 2)

                Spacer().frame(height: 50)

                // 2. 内蔵ソフト一覧アイコン (スライド26中央部 & 新版仕様書)
                HStack(spacing: 12) {
                    ForEach(SoftwareModule.allCases) { module in
                        appTopModuleButton(module: module)
                    }
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 50)

                // 3. アクションボタン群 (機能リスト / 設定 / アプリを終了 - スライド26下部)
                HStack(spacing: 30) {
                    specActionButton(title: "機能リスト") {
                        appState.activeModal = .featureList
                    }

                    specActionButton(title: "設定") {
                        appState.activeModal = .settings
                    }

                    specActionButton(title: "アプリを終了") {
                        NSApplication.shared.terminate(nil)
                    }
                }

                Spacer()

                // 4. フッターコピーライト (スライド26最下部)
                Text("Toho-Studio V1.0.0 Powerd By zuyasi & Nanndemoya")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: - 仕様書スライド26準拠のモジュールアイコンボタン
    private func appTopModuleButton(module: SoftwareModule) -> some View {
        let isHovered = hoveredModule == module

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.currentModule = module
                appState.isShowingAppTop = false
                appState.addHistory("アプリトップからソフト起動: \(module.rawValue)")
            }
        }) {
            VStack(spacing: 16) {
                // 上部タイトル
                Text(module == .tohoAIStudio ? "TohoAI\nStudio" : module.rawValue)
                    .font(.system(size: module == .tohoAIStudio ? 15 : 16, weight: .heavy))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(height: 44)

                // スライド26の象徴的な黒シルエットアイコン
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isHovered ? Color.white.opacity(0.2) : Color.clear)
                        .frame(width: 104, height: 104)

                    Image(systemName: iconForModule(module))
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.black)
                        .scaleEffect(isHovered ? 1.08 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
                }
                .shadow(color: isHovered ? Color.black.opacity(0.25) : Color.clear, radius: 8, y: 4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 2)
            .frame(width: 116)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredModule = hovering ? module : nil
        }
    }

    private func iconForModule(_ module: SoftwareModule) -> String {
        switch module {
        case .movieMaker:
            return "film.fill" // カチンコ・映画フィルム
        case .soundMaker:
            return "music.note" // 音符アイコン
        case .gameMaker:
            return "gamecontroller.fill" // ゲームコントローラー
        case .slideScenarioMaker:
            return "rectangle.inset.filled" // スライド・シナリオ額縁
        case .characterMaker:
            return "person.crop.artframe" // キャラクター立ち絵
        case .materialStudio:
            return "books.vertical.fill" // 素材スタック
        case .tohoAIStudio:
            return "sparkles.rectangle.stack.fill" // 東方AIスタジオ
        }
    }

    // MARK: - 仕様書スライド26の黒色角丸ボタン
    private func specActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 190, height: 56)
                .background(Color.black)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
