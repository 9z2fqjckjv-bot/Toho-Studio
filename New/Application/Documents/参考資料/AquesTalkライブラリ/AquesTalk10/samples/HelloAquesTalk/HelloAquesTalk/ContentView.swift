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
	@State private var sliderValSpd: Double = 100
	@State private var sliderValPit: Double = 100
	@State private var sliderValImd: Double = 100   

    var body: some View {
		VStack(spacing: 20) {
	        HStack(spacing: 20) {
	            TextField("音声記号列を入力", text: $inputText)
	                .textFieldStyle(RoundedBorderTextFieldStyle())
	                .padding()

	            Button("Say") {
	                synthAndPlay(text: inputText)
	            }
	        }
		    HStack(spacing: 40) {
		        VStack {
		            Text("spd")
		            Slider(value: $sliderValSpd, in: 50...300)
		                .frame(width: 120)
		        }
		        VStack {
		            Text("pit")
		            Slider(value: $sliderValPit, in: 20...200)
		                .frame(width: 120)
		        }
		        VStack {
		            Text("lmd")
		            Slider(value: $sliderValImd, in: 0...200)
		                .frame(width: 120)
		        }
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
	    // 声質設定
	    var voice: AQTK_VOICE = gVoice_F1 	//プリセット声種のF1をベースにする
	    voice.spd = Int32(sliderValSpd) 	// スライダーの値から話速をセット
	    voice.pit = Int32(sliderValPit)		// 高さ
	    voice.lmd = Int32(sliderValImd)		// 音程1

        guard let cString = text.cString(using: .utf8) else {
            print("文字列変換失敗")
            return
        }
        var dataSize: Int32 = 0
        if let resultPtr = AquesTalk_Synthe_Utf8(&voice, cString, &dataSize) {

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
