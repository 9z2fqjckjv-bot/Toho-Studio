import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class SoundEditorModel: ObservableObject {
    @Published var text: String = "こんにちは"
    @Published var status: String = "AquesTalk API（localhost:50021）の状態を確認してください。"
    @Published var lastError: String?
    @Published var isBusy = false
    @Published var apiReady = false
    @Published var lastWAVPath: String = ""

    private var player: AVAudioPlayer?

    func refreshAPIStatus() async {
        lastError = nil
        var request = URLRequest(url: URL(string: "http://127.0.0.1:50021/version")!)
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            apiReady = (200..<500).contains(code)
            status = apiReady ? "AquesTalk API: 接続中 (http://127.0.0.1:50021)" : "AquesTalk API: 応答異常"
        } catch {
            apiReady = false
            status = "AquesTalk API: 未接続 — ムービーメーカーで「AquesTalk API起動」を実行してください。"
        }
    }

    func preview() async {
        await synthesize(play: true, save: false)
    }

    func saveWAV() async {
        await synthesize(play: false, save: true)
    }

    private func synthesize(play: Bool, save: Bool) async {
        lastError = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "読み上げるテキストを入力してください。"
            return
        }

        await refreshAPIStatus()
        guard apiReady else {
            lastError = "AquesTalk APIに未接続のため、プレビュー/保存できません。"
            return
        }

        isBusy = true
        defer { isBusy = false }

        // Common local API shapes: /audio_query + /synthesis, or /tts, or /speak
        guard let wavData = await requestWAV(text: trimmed) else {
            if lastError == nil {
                lastError = "音声合成に失敗しました。APIのエンドポイント仕様を確認してください。"
            }
            return
        }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("toho_tts_preview.wav")
        do {
            try wavData.write(to: tmp, options: .atomic)
            lastWAVPath = tmp.path
            status = "合成成功: \(tmp.lastPathComponent) (\(wavData.count) bytes)"
        } catch {
            lastError = "WAV書き込み失敗: \(error.localizedDescription)"
            return
        }

        if save {
            let panel = NSSavePanel()
            panel.title = "WAVを保存"
            panel.nameFieldStringValue = "aquestalk_preview.wav"
            panel.allowedFileTypes = ["wav"]
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    try FileManager.default.copyItem(at: tmp, to: url)
                    lastWAVPath = url.path
                    status = "保存しました: \(url.path)"
                } catch {
                    lastError = "保存失敗: \(error.localizedDescription)"
                }
            }
        }

        if play {
            do {
                player = try AVAudioPlayer(contentsOf: tmp)
                player?.prepareToPlay()
                player?.play()
            } catch {
                lastError = "再生失敗: \(error.localizedDescription)"
            }
        }
    }

    private func requestWAV(text: String) async -> Data? {
        // Try several known local endpoints; first success wins.
        let attempts: [(URL, Data?, String)] = [
            (URL(string: "http://127.0.0.1:50021/tts")!, try? JSONSerialization.data(withJSONObject: ["text": text]), "application/json"),
            (URL(string: "http://127.0.0.1:50021/speak")!, try? JSONSerialization.data(withJSONObject: ["text": text]), "application/json"),
            (URL(string: "http://127.0.0.1:50021/?text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!, nil, "text/plain")
        ]

        for (url, body, contentType) in attempts {
            var request = URLRequest(url: url)
            request.httpMethod = body == nil ? "GET" : "POST"
            request.timeoutInterval = 20
            if let body {
                request.httpBody = body
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200..<300).contains(code), !data.isEmpty else { continue }
                // WAV typically starts with RIFF
                if data.count > 12, String(data: data.prefix(4), encoding: .ascii) == "RIFF" {
                    return data
                }
                // Some APIs return JSON with base64
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let b64 = obj["wav"] as? String ?? obj["audio"] as? String,
                       let decoded = Data(base64Encoded: b64) {
                        return decoded
                    }
                }
            } catch {
                continue
            }
        }

        // Last resort: audio_query + synthesis style (VOICEVOX-like used by some wrappers)
        if let queryURL = URL(string: "http://127.0.0.1:50021/audio_query?text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&speaker=0") {
            var qReq = URLRequest(url: queryURL)
            qReq.httpMethod = "POST"
            qReq.timeoutInterval = 20
            do {
                let (queryData, qRes) = try await URLSession.shared.data(for: qReq)
                guard ((qRes as? HTTPURLResponse)?.statusCode ?? 0) < 300 else { return nil }
                var sReq = URLRequest(url: URL(string: "http://127.0.0.1:50021/synthesis?speaker=0")!)
                sReq.httpMethod = "POST"
                sReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                sReq.httpBody = queryData
                sReq.timeoutInterval = 30
                let (wav, sRes) = try await URLSession.shared.data(for: sReq)
                if ((sRes as? HTTPURLResponse)?.statusCode ?? 0) < 300, !wav.isEmpty {
                    return wav
                }
            } catch {
                lastError = "API呼び出し失敗: \(error.localizedDescription)"
            }
        }
        return nil
    }
}

struct SoundEditorView: View {
    @StateObject private var model = SoundEditorModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("東方サウンドエディタ")
                        .font(.title.weight(.bold))
                    Text("波形編集UIは未実装。ローカル AquesTalk API 経由の読み上げプレビューのみ対応します。")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("読み上げテキスト") {
                TextEditor(text: $model.text)
                    .font(.body)
                    .frame(minHeight: 120)
                    .padding(4)
            }

            GroupBox("AquesTalk") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.status)
                    if let err = model.lastError {
                        Text(err).foregroundStyle(.red).font(.callout)
                    }
                    if !model.lastWAVPath.isEmpty {
                        Text("出力: \(model.lastWAVPath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    HStack {
                        Button("接続確認") { Task { await model.refreshAPIStatus() } }
                        Button("プレビュー再生") { Task { await model.preview() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isBusy || !model.apiReady)
                        Button("WAV保存…") { Task { await model.saveWAV() } }
                            .disabled(model.isBusy || !model.apiReady)
                        if !model.apiReady {
                            Text("状態: 未接続")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(6)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await model.refreshAPIStatus() }
    }
}
