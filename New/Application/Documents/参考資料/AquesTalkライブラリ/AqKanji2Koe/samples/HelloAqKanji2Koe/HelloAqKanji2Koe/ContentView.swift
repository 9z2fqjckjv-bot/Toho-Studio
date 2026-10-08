//
//  ContentView.swift
//  HelloAqKanji2Koe
//
//  Created by AQUEST corp. on 2025/04/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var inputText = "ここに日本語のテキストを入れます。"
    @State private var resultText = "音声記号列に変換されます"
    @State private var handle: UnsafeMutableRawPointer? = nil

    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var exportTrigger = false
    @State private var importTrigger = false

    var pathUserDic: String? {
        Bundle.main.path(forResource: "aq_user", ofType: "dic", inDirectory: "aq_dic")
    }

    var pathDicCsvOnDesktop: String? {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        return desktopURL?.appendingPathComponent("user_dic.csv").path
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Enter text", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            HStack(spacing: 48) {
                Button("Convert Text") {
					convertText()
                }
                Button("Export User Dic.") {
	                exportUserDicToDesktop()
                }
                Button("Import User Dic.") {
	                importUserDicFromDesktop()
				//	debugCheckPaths()
                }
            }

            TextField("Enter text", text: $resultText)
                //.disabled(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
        }
        .onAppear {
            var err: Int32 = 0

			//開発ライセンスキーを指定
            AqKanji2Koe_SetDevKey("XXX-XXX-XXX")

			//辞書データのパスを取得
            guard let dicPath = Bundle.main.path(forResource: "aq_dic", ofType: nil) else {
                resultText = "辞書が見つかりません"
				return }

			// AqKanji2Koeの初期化(インスタンス生成)
            self.handle = AqKanji2Koe_Create(dicPath, &err)
            if self.handle == nil {
                resultText = "Create失敗: \(err)"
            }
        }
		.onDisappear {
			// AqKanji2Koeの終了
            if let handle = self.handle {
                AqKanji2Koe_Release(handle)
                self.handle = nil
            }
    	}
        .padding()
        .alert("通知", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    func convertText() {
        guard let handle = self.handle else {
            resultText = "handleが未初期化"
            return
        }

        // 入力をC文字列に変換
        let cKanji = inputText.cString(using: .utf8)

        // 出力音声記号列バッファ
        let nBufKoe = 1024
        let koeBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: nBufKoe)
        defer { koeBuffer.deallocate() }

        // 変換
	    let err = AqKanji2Koe_Convert(handle, cKanji, koeBuffer, Int32(nBufKoe))
	    if err == 0 {
	        self.resultText = String(cString: koeBuffer)
	    } else {
	        self.resultText = "変換エラー (\(err))"
	    }
    }


    private func exportUserDicToDesktop() {
        guard let pathUserDic, let pathCsv = pathDicCsvOnDesktop else {
            showMessage("パス取得失敗")
            return
        }
        let result = AqUsrDic_Export(pathUserDic, pathCsv)
        showMessage(result == 0 ? "Export成功: \(pathCsv)" : "Export失敗")
    }

    private func importUserDicFromDesktop() {
        guard let pathUserDic, let pathCsv = pathDicCsvOnDesktop else {
            showMessage("パス取得失敗")
            return
        }
        let result = AqUsrDic_Import(pathUserDic, pathCsv)
        showMessage(result == 0 ? "Import成功" : "Import失敗")
    }

    private func showMessage(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    ContentView()
}
