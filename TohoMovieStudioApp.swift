// TohoMovieStudioApp.swift
//
// このルートファイルは後方互換用です。実体は SPM ターゲット
// `Sources/TohoStudio/`（TohoStudioApp + SidebarView）に移しました。
//
// ビルド / 実行:
//   cd /Volumes/ZSSD/GitHub/repository/TohoStudio
//   swift run TohoStudio
//
// ムービーメーカー UI は Sources/TohoStudio/MovieStudio/MovieStudioCore.swift
// （StudioView / StudioModel）です。サイドバーの「ムービーメーカー」から開きます。

import SwiftUI

// 旧 Xcode スキームがこのファイルの @main を参照している場合に備え、
// パッケージとは別コンパイル単位向けのエントリを残します。
// `swift run TohoStudio` では Sources 側の TohoStudioApp が使われます。
#if TOHO_LEGACY_ROOT_ENTRY
@main
struct TohoMovieStudioApp: App {
    var body: some Scene {
        WindowGroup {
            SidebarView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}
#endif
