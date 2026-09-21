import AppKit
import SwiftUI

@MainActor
final class CharacterStudioModel: ObservableObject {
    @Published var psdPath: String = ""
    @Published var status: String = "PSDを選択するか、外部スタジオを起動してください。"
    @Published var lastError: String?
    @Published var isLaunching = false

    private let candidateRoots = [
        "/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story",
        "/Volumes/ZSSD/GitHub/repository/TohoStudio",
        NSHomeDirectory() + "/GitHub/repository/Toho-Project-Second-Story"
    ]

    var psdURL: URL? {
        guard !psdPath.isEmpty else { return nil }
        return URL(fileURLWithPath: psdPath)
    }

    var psdInfo: String {
        guard let url = psdURL else { return "未選択" }
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return "ファイルが見つかりません" }
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? NSNumber
        let date = attrs?[.modificationDate] as? Date
        let sizeText = size.map { ByteCountFormatter.string(fromByteCount: $0.int64Value, countStyle: .file) } ?? "?"
        let dateText = date.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) } ?? "?"
        return "\(url.lastPathComponent)  /  \(sizeText)  /  更新: \(dateText)"
    }

    func choosePSD() {
        let panel = NSOpenPanel()
        panel.title = "PSDファイルを選択"
        panel.allowedFileTypes = ["psd", "PSD"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            psdPath = url.path
            lastError = nil
            status = "PSDを読み込みました（プレビューは外部スタジオで開きます）。"
        }
    }

    func revealInFinder() {
        guard let url = psdURL, FileManager.default.fileExists(atPath: url.path) else {
            lastError = "先に存在するPSDを選択してください。"
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func resolveStudioApp() -> URL? {
        let names = ["psd_studio_app.py", "東方キャラ立ち絵スタジオ/program/psd_studio_app.py", "東方キャラ立ち絵スタジオ/psd_studio_app.py"]
        for root in candidateRoots {
            for name in names {
                let url = URL(fileURLWithPath: root).appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
        }
        return nil
    }

    func launchExternalStudio() {
        lastError = nil
        guard let script = resolveStudioApp() else {
            lastError = "東方キャラ立ち絵スタジオ（psd_studio_app.py）が見つかりません。Toho-Project-Second-Story を配置してください。"
            status = "外部スタジオ: 未接続"
            return
        }
        isLaunching = true
        defer { isLaunching = false }

        let python: String = {
            let venv = script.deletingLastPathComponent().appendingPathComponent(".venv/bin/python").path
            let rootVenv = script.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".venv/bin/python").path
            if FileManager.default.fileExists(atPath: venv) { return venv }
            if FileManager.default.fileExists(atPath: rootVenv) { return rootVenv }
            return "/usr/bin/python3"
        }()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.currentDirectoryURL = script.deletingLastPathComponent()
        var args = [script.path]
        if let psd = psdURL, FileManager.default.fileExists(atPath: psd.path) {
            args.append(contentsOf: ["--psd", psd.path])
        }
        process.arguments = args
        do {
            try process.run()
            status = "外部スタジオを起動しました: \(script.path)"
        } catch {
            lastError = "起動に失敗しました: \(error.localizedDescription)"
            status = "外部スタジオ: 起動失敗"
        }
    }
}

struct CharacterStudioView: View {
    @StateObject private var model = CharacterStudioModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.artframe")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("東方キャラ立ち絵スタジオ")
                        .font(.title.weight(.bold))
                    Text("ネイティブ埋め込み編集は未実装です。PSDの選択と外部スタジオ起動のみ行えます。")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("PSD") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("PSDパス", text: $model.psdPath)
                            .textFieldStyle(.roundedBorder)
                        Button("選択…") { model.choosePSD() }
                        Button("Finderで表示") { model.revealInFinder() }
                            .disabled(model.psdPath.isEmpty)
                    }
                    Text(model.psdInfo)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(6)
            }

            GroupBox("外部スタジオ") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.status)
                    if let err = model.lastError {
                        Text(err).foregroundStyle(.red).font(.callout)
                    }
                    HStack {
                        Button("外部スタジオを起動") { model.launchExternalStudio() }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isLaunching)
                        if model.resolveStudioApp() == nil {
                            Text("状態: 未接続（psd_studio_app.py なし）")
                                .foregroundStyle(.orange)
                        } else {
                            Text("状態: 起動可能")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(6)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
