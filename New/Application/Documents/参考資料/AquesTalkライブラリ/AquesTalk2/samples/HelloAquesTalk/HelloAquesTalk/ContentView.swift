//
//  ContentView.swift
//  HelloAquesTalk for AquesTalk2 Mac
//
//  Created by AQUEST on 2025/04/27.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var audioPlayer: AVAudioPlayer?
	@State private var phontData: Data?
	@State private var phontPointer: UnsafeRawPointer?
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("音声記号列を入力", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("音声を再生") {
                synthAndPlay(text: inputText)
            }
        }
        .onAppear {
			loadPhontFromResource()
		}
        .padding()
    }

	// Phontの読み込み
	func loadPhontFromResource() {
	    if let url = Bundle.main.url(forResource: "aq_robo", withExtension: "phont") {
	        do {
	            let data = try Data(contentsOf: url)
	            phontData = data
	            phontData?.withUnsafeBytes { rawBufferPointer in
	                phontPointer = rawBufferPointer.baseAddress
	            }
	        } catch {
	            print("Phontの読み込みに失敗しました: \(error)")
	        }
	    } else {
	        print("指定のPhontが見つからない")
	    }
	}

    func synthAndPlay(text: String) {
        guard let cString = text.cString(using: .utf8) else {
            print("文字列変換失敗")
            return
        }
        var dataSize: Int32 = 0
        if let resultPtr = AquesTalk2_Synthe_Utf8(cString, 100, &dataSize, phontPointer) {

            // Cポインタ → SwiftのDataに変換
            let soundData = Data(bytes: resultPtr, count: Int(dataSize))

            do {
                // AVAudioPlayerでメモリ上の音声データを再生
                self.audioPlayer = try AVAudioPlayer(data: soundData)
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
                print("再生開始！")
            } catch {
                print("音声再生エラー: \(error)")
            }

            // メモリ解放（AquesTalkの仕様）
            AquesTalk2_FreeWave(resultPtr)

        } else {
            // エラー時はdataSizeにエラーコードが返されている
            print("音声データ生成失敗(\(dataSize))")
        }
    }
}


#Preview {
    ContentView()
}
