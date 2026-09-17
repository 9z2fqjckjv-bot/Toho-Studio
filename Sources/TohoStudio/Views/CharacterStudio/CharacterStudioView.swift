import SwiftUI

struct CharacterStudioView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.artframe")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("東方キャラ立ち絵スタジオ")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("PSDファイルの読み込みや立ち絵の出力機能がここに実装されます。")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
