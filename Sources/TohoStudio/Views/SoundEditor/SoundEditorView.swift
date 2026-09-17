import SwiftUI

struct SoundEditorView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("東方サウンドエディタ")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("AquesTalk音声の生成やオーディオ波形の編集機能がここに実装されます。")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
