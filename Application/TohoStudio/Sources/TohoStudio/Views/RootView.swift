import SwiftUI

public struct RootView: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        ZStack {
            if appState.isShowingAppTop {
                // 仕様書スライド 26: アプリトップ画面
                AppTopScreenView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    // コントロールバーの表示を消して、必要時のみトグル表示可能にする
                    if appState.isControlBarVisible {
                        customControlBarView
                        Divider()
                    }

                    // Active Module Workspace
                    activeModuleView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    // Bottom Status Bar
                    bottomStatusBarView
                }
                .transition(.opacity)
            }

            // Modal Sheets & Overlays
            if let modal = appState.activeModal {
                modalOverlay(for: modal)
            }

            // In-App Browser Overlay
            if let browserURL = appState.activeInAppBrowserURL {
                ZStack {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            appState.closeInAppBrowser()
                        }

                    InAppBrowserView(
                        url: browserURL,
                        title: appState.inAppBrowserTitle,
                        isPresented: Binding(
                            get: { appState.activeInAppBrowserURL != nil },
                            set: { if !$0 { appState.closeInAppBrowser() } }
                        )
                    )
                    .frame(maxWidth: 1100, maxHeight: 720)
                    .padding(24)
                }
                .zIndex(100)
            }

            // Import Feedback Toast
            if let feedback = appState.importFeedbackMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                        Text(feedback)
                            .font(.callout)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            withAnimation { appState.importFeedbackMessage = nil }
                        }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.88))
                    .cornerRadius(10)
                    .shadow(radius: 8)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 36)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(90)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation {
                            if appState.importFeedbackMessage == feedback {
                                appState.importFeedbackMessage = nil
                            }
                        }
                    }
                }
            }

            // Ad Overlay (File processing, Long processing, Trial Video)
            if AdManager.shared.hasActiveAd {
                AdOverlayView()
            }

            // Application Tamper Security Block (Restricted: Unlocked ONLY from Developer Mac)
            if ResourceIntegrityProtectionService.shared.isBlocked {
                ApplicationBlockedView()
            }
        }
        .frame(minWidth: 1024, minHeight: 680)
        .onAppear {
            _ = ResourceIntegrityProtectionService.shared.verifyIntegrity()
        }
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
            // App Official Logo (image11.png) & Dropdown
            HStack(spacing: 8) {
                AppLogoView(size: 24, cornerRadius: 5)

                Menu {
                    Button("アプリ情報 (cmd+t+i)") { appState.activeModal = .appInfo }
                    Button("設定画面 (cmd+t+s)") { appState.activeModal = .settings }
                    Button("ストア (cmd+t+shift+s)") { appState.activeModal = .store }
                    Button("再起動 (cmd+t+r)") { appState.activeModal = .reboot }
                    Divider()
                    Button("開発者コンソール (cmd+t+e)") { appState.activeModal = .developer }
                } label: {
                    Text("Toho-Studio")
                        .font(.headline)
                        .bold()
                }
                .menuStyle(.borderlessButton)
            }

            Divider().frame(height: 20)

            // アプリトップに戻るボタン (ソフトナビゲーター廃止に伴う統合)
            Button(action: {
                withAnimation { appState.isShowingAppTop = true }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("アプリトップ")
                        .font(.subheadline)
                        .bold()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("仕様書スライド26のアプリトップ画面に戻ります (cmd+0)")

            // 現在開いているソフトの表示バッジ
            HStack(spacing: 6) {
                Image(systemName: appState.currentModule.iconName)
                    .foregroundColor(.accentColor)
                Text(appState.currentModule.rawValue)
                    .font(.subheadline)
                    .bold()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(5)

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

                // AquesTalk Voice Generator Button
                Button(action: { appState.activeModal = .aquesTalkGenerator }) {
                    Image(systemName: "waveform.badge.plus")
                        .foregroundColor(.cyan)
                }
                .help("AquesTalkで音声を生成 (cmd+shift+a)")

                // Layout Presets (仕様書準拠)
                Menu {
                    ForEach(AppState.LayoutPresets, id: \.self) { preset in
                        Button(action: { appState.setLayout(preset) }) {
                            HStack {
                                Text(preset)
                                if appState.layoutMode == preset {
                                    Text("✓")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.3.group")
                        Text(appState.layoutMode)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
                // Google Ads Status Indicator
                Button(action: { appState.activeModal = .settings }) {
                    HStack(spacing: 3) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AdManager.shared.shouldShowAds() ? .blue : .green)
                        Text(AdManager.shared.shouldShowAds() ? "Google広告ON" : "広告フリー")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Google 広告配信ステータス (仕様書指定枠・広告フリー設定)")

                // Settings
                Button(action: { appState.activeModal = .settings }) {
                    Image(systemName: "gearshape")
                }
                .help("設定 (cmd+t+s)")

                Divider().frame(height: 18)

                // コントロールバーを消すボタン (仕様書準拠: コントロールバーを非表示にしてメニューバーを有効化)
                Button(action: {
                    withAnimation { appState.isControlBarVisible = false }
                }) {
                    Image(systemName: "chevron.up.circle")
                        .foregroundColor(.secondary)
                }
                .help("コントロールバーを消す (cmd+shift+c / メニューバーで再表示可能)")

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
        case .tohoAIStudio:
            TohoAIStudioView()
        }
    }

    // MARK: - Bottom Status Bar
    private var bottomStatusBarView: some View {
        HStack(spacing: 16) {
            // アプリトップに戻るクイックボタン
            Button(action: {
                withAnimation { appState.isShowingAppTop = true }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.caption2)
                    Text("アプリトップ")
                        .font(.caption2)
                        .bold()
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("仕様書スライド26のアプリトップ画面に戻ります (cmd+0)")

            // コントロールバーのトグルボタン
            Button(action: {
                withAnimation { appState.isControlBarVisible.toggle() }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: appState.isControlBarVisible ? "eye.slash" : "eye")
                        .font(.caption2)
                    Text(appState.isControlBarVisible ? "バーを隠す" : "コントロールバー")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("コントロールバーの表示/非表示を切り替えます (cmd+shift+c)")

            Divider().frame(height: 12)

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

            Text("バージョン: v2.0.0")
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
                CommonModalContainer(title: "アプリ情報", icon: "info.circle", isPresented: modalBinding) {
                    AppInfoView(initialTab: appState.appInfoInitialTab)
                }

            case .settings:
                SettingsView()

            case .store:
                CommonModalContainer(title: "ストア", icon: "bag", isPresented: modalBinding) {
                    StoreView()
                }

            case .developer:
                CommonModalContainer(title: "開発者コンソール", icon: "chevron.left.forwardslash.chevron.right", isPresented: modalBinding) {
                    DeveloperConsoleView()
                }

            case .reboot:
                rebootDialogView

            case .statusComparison:
                CommonModalContainer(title: "ステータス", icon: "speedometer", isPresented: modalBinding) {
                    StatusComparisonModalView()
                }

            case .logsAndAchievements:
                CommonModalContainer(title: "ログと実績", icon: "trophy", isPresented: modalBinding) {
                    LogsAndAchievementsModalView()
                }

            case .policyCheckPopup:
                CommonModalContainer(title: "点検と修正", icon: "shield", isPresented: modalBinding) {
                    PolicyCheckModalView()
                }

            case .newProject:
                CommonModalContainer(title: "新規作成", icon: "doc.badge.plus", isPresented: modalBinding) {
                    NewProjectModalView()
                }

            case .fileExport:
                CommonModalContainer(title: "書き出し", icon: "square.and.arrow.up", isPresented: modalBinding) {
                    FileExportModalView()
                }

            case .backupManager:
                CommonModalContainer(title: "バックアップ", icon: "archivebox", isPresented: modalBinding) {
                    BackupManagerModalView()
                }

            case .integrityAlert:
                CommonModalContainer(title: "整合性確認", icon: "checkmark.shield", isPresented: modalBinding) {
                    IntegrityCheckModalView()
                }

            case .fileInfo:
                CommonModalContainer(title: "ファイル情報", icon: "doc.text.magnifyingglass", isPresented: modalBinding) {
                    FileInfoModalView()
                }

            case .sceneInfo:
                CommonModalContainer(title: "シーン情報", icon: "film", isPresented: modalBinding) {
                    SceneInfoModalView()
                }

            case .trimmingPopup:
                CommonModalContainer(title: "トリミング", icon: "crop", isPresented: modalBinding) {
                    TrimmingModalView()
                }

            case .splitPopup:
                CommonModalContainer(title: "分割", icon: "scissors", isPresented: modalBinding) {
                    SplitModalView()
                }

            case .historyList:
                CommonModalContainer(title: "履歴一覧", icon: "clock.arrow.circlepath", isPresented: modalBinding) {
                    HistoryModalView()
                }

            case .memoPad:
                CommonModalContainer(title: "備考録・メモ", icon: "note.text", isPresented: modalBinding) {
                    MemoPadModalView()
                }

            case .backgroundProcess:
                CommonModalContainer(title: "進捗状況確認", icon: "chart.line.uptrend.xyaxis", isPresented: modalBinding) {
                    BackgroundProcessModalView()
                }

            case .bugReport:
                CommonModalContainer(title: "バグレポート", icon: "ladybug", isPresented: modalBinding) {
                    BugReportModalView()
                }

            case .debugScreen:
                CommonModalContainer(title: "デバック画面", icon: "terminal", isPresented: modalBinding) {
                    DebugScreenModalView()
                }

            case .softwareList:
                CommonModalContainer(title: "ソフト一覧", icon: "square.grid.2x2", isPresented: modalBinding) {
                    SoftwareListModalView()
                }

            case .featureList:
                CommonModalContainer(title: "機能リスト", icon: "list.bullet.rectangle", isPresented: modalBinding) {
                    FeatureListModalView()
                }

            case .contextOptions:
                CommonModalContainer(title: "オプション設定", icon: "slider.horizontal.3", isPresented: modalBinding) {
                    ContextOptionsModalView()
                }

            case .windowOptions:
                CommonModalContainer(title: "ウィンドウ設定", icon: "macwindow", isPresented: modalBinding) {
                    WindowOptionsModalView()
                }

            case .manual:
                CommonModalContainer(title: "取扱説明書", icon: "book", isPresented: modalBinding) {
                    HelpCenterModalView(initialTab: 0)
                }

            case .helpGuide:
                CommonModalContainer(title: "ヘルプガイド", icon: "questionmark.circle", isPresented: modalBinding) {
                    HelpCenterModalView(initialTab: 1)
                }

            case .qa:
                CommonModalContainer(title: "よくある質問 (Q&A)", icon: "bubble.left.and.bubble.right", isPresented: modalBinding) {
                    HelpCenterModalView(initialTab: 2)
                }

            case .troubleshoot:
                CommonModalContainer(title: "困ったときは", icon: "exclamationmark.bubble", isPresented: modalBinding) {
                    HelpCenterModalView(initialTab: 3)
                }

            case .supportRequest:
                CommonModalContainer(title: "サポート依頼", icon: "person.crop.circle.badge.questionmark", isPresented: modalBinding) {
                    HelpCenterModalView(initialTab: 4)
                }

            case .credits:
                CommonModalContainer(title: "クレジット", icon: "star.circle", isPresented: modalBinding) {
                    AppInfoView(initialTab: 3)
                }

            case .license:
                CommonModalContainer(title: "ライセンス", icon: "doc.plaintext", isPresented: modalBinding) {
                    AppInfoView(initialTab: 2)
                }

            case .aquesTalkGenerator:
                CommonModalContainer(title: "AquesTalkで音声を生成", icon: "waveform.badge.plus", isPresented: modalBinding) {
                    AquesTalkGeneratorModalView()
                }

            case .batchVoiceGenerator:
                BatchVoiceGenerationSheet()

            case .spanAudioInsert:
                SpanAudioInsertSheet(initialStartScene: max(1, appState.selectedSceneIndex + 1))

            case .slideExtractor:
                CommonModalContainer(title: "スライド抽出プログラム (有料機能)", icon: "line.3.horizontal.decrease.circle", isPresented: modalBinding) {
                    SlideExtractorModalView()
                }

            case .aiSearch:
                CommonModalContainer(title: "AI高度検索・生成・置換 (有料機能連携)", icon: "sparkles", isPresented: modalBinding) {
                    AISearchModalView()
                }

            case .slideRecognitionPopup, .slideLoader:
                Color.clear
                    .onAppear {
                        appState.currentModule = .slideScenarioMaker
                    }
            }
        }
    }

    private var modalBinding: Binding<Bool> {
        Binding(
            get: { appState.activeModal != nil },
            set: { if !$0 { appState.activeModal = nil } }
        )
    }

    private var rebootDialogView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text("Toho-Studio の再起動")
                .font(.headline)
            Text("現在の編集内容を安全に自動保存・バックアップした上で、アプリケーションを再起動します。")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            HStack(spacing: 14) {
                Button("キャンセル") {
                    appState.activeModal = nil
                }
                Button("安全に保存して再起動") {
                    appState.activeModal = nil
                    appState.performReboot()
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
}
