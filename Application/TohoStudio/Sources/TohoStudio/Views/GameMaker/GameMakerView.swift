import SwiftUI

public struct GameMakerView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isTestPlaying: Bool = false
    @State private var currentTestSceneIndex: Int = 1
    @State private var playerGold: Int = 500
    @State private var playerHealth: Int = 100
    @State private var playerSpells: [String] = ["夢想封印", "八方鬼縛陣"]

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 14) {
                Label("ゲームメーカー", systemImage: "gamecontroller")
                    .font(.headline)
                Text("(横長ワイド東方RPG / ノベルゲーム制作エンジン)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    isTestPlaying.toggle()
                    appState.log("テストプレイを \(isTestPlaying ? "開始" : "終了") しました")
                }) {
                    Label(isTestPlaying ? "テストプレイ終了" : "テストプレイ開始", systemImage: isTestPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if isTestPlaying {
                gameTestPlayScreen
            } else {
                gameEditorScreen
            }
        }
    }

    // MARK: - Game Editor Screen
    private var gameEditorScreen: some View {
        HSplitView {
            // Left: Game Scene Map & Command Graph
            VStack(alignment: .leading, spacing: 12) {
                Text("ゲームフローチャート＆コマンド分岐")
                    .font(.headline)

                List {
                    ForEach(appState.gameCommands) { cmd in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("シーン #\(cmd.sceneIndex)")
                                    .font(.caption2)
                                    .bold()
                                    .padding(2)
                                    .background(Color.accentColor.opacity(0.3))
                                    .cornerRadius(3)
                                Text("コマンド: \(cmd.commandType)")
                                    .font(.caption)
                                    .bold()
                                Spacer()
                                if let target = cmd.targetScene {
                                    Text("→ シーン #\(target)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                            Text(cmd.promptText)
                                .font(.callout)
                        }
                        .padding(6)
                    }
                }

                Button(action: {
                    let newCmd = GameCommand(
                        sceneIndex: appState.gameCommands.count + 1,
                        commandType: "選択肢",
                        promptText: "新しい選択肢分岐を追加",
                        targetScene: appState.gameCommands.count + 2
                    )
                    appState.gameCommands.append(newCmd)
                }) {
                    Label("分岐コマンド追加", systemImage: "plus")
                }
            }
            .padding()
            .frame(minWidth: 400, maxWidth: .infinity)

            // Right: Player & Game Parameters Inspector
            VStack(alignment: .leading, spacing: 14) {
                Text("プレイヤー設定＆グローバル変数")
                    .font(.headline)

                GroupBox(label: Text("プレイヤー初期パラメータ")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("初期所持金 (円):")
                            Spacer()
                            Text("\(playerGold)").bold()
                        }
                        Slider(value: Binding(
                            get: { Double(playerGold) },
                            set: { playerGold = Int($0) }
                        ), in: 0...5000, step: 100)

                        HStack {
                            Text("初期体力 (HP):")
                            Spacer()
                            Text("\(playerHealth)").bold()
                        }
                        Slider(value: Binding(
                            get: { Double(playerHealth) },
                            set: { playerHealth = Int($0) }
                        ), in: 50...200, step: 10)
                    }
                    .padding(6)
                }

                GroupBox(label: Text("習得スペルカード一覧")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(playerSpells, id: \.self) { spell in
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text(spell).font(.caption)
                            }
                        }
                    }
                    .padding(6)
                }

                Spacer()
            }
            .padding()
            .frame(width: 300)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        }
    }

    // MARK: - Game Test Play Screen
    private var gameTestPlayScreen: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack {
                // Top HUD
                HStack(spacing: 24) {
                    HStack {
                        Image(systemName: "heart.fill").foregroundColor(.red)
                        Text("HP: \(playerHealth) / 100")
                    }
                    HStack {
                        Image(systemName: "dollarsign.circle.fill").foregroundColor(.yellow)
                        Text("所持金: \(playerGold) 円")
                    }
                    Spacer()
                    Text("シーン \(currentTestSceneIndex): 幻想郷異変調査")
                        .foregroundColor(.white.opacity(0.8))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))

                Spacer()

                // Visual Representation
                VStack(spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    Text("横長ワイドスクリーン RPG テスト実行中")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }

                Spacer()

                // Dialog and Choices Box
                VStack(alignment: .leading, spacing: 12) {
                    Text("霊夢「前方に妖気を感じるわ。どうする？」")
                        .font(.title3)
                        .foregroundColor(.white)

                    HStack(spacing: 16) {
                        Button(action: {
                            currentTestSceneIndex = 2
                            appState.log("テストプレイ: 選択肢1 [正面突破] を選択")
                        }) {
                            Text("1. お札を構えて正面突破する")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            currentTestSceneIndex = 3
                            appState.log("テストプレイ: 選択肢2 [様子見] を選択")
                        }) {
                            Text("2. 草むらに隠れて様子を伺う")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.purple.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.85))
                .cornerRadius(12)
                .padding(24)
            }
        }
    }
}
