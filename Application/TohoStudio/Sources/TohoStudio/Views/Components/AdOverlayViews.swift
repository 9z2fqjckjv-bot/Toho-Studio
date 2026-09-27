import SwiftUI

public struct AdOverlayView: View {
    @ObservedObject var adManager = AdManager.shared

    public init() {}

    public var body: some View {
        Group {
            // File Processing Ad
            if adManager.isFileAdActive {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            adManager.dismissFileProcessingAd()
                        }

                    VStack(spacing: 16) {
                        HStack {
                            Label("スポンサー広告 (Google AdSense)", systemImage: "megaphone.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { adManager.dismissFileProcessingAd() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 140)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "cloud.rainbow.half.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(.purple)
                                        Text("NanndemoyaCloud 超高速クラウドストレージ")
                                            .font(.headline)
                                            .bold()
                                        Text("東方Project二次創作作品の大容量バックアップ＆複数Mac同期")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )

                            HStack {
                                Text("※「広告フリー券」を購入すると、この広告を非表示にできます。")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("閉じる") {
                                    adManager.dismissFileProcessingAd()
                                }
                                .keyboardShortcut(.cancelAction)
                            }
                        }
                    }
                    .padding(20)
                    .frame(width: 480)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 16)
                }
                .zIndex(200)
            }

            // Long Processing Ad
            if adManager.isLongProcessingAdActive {
                ZStack {
                    Color.black.opacity(0.55)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 18) {
                        HStack {
                            Label("バックグラウンド処理実行中（1分以上の長時間処理）", systemImage: "hourglass")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }

                        ProgressView("動画エンコード・AI生成・スライド解析を処理しています...")
                            .progressViewStyle(LinearProgressViewStyle())

                        VStack(spacing: 10) {
                            Text("Google AdSense スポンサー提供枠")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [Color.indigo.opacity(0.25), Color.pink.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 120)
                                .overlay(
                                    HStack(spacing: 16) {
                                        Image(systemName: "cpu.fill")
                                            .font(.system(size: 44))
                                            .foregroundColor(.indigo)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Google Cloud 仮想Linux LLM Dedicated PC")
                                                .font(.headline)
                                                .bold()
                                            Text("24時間自動運転・月間100ドル枠内でフル稼働")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                )
                        }

                        HStack {
                            Text("処理が完了すると自動的に画面が閉じます。")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("完了・閉じる") {
                                adManager.dismissLongProcessingAd()
                            }
                        }
                    }
                    .padding(24)
                    .frame(width: 560)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(14)
                    .shadow(radius: 20)
                }
                .zIndex(201)
            }

            // Trial Video Ad (Blocking modal until countdown finishes)
            if adManager.isTrialVideoAdActive {
                ZStack {
                    Color.black.opacity(0.85)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 20) {
                        HStack {
                            Image(systemName: "film.fill")
                                .foregroundColor(.orange)
                            Text("お試し動画広告（再生中）")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Text("残り \(adManager.trialAdCountdown) 秒")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.yellow)
                        }

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .frame(height: 240)
                            .overlay(
                                VStack(spacing: 14) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 64))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Nanndemoya365 × Toho-Studio プレミアム連携動画")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.white)
                                    Text("動画広告を最後まで視聴すると、対象の有料機能が1回分アンロックされます。")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            )

                        HStack {
                            Text("本日の利用状況: \(adManager.trialAdUsedToday) / \(adManager.trialAdMaxPerDay) 回")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            if adManager.trialAdCountdown == 0 {
                                Button("機能を開始する") {
                                    adManager.isTrialVideoAdActive = false
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Text("※動画視聴中は他の操作はできません")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(28)
                    .frame(width: 640)
                    .background(Color(NSColor.darkGray).opacity(0.95))
                    .cornerRadius(16)
                    .shadow(radius: 24)
                }
                .zIndex(202)
            }
        }
    }
}
