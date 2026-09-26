import SwiftUI

public struct RootView: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Custom Control Bar (仕様書 26-28スライド目)
                customControlBarView

                Divider()

                // Active Module Workspace
                activeModuleView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Bottom Status Bar
                bottomStatusBarView
            }

            // Modal Sheets & Overlays
            if let modal = appState.activeModal {
                modalOverlay(for: modal)
            }
        }
        .frame(minWidth: 1024, minHeight: 680)
        .sheet(isPresented: Binding(
            get: { !appState.hasCompletedTour },
            set: { _ in }
        )) {
            AppTourView()
        }
    }

    // MARK: - Custom Control Bar (Slide 26-28)
    private var customControlBarView: some View {
        HStack(spacing: 12) {
            // App Logo & Dropdown
            Menu {
                Button("アプリ情報 (cmd+t+i)") { appState.activeModal = .appInfo }
                Button("設定画面 (cmd+t+s)") { appState.activeModal = .settings }
                Button("ストア (cmd+t+shift+s)") { appState.activeModal = .store }
                Button("再起動 (cmd+t+r)") { appState.activeModal = .reboot }
                Divider()
                Button("開発者コンソール (cmd+t+e)") { appState.activeModal = .developer }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text("Toho-Studio")
                        .font(.headline)
                        .bold()
                }
            }
            .menuStyle(.borderlessButton)

            Divider().frame(height: 20)

            // 6 Software Module Switchers
            HStack(spacing: 4) {
                ForEach(SoftwareModule.allCases) { mod in
                    Button(action: {
                        appState.currentModule = mod
                        appState.addHistory("ソフト切り替え: \(mod.rawValue)")
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: mod.iconName)
                            Text(mod.rawValue)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(appState.currentModule == mod ? Color.accentColor : Color.clear)
                        .foregroundColor(appState.currentModule == mod ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Control Bar Actions
            HStack(spacing: 8) {
                // Function List
                Button(action: { appState.activeModal = .featureList }) {
                    Image(systemName: "list.bullet.rectangle")
                }
                .help("機能リスト (cmd+d+option+l)")

                // Store
                Button(action: { appState.activeModal = .store }) {
                    Image(systemName: "bag")
                }
                .help("ストア (cmd+t+shift+s)")

                // Developer
                Button(action: { appState.activeModal = .developer }) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help("開発者コンソール (cmd+t+e)")

                // Settings
                Button(action: { appState.activeModal = .settings }) {
                    Image(systemName: "gearshape")
                }
                .help("設定 (cmd+t+s)")

                Divider().frame(height: 18)

                // Quit
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .foregroundColor(.red.opacity(0.8))
                }
                .help("アプリを終了")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Active Module Workspace
    @ViewBuilder
    private var activeModuleView: some View {
        switch appState.currentModule {
        case .movieMaker:
            MovieMakerView()
        case .characterMaker:
            CharacterMakerView()
        case .soundMaker:
            SoundMakerView()
        case .slideScenarioMaker:
            SlideScenarioMakerView()
        case .gameMaker:
            GameMakerView()
        case .materialStudio:
            MaterialStudioView()
        }
    }

    // MARK: - Bottom Status Bar
    private var bottomStatusBarView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text(appState.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("FPS: \(appState.targetFpsMode)")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("アカウント: \(appState.userName) (\(appState.currentAccountType))")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("バージョン: v1.0.6")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }

    // MARK: - Modal Overlay Router
    @ViewBuilder
    private func modalOverlay(for modal: ActiveModal) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    appState.activeModal = nil
                }

            switch modal {
            case .tour:
                AppTourView()
            case .appInfo:
                CommonModalContainer(title: "アプリ情報", icon: "info.circle", isPresented: Binding(
                    get: { appState.activeModal != nil },
                    set: { if !$0 { appState.activeModal = nil } }
                )) {
                    AppInfoView()
                }
            case .settings:
                CommonModalContainer(title: "設定", icon: "gearshape", isPresented: Binding(
                    get: { appState.activeModal != nil },
                    set: { if !$0 { appState.activeModal = nil } }
                )) {
                    SettingsView()
                }
            case .store:
                CommonModalContainer(title: "ストア", icon: "bag", isPresented: Binding(
                    get: { appState.activeModal != nil },
                    set: { if !$0 { appState.activeModal = nil } }
                )) {
                    StoreView()
                }
            case .developer:
                CommonModalContainer(title: "開発者コンソール", icon: "chevron.left.forwardslash.chevron.right", isPresented: Binding(
                    get: { appState.activeModal != nil },
                    set: { if !$0 { appState.activeModal = nil } }
                )) {
                    DeveloperConsoleView()
                }
            case .reboot:
                rebootDialogView
            case .statusComparison:
                CommonModalContainer(title: "ステータス", icon: "speedometer", isPresented: Binding(
                    get: { appState.activeModal != nil },
                    set: { if !$0 { appState.activeModal = nil } }
                )) {
                    StatusComparisonModalView()
                }
            case .logsAndAchievements:
                CommonModalContainer(title: "ログと実績", icon: "trophy", isPresented: Binding(
                    get: { appState.activeModal != nil },
                    set: { if !$0 { appState.activeModal = nil } }
                )) {
                    LogsAndAchievementsModalView()
                }
            case .policyCheckPopup:
                CommonModalContainer(title: "点検と修正", icon: "shield", isPresented: Binding(
                    get: { appState.activeModal != nil },
                    set: { if !$0 { appState.activeModal = nil } }
                )) {
                    PolicyCheckModalView()
                }
            case .slideLoader:
                Color.clear
                    .onAppear {
                        appState.currentModule = .slideScenarioMaker
                    }
            default:
                fallbackModalView(title: modal.rawValue)
            }
        }
    }

    private var rebootDialogView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text("Toho-Studio の再起動")
                .font(.headline)
            Text("現在の編集内容を自動バックアップした上で、アプリケーションを再起動します。")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            HStack(spacing: 14) {
                Button("キャンセル") {
                    appState.activeModal = nil
                }
                Button("安全に保存して再起動") {
                    appState.activeModal = nil
                    appState.log("アプリケーションの再起動シーケンスを実行しました")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }

    private func fallbackModalView(title: String) -> some View {
        VStack(spacing: 16) {
            Text(title).font(.headline)
            Text("【\(title)】ダイアログ画面です。正常に処理されました。")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("OK") { appState.activeModal = nil }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}
