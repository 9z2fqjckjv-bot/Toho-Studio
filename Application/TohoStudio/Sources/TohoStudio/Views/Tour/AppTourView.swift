import SwiftUI

public struct AppTourView: View {
    @ObservedObject var appState = AppState.shared
    @State private var currentStep: Int = 0

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                AppLogoView(size: 26, cornerRadius: 6)
                Text("Toho-Studio へようこそ")
                    .font(.title2)
                    .bold()
                Spacer()
                Text("ステップ \(currentStep + 1) / 5")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Step Content
            VStack(spacing: 20) {
                switch currentStep {
                case 0:
                    tourIntroductionStep
                case 1:
                    tourModulesStep
                case 2:
                    termsAndPolicyStep
                case 3:
                    accountSelectionStep
                case 4:
                    tourCompletionStep
                default:
                    EmptyView()
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation Bar
            HStack {
                if currentStep > 0 {
                    Button("戻る") {
                        currentStep -= 1
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                }
                Spacer()
                if currentStep < 4 {
                    Button("次に進む") {
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                } else {
                    Button("Toho-Studio を始める") {
                        appState.hasCompletedTour = true
                        appState.activeModal = nil
                        appState.addHistory("ツアー完了: メイン編集画面へ移行")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 720, height: 540)
    }

    // Step 0: Welcome & Overview
    private var tourIntroductionStep: some View {
        VStack(spacing: 16) {
            AppLogoView(size: 88, cornerRadius: 18)
            Text("東方Project 二次創作クリエイティブスイート")
                .font(.title3)
                .bold()
            Text("Toho-Studio は、動画、キャラクター、音声合成、スライド台本、ゲーム制作、素材管理のすべてを統合したMacネイティブの総合制作環境です。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
    }

    // Step 1: Software Modules
    private var tourModulesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("6つの内蔵クリエイティブソフト")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(SoftwareModule.allCases) { mod in
                    HStack(spacing: 12) {
                        Image(systemName: mod.iconName)
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mod.rawValue).font(.subheadline).bold()
                            Text(mod.baseModel).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    // Step 2: Terms and Policies
    private var termsAndPolicyStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("利用規約とポリシーへの同意")
                .font(.headline)
            Text("東方Project二次創作ガイドラインおよびToho-Studio利用規約、プライバシーポリシー、特定商取引法に基づく表記を確認してください。")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("【Toho-Studio 利用規約】").bold()
                    Text("本ソフトウェアは東方Projectの二次創作活動を支援するための統合制作環境です。本ソフトウェアで作成された作品の著作権は創作者に帰属し、東方Project原作者（上海アリス幻樂団）の二次創作ガイドラインを遵守してご利用いただけます。")
                    Text("【有料機能と何でも屋クラウド】").bold()
                    Text("クラウド保存・AI拡張・ライセンス連携などの有料機能は「何でも屋」により快適性を向上させる目的で提供されます。")
                }
                .font(.caption)
                .padding(8)
            }
            .frame(height: 140)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(6)

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("利用規約、プライバシーポリシーに同意します")
                    .font(.callout)
            }
        }
    }

    // Step 3: Account Selection
    private var accountSelectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("利用アカウントの選択")
                .font(.headline)
            Text("Toho-Studio で使用するアカウントを選択してください。後から設定画面でいつでも変更可能です。")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                accountOptionRow(title: "NanndemoyaCloud", subtitle: "大容量ドライブ連携、AI特典、チーム同期機能がフル活用できます", icon: "cloud.fill", type: "NanndemoyaCloud")
                accountOptionRow(title: "Google アカウント", subtitle: "マイドライブ連携、GoogleWorkspaceドライブ保存に対応", icon: "person.crop.circle.badge.checkmark", type: "Google")
                accountOptionRow(title: "ローカルアカウント", subtitle: "PCローカルのみで完結。ネットワーク通信なしで利用可能", icon: "laptopcomputer", type: "Local")
            }
        }
    }

    private func accountOptionRow(title: String, subtitle: String, icon: String, type: String) -> some View {
        Button(action: {
            appState.currentAccountType = type
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(appState.currentAccountType == type ? .white : .accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundColor(appState.currentAccountType == type ? .white : .primary)
                    Text(subtitle).font(.caption).foregroundColor(appState.currentAccountType == type ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
                if appState.currentAccountType == type {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(appState.currentAccountType == type ? Color.accentColor : Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // Step 4: Completion
    private var tourCompletionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("初期設定が完了しました！")
                .font(.title3)
                .bold()
            Text("さあ、Toho-Studio であなただけの東方作品を創り出しましょう。\nショートカットキー (cmd+t, cmd+f, cmd+e, cmd+d, cmd+p, cmd+w, cmd+h) や上部メニューバーからすべての機能にアクセスできます。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
        }
    }
}
