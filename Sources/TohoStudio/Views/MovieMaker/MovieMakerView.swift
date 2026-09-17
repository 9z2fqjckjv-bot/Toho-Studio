import SwiftUI

struct MovieMakerView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "film")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("東方ムービーメーカー")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("動画の合成やタイムライン編集を行うネイティブ機能がここに実装されます。")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
