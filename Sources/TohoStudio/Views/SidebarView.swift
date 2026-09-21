import SwiftUI

struct SidebarView: View {
    enum Tool: String, CaseIterable, Identifiable {
        case movieMaker = "ムービーメーカー"
        case characterStudio = "キャラ立ち絵スタジオ"
        case soundEditor = "サウンドエディタ"

        var id: String { self.rawValue }

        var icon: String {
            switch self {
            case .movieMaker: return "film"
            case .characterStudio: return "person.crop.artframe"
            case .soundEditor: return "waveform"
            }
        }
    }

    @State private var selectedTool: Tool? = .movieMaker

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTool) {
                ForEach(Tool.allCases) { tool in
                    Label(tool.rawValue, systemImage: tool.icon)
                        .tag(tool)
                }
            }
            .navigationTitle("TohoStudio")
            .listStyle(.sidebar)
        } detail: {
            if let selectedTool {
                switch selectedTool {
                case .movieMaker:
                    MovieMakerView()
                case .characterStudio:
                    CharacterStudioView()
                case .soundEditor:
                    SoundEditorView()
                }
            } else {
                Text("ツールを選択してください")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 1100, minHeight: 760)
    }
}
