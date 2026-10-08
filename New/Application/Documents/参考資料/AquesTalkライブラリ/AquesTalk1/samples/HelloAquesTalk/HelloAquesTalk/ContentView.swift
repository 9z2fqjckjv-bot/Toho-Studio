//
//  ContentView.swift
//  HelloAquesTalk
//
//  Created by AQUEST on 2025/04/14.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isFirstAppear = true;
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("読み仮名を入力", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("音声を再生") {
                synthAndPlay(text: inputText)
            }
        }
        .onAppear {
            if isFirstAppear {
                isFirstAppear = false
                AquesTalk_SetDevKey("XXXXXXXX") //開発ライセンスキーを指定
                AquesTalk_SetUsrKey("YYYYYYYY") // 使用ライセンスキーを指定
            }
        }
        .padding()
    }

    func synthAndPlay(text: String) {
        guard let cString = text.cString(using: .utf8) else {
            print("文字列変換失敗")
            return
        }
        var dataSize: Int32 = 0
        if let resultPtr = AquesTalk_Synthe_Utf8(cString, 100, &dataSize) {

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
            AquesTalk_FreeWave(resultPtr)

        } else {
            // エラー時はdataSizeにエラーコードが返されている
            print("音声データ生成失敗(\(dataSize))")
        }
    }
}


#Preview {
    ContentView()
}
