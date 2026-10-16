import Foundation
import Combine

/// 辞書単語の分類カテゴリ
public enum DictionaryCategory: String, Codable, CaseIterable, Identifiable {
    case tohoCharacter = "東方キャラクター"
    case tohoTerm = "東方用語・地名"
    case general = "一般・ネットスラング"
    case userCustom = "ユーザー登録"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .tohoCharacter: return "person.crop.circle.badge.checkmark"
        case .tohoTerm: return "sparkles"
        case .general: return "text.bubble"
        case .userCustom: return "person.badge.plus"
        }
    }

    public var badgeColorHex: String {
        switch self {
        case .tohoCharacter: return "#E74C3C"
        case .tohoTerm: return "#9B59B6"
        case .general: return "#3498DB"
        case .userCustom: return "#2ECC71"
        }
    }
}

/// 辞書単語エントリ
public struct DictionaryWord: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var surface: String          // 表記 (例: "博麗霊夢", "十六夜咲夜", "うｐ")
    public var reading: String          // 読み (例: "はくれいれいむ", "いざよいさくや", "アップ")
    public var phonetic: String?        // 音声記号直接指定 (省略時は読みをそのまま使用)
    public var category: DictionaryCategory
    public var isEnabled: Bool = true
    public var priority: Int = 0        // 優先度 (同一文字数時の優先順位)

    public init(
        id: UUID = UUID(),
        surface: String,
        reading: String,
        phonetic: String? = nil,
        category: DictionaryCategory = .userCustom,
        isEnabled: Bool = true,
        priority: Int = 0
    ) {
        self.id = id
        self.surface = surface
        self.reading = reading
        self.phonetic = phonetic
        self.category = category
        self.isEnabled = isEnabled
        self.priority = priority
    }
}

/// サウンドメーカー専用の読み仮名・発音辞書マネージャー
/// 東方Projectキャラクター名・用語の初期プリセットを網羅し、
/// ユーザー追加辞書の永続化と、音声合成前のテキスト自動置換を実行
public final class SoundMakerDictionaryManager: ObservableObject {
    public static let shared = SoundMakerDictionaryManager()

    @Published public var words: [DictionaryWord] = []

    private let userDefaultsKey = "TohoStudio_SoundMaker_DictionaryWords_v1"

    private init() {
        loadDictionary()
    }

    // MARK: - 辞書の読み込みと保存
    public func loadDictionary() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedWords = try? JSONDecoder().decode([DictionaryWord].self, from: data),
           !savedWords.isEmpty {
            self.words = savedWords
        } else {
            self.words = Self.defaultPresetWords()
            saveDictionary()
        }
    }

    public func saveDictionary() {
        if let data = try? JSONEncoder().encode(words) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    public func resetToDefaults() {
        self.words = Self.defaultPresetWords()
        saveDictionary()
    }

    // MARK: - 単語の操作
    public func addWord(surface: String, reading: String, phonetic: String? = nil, category: DictionaryCategory = .userCustom) {
        let trimmedSurface = surface.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReading = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSurface.isEmpty, !trimmedReading.isEmpty else { return }

        // 既存の同表記があれば更新、なければ追加
        if let index = words.firstIndex(where: { $0.surface == trimmedSurface }) {
            words[index].reading = trimmedReading
            words[index].phonetic = phonetic?.trimmingCharacters(in: .whitespacesAndNewlines)
            words[index].category = category
            words[index].isEnabled = true
        } else {
            let newWord = DictionaryWord(
                surface: trimmedSurface,
                reading: trimmedReading,
                phonetic: phonetic?.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                isEnabled: true,
                priority: 10
            )
            words.insert(newWord, at: 0)
        }
        saveDictionary()
    }

    public func removeWord(id: UUID) {
        words.removeAll(where: { $0.id == id })
        saveDictionary()
    }

    public func toggleWordEnabled(id: UUID) {
        if let index = words.firstIndex(where: { $0.id == id }) {
            words[index].isEnabled.toggle()
            saveDictionary()
        }
    }

    public func updateWord(_ word: DictionaryWord) {
        if let index = words.firstIndex(where: { $0.id == word.id }) {
            words[index] = word
            saveDictionary()
        }
    }

    // MARK: - テキストへの辞書適用 (長一致優先)
    /// 文章中のキャラクター名や登録単語を、辞書に基づき正しい読みに置換する
    public func applyDictionary(to text: String) -> String {
        guard !text.isEmpty else { return text }

        // 有効な単語を最長一致 (文字数降順 -> 優先度降順) でソート
        let activeWords = words
            .filter { $0.isEnabled && !$0.surface.isEmpty && !$0.reading.isEmpty }
            .sorted { (w1, w2) -> Bool in
                if w1.surface.count != w2.surface.count {
                    return w1.surface.count > w2.surface.count
                }
                return w1.priority > w2.priority
            }

        var result = text
        for word in activeWords {
            let target = word.surface
            // 置換後の読み（かな、または直接指定の音声記号）
            let replacement = word.phonetic?.isEmpty == false ? word.phonetic! : word.reading
            if result.contains(target) {
                result = result.replacingOccurrences(of: target, with: replacement)
            }
        }
        return result
    }

    // MARK: - CSV インポート / エクスポート
    public func exportCSV() -> String {
        var lines = ["表記,読み,音声記号,カテゴリ,有効"]
        for w in words {
            let p = w.phonetic ?? ""
            let cat = w.category.rawValue
            let en = w.isEnabled ? "1" : "0"
            lines.append("\"\(w.surface)\",\"\(w.reading)\",\"\(p)\",\"\(cat)\",\(en)")
        }
        return lines.joined(separator: "\n")
    }

    public func importCSV(_ csvText: String) {
        let lines = csvText.components(separatedBy: .newlines)
        var importedCount = 0
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = parseCSVLine(trimmed)
            guard parts.count >= 2 else { continue }
            let surface = parts[0]
            let reading = parts[1]
            let phonetic = parts.count > 2 ? parts[2] : nil
            let categoryStr = parts.count > 3 ? parts[3] : ""
            let category = DictionaryCategory.allCases.first(where: { $0.rawValue == categoryStr }) ?? .userCustom
            let isEnabled = parts.count > 4 ? (parts[4] != "0" && parts[4].lowercased() != "false") : true

            addWord(surface: surface, reading: reading, phonetic: phonetic, category: category)
            if let idx = words.firstIndex(where: { $0.surface == surface }) {
                words[idx].isEnabled = isEnabled
            }
            importedCount += 1
        }
        saveDictionary()
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    // MARK: - 東方Project キャラクター・用語デフォルトプリセット
    public static func defaultPresetWords() -> [DictionaryWord] {
        var presets: [DictionaryWord] = []

        func add(_ surface: String, _ reading: String, _ phonetic: String? = nil, _ category: DictionaryCategory = .tohoCharacter) {
            presets.append(DictionaryWord(
                surface: surface,
                reading: reading,
                phonetic: phonetic,
                category: category,
                isEnabled: true,
                priority: category == .tohoCharacter ? 20 : 10
            ))
        }

        // --- 主人公・霊夢・魔理沙 ---
        add("博麗霊夢", "はくれいれいむ", "ハクレイレイ'ム")
        add("博麗 霊夢", "はくれいれいむ", "ハクレイレイ'ム")
        add("博麗", "はくれい", "ハク'レイ")
        add("霊夢", "れいむ", "レ'イム")
        add("霧雨魔理沙", "きりさめまりさ", "キリサメマ'リサ")
        add("霧雨 魔理沙", "きりさめまりさ", "キリサメマ'リサ")
        add("霧雨", "きりさめ", "キリ'サメ")
        add("魔理沙", "まりさ", "マ'リサ")

        // --- 紅魔郷 ---
        add("ルーミア", "るーみあ", "ルー'ミア")
        add("大妖精", "だいようせい", "ダイヨー'セイ")
        add("チルノ", "ちるの", "チ'ルノ")
        add("紅美鈴", "ほんめいりん", "ホンメ'イリン")
        add("美鈴", "めいりん", "メ'イリン")
        add("小悪魔", "こあくま", "コア'クマ")
        add("パチュリー・ノーレッジ", "ぱちゅりーのーれっじ", "パチュリーノ'ーレッジ")
        add("パチュリー", "ぱちゅりー", "パチュ'リー")
        add("十六夜咲夜", "いざよいさくや", "イザヨイサ'クヤ")
        add("十六夜 咲夜", "いざよいさくや", "イザヨイサ'クヤ")
        add("十六夜", "いざよい", "イザ'ヨイ")
        add("咲夜", "さくや", "サ'クヤ")
        add("レミリア・スカーレット", "れみりあすかーれっと", "レミリアスカー'レット")
        add("レミリア", "れみりあ", "レミ'リア")
        add("スカーレット", "すかーれっと", "スカー'レット")
        add("フランドール・スカーレット", "ふらんどーるすかーれっと", "フランドールスカー'レット")
        add("フランドール", "ふらんどーる", "フランド'ール")
        add("フラン", "ふらん", "フ'ラン")

        // --- 妖々夢 ---
        add("レティ・ホワイトロック", "れてぃほわいとろっく", "レティホワイト'ロック")
        add("レティ", "れてぃ", "レ'ティ")
        add("橙", "ちぇん", "チェ'ン")
        add("アリス・マーガトロイド", "ありすまーがとろいど", "アリスマ'ーガトロイド")
        add("アリス", "ありす", "ア'リス")
        add("リリーホワイト", "りりーほわいと", "リリーホワ'イト")
        add("ルナサ・プリズムリバー", "るなさぷりずむりばー", "ルナサプリズム'リバー")
        add("ルナサ", "るなさ", "ル'ナサ")
        add("メルラン・プリズムリバー", "めるらんぷりずむりばー", "メルランプリズム'リバー")
        add("メルラン", "めるらん", "メ'ルラン")
        add("リリカ・プリズムリバー", "りりかぷりずむりばー", "リリカプリズム'リバー")
        add("リリカ", "りりか", "リ'リカ")
        add("魂魄妖夢", "こんぱくようむ", "コンパクヨ'ーム")
        add("魂魄 妖夢", "こんぱくようむ", "コンパクヨ'ーム")
        add("魂魄", "こんぱく", "コ'ンパク")
        add("妖夢", "ようむ", "ヨ'ーム")
        add("西行寺幽々子", "さいぎょうじゆゆこ", "サイギョージユ'ユコ")
        add("西行寺 幽々子", "さいぎょうじゆゆこ", "サイギョージユ'ユコ")
        add("西行寺", "さいぎょうじ", "サイギョ'ージ")
        add("幽々子", "ゆゆこ", "ユ'ユコ")
        add("八雲藍", "やくもらん", "ヤクモラ'ン")
        add("八雲 藍", "やくもらん", "ヤクモラ'ン")
        add("藍", "らん", "ラ'ン")
        add("八雲紫", "やくもゆかり", "ヤクモユ'カリ")
        add("八雲 紫", "やくもゆかり", "ヤクモユ'カリ")
        add("八雲", "やくも", "ヤ'クモ")
        add("紫", "ゆかり", "ユ'カリ")

        // --- 萃夢想 / 緋想天 / 非想天則 / 心綺楼 / 深秘録 / 憑依華 ---
        add("伊吹萃香", "いぶきすいか", "イブキス'イカ")
        add("伊吹 萃香", "いぶきすいか", "イブキス'イカ")
        add("萃香", "すいか", "ス'イカ")
        add("永江衣玖", "ながえいく", "ナガエイ'ク")
        add("衣玖", "いく", "イ'ク")
        add("比那名居天子", "ひなないてんし", "ヒナナ'イテンシ")
        add("天子", "てんし", "テ'ンシ")
        add("秦こころ", "はたのこころ", "ハタノコ'コロ")
        add("こころ", "こころ", "コ'コロ")
        add("茨木華扇", "いばらきかせん", "イバラキカ'セン")
        add("華扇", "かせん", "カ'セン")
        add("依神紫苑", "よりがみしおん", "ヨリガミシ'オン")
        add("紫苑", "しおん", "シ'オン")
        add("依神女苑", "よりがみじょおん", "ヨリガミジョ'オン")
        add("女苑", "じょおん", "ジョ'オン")

        // --- 永夜抄 ---
        add("リグル・ナイトバグ", "りぐるないとばぐ", "リグルナイト'バグ")
        add("リグル", "りぐる", "リ'グル")
        add("ミスティア・ローレライ", "みすてぃあろーれらい", "ミスティアロー'レライ")
        add("ミスティア", "みすてぃあ", "ミス'ティア")
        add("みすちー", "みすちー", "ミス'チー")
        add("上白沢慧音", "かみしらさわけいね", "カミシラサワケ'イネ")
        add("上白沢 慧音", "かみしらさわけいね", "カミシラサワケ'イネ")
        add("慧音", "けいね", "ケ'イネ")
        add("因幡てゐ", "いなばてゐ", "イナバテ'イ")
        add("てゐ", "てゐ", "テ'イ")
        add("鈴仙・優曇華院・イナバ", "れいせんうどんげいんいなば", "レイセンウドンゲ'インイナバ")
        add("鈴仙", "れいせん", "レイ'セン")
        add("優曇華", "うどんげ", "ウド'ンゲ")
        add("うどんげ", "うどんげ", "ウド'ンゲ")
        add("八意永琳", "やごころえいりん", "ヤゴコロエ'イリン")
        add("八意 永琳", "やごころえいりん", "ヤゴコロエ'イリン")
        add("永琳", "えいりん", "エ'イリン")
        add("蓬莱山輝夜", "ほうらいさんかぐや", "ホーライサンカ'グヤ")
        add("蓬莱山 輝夜", "ほうらいさんかぐや", "ホーライサンカ'グヤ")
        add("輝夜", "かぐや", "カ'グヤ")
        add("藤原妹紅", "ふじわらのもこう", "フジワラノモ'コー")
        add("藤原 妹紅", "ふじわらのもこう", "フジワラノモ'コー")
        add("妹紅", "もこう", "モ'コー")

        // --- 花映塚 ---
        add("射命丸文", "しゃめいまるあや", "シャメイマルア'ヤ")
        add("射命丸 文", "しゃめいまるあや", "シャメイマルア'ヤ")
        add("射命丸", "しゃめいまる", "シャメ'イマル")
        add("文", "あや", "ア'ヤ")
        add("メディスン・メランコリー", "めでぃすんめらんこりー", "メディスンメランコ'リー")
        add("メディスン", "めでぃすん", "メデ'ィスン")
        add("風見幽香", "かざみゆうか", "カザミユ'ーカ")
        add("幽香", "ゆうか", "ユ'ーカ")
        add("小野塚小町", "おのづかこまち", "オノヅカコ'マチ")
        add("小町", "こまち", "コ'マチ")
        add("四季映姫・ヤマザナドゥ", "しきえいきやまざなどぅ", "シキエイキヤマザナ'ドゥ")
        add("四季映姫", "しきえいき", "シキエ'イキ")
        add("映姫", "えいき", "エ'イキ")

        // --- 風神録 ---
        add("秋静葉", "あきしずは", "アキシ'ズハ")
        add("静葉", "しずは", "シ'ズハ")
        add("秋穣子", "あきみのりこ", "アキミノ'リコ")
        add("穣子", "みのりこ", "ミノ'リコ")
        add("鍵山雛", "かぎやまひな", "カギヤマヒ'ナ")
        add("雛", "ひな", "ヒ'ナ")
        add("河城にとり", "かわしろにとり", "カワシロニ'トリ")
        add("にとり", "にとり", "ニ'トリ")
        add("犬走椛", "いぬばしりもみじ", "イヌバシリモ'ミジ")
        add("椛", "もみじ", "モ'ミジ")
        add("東風谷早苗", "こちやさなえ", "コチヤサ'ナエ")
        add("東風谷 早苗", "こちやさなえ", "コチヤサ'ナエ")
        add("早苗", "さなえ", "サ'ナエ")
        add("八坂神奈子", "やさかかなこ", "ヤサカカ'ナコ")
        add("神奈子", "かなこ", "カ'ナコ")
        add("洩矢諏訪子", "もりやすわこ", "モリヤス'ワコ")
        add("諏訪子", "すわこ", "ス'ワコ")

        // --- 地霊殿 ---
        add("キスメ", "きすめ", "キ'スメ")
        add("黒谷ヤマメ", "くろだにやまめ", "クロダニヤ'マメ")
        add("ヤマメ", "やまめ", "ヤ'マメ")
        add("水橋パルスィ", "みずはしぱるすぃ", "ミズハシパ'ルスィ")
        add("パルスィ", "ぱるすぃ", "パ'ルスィ")
        add("星熊勇儀", "ほしぐまゆうぎ", "ホシグマユ'ーギ")
        add("勇儀", "ゆうぎ", "ユ'ーギ")
        add("古明地さとり", "こめいじさとり", "コメイジサ'トリ")
        add("古明地 さとり", "こめいじさとり", "コメイジサ'トリ")
        add("さとり", "さとり", "サ'トリ")
        add("火焔猫燐", "かえんびょうりん", "カエンビョーリ'ン")
        add("火焔猫 燐", "かえんびょうりん", "カエンビョーリ'ン")
        add("お燐", "おりん", "オ'リン")
        add("燐", "りん", "リ'ン")
        add("霊烏路空", "れいうじうつほ", "レイウジウ'ツホ")
        add("霊烏路 空", "れいうじうつほ", "レイウジウ'ツホ")
        add("お空", "おくう", "オ'クー")
        add("空", "うつほ", "ウ'ツホ")
        add("古明地こいし", "こめいじこいし", "コメイジコ'イシ")
        add("古明地 こいし", "こめいじこいし", "コメイジコ'イシ")
        add("こいし", "こいし", "コ'イシ")

        // --- 星蓮船 ---
        add("ナズーリン", "なずーりん", "ナズ'ーリン")
        add("多々良小傘", "たたらこがさ", "タタラコ'ガサ")
        add("小傘", "こがさ", "コ'ガサ")
        add("雲居一輪", "くもいいちりん", "クモイイチ'リン")
        add("一輪", "いちりん", "イチ'リン")
        add("雲山", "うんざん", "ウ'ンザン")
        add("村紗水蜜", "むらさみなみつ", "ムラサミ'ナミツ")
        add("村紗", "むらさ", "ム'ラサ")
        add("寅丸星", "とらまるしょう", "トラマルシ'ョー")
        add("寅丸", "とらまる", "トラ'マル")
        add("聖白蓮", "ひじりびゃくれん", "ヒジリビャ'クレン")
        add("白蓮", "びゃくれん", "ビャ'クレン")
        add("封獣ぬえ", "ほうじゅうぬえ", "ホージュウヌ'エ")
        add("ぬえ", "ぬえ", "ヌ'エ")

        // --- 神霊廟 ---
        add("幽谷響子", "かそだにきょうこ", "カソダニキョ'ーコ")
        add("響子", "きょうこ", "キョ'ーコ")
        add("宮古芳香", "みやこよしか", "ミヤコヨ'シカ")
        add("芳香", "よしか", "ヨ'シカ")
        add("霍青娥", "かくせいが", "カクセ'イガ")
        add("青娥", "せいが", "セ'イガ")
        add("蘇我屠自古", "そがのとじこ", "ソガノト'ジコ")
        add("屠自古", "とじこ", "ト'ジコ")
        add("物部布都", "もののべのふと", "モノノベノフ'ト")
        add("布都", "ふと", "フ'ト")
        add("豊聡耳神子", "とよさとみみのみこ", "トヨサトミミノミ'コ")
        add("神子", "みこ", "ミ'コ")
        add("二ッ岩マミゾウ", "ふたついわまみぞう", "フタツイワマミ'ゾウ")
        add("マミゾウ", "まみぞう", "マミ'ゾウ")

        // --- 輝針城 ---
        add("わかさぎ姫", "わかさぎひめ", "ワカサギヒ'メ")
        add("赤蛮奇", "せきばんき", "セキバ'ンキ")
        add("今泉影狼", "いまいずみかげろう", "イマイズミカ'ゲロー")
        add("影狼", "かげろう", "カ'ゲロー")
        add("九十九弁々", "つくもべんべん", "ツクモベ'ンベン")
        add("弁々", "べんべん", "ベ'ンベン")
        add("九十九八橋", "つくもやつはし", "ツクモヤ'ツハシ")
        add("八橋", "やつはし", "ヤ'ツハシ")
        add("鬼人正邪", "きじんせいじゃ", "キジンセ'イジャ")
        add("正邪", "せいじゃ", "セ'イジャ")
        add("少名針妙丸", "すくなしんみょうまる", "スクナシンミョ'ーマル")
        add("針妙丸", "しんみょうまる", "シンミョ'ーマル")
        add("堀川雷鼓", "ほりかわらいこ", "ホリカワラ'イコ")
        add("雷鼓", "らいこ", "ラ'イコ")

        // --- 紺珠伝 ---
        add("清蘭", "せいらん", "セイ'ラン")
        add("鈴瑚", "りんご", "リ'ンゴ")
        add("ドレミー・スイート", "どれみーすいーと", "ドレミースイ'ート")
        add("ドレミー", "どれみー", "ドレ'ミー")
        add("稀神サグメ", "きしんさぐめ", "キシンサ'グメ")
        add("サグメ", "さぐめ", "サ'グメ")
        add("クラウンピース", "くらうんぴーす", "クラウンピ'ース")
        add("純狐", "じゅんこ", "ジュ'ンコ")
        add("ヘカーティア・ラピスラズリ", "へかーてぃあらぴすらずり", "ヘカーティアラピスラ'ズリ")
        add("ヘカーティア", "へかーてぃあ", "ヘカ'ーティア")

        // --- 天空璋 ---
        add("エタニティラルバ", "えたにてぃらるば", "エタニティラ'ルバ")
        add("坂田ネムノ", "さかたねむの", "サカタネ'ムノ")
        add("ネムノ", "ねむの", "ネ'ムノ")
        add("高麗野あうん", "こまのあうん", "コマノア'ウン")
        add("あうん", "あうん", "ア'ウン")
        add("矢田寺成美", "やたでらなるみ", "ヤタデラナ'ルミ")
        add("成美", "なるみ", "ナ'ルミ")
        add("爾子田里乃", "にしださとの", "ニシダサ'トノ")
        add("里乃", "さとの", "サ'トノ")
        add("丁礼田舞", "ていれいだまい", "テイレイダマ'イ")
        add("舞", "まい", "マ'イ")
        add("摩多羅隠岐奈", "またらおきな", "マタラオ'キナ")
        add("隠岐奈", "おきな", "オ'キナ")

        // --- 鬼形獣 ---
        add("戎瓔花", "えびすえいか", "エビスエ'イカ")
        add("瓔花", "えいか", "エ'イカ")
        add("牛崎潤美", "うしざきうるみ", "ウシザキウ'ルミ")
        add("潤美", "うるみ", "ウ'ルミ")
        add("庭渡久侘歌", "にわたりくたか", "ニワタリク'タカ")
        add("久侘歌", "くたか", "ク'タカ")
        add("吉弔八千慧", "きっちょうやちえ", "キッチョーヤ'チエ")
        add("八千慧", "やちえ", "ヤ'チエ")
        add("杖刀偶磨弓", "じょうとうぐうまゆみ", "ジョートーグーマ'ユミ")
        add("磨弓", "まゆみ", "マ'ユミ")
        add("埴安神袿姫", "はにやすしんけいき", "ハニヤスシンケ'イキ")
        add("袿姫", "けいき", "ケ'イキ")
        add("驪駒早鬼", "くろまざき", "クロマザ'キ")
        add("早鬼", "さき", "サ'キ")

        // --- 虹龍洞 ---
        add("豪徳寺ミケ", "ごうとくじみけ", "ゴートクジミ'ケ")
        add("ミケ", "みけ", "ミ'ケ")
        add("山城たかね", "やましろたかね", "ヤマシロタ'カネ")
        add("たかね", "たかね", "タ'カネ")
        add("駒草山如", "こまくささんによ", "コマクササ'ンニョ")
        add("山如", "さんにょ", "サ'ンニョ")
        add("玉造魅須丸", "たまつくりみすまる", "タマツクリミス'マル")
        add("魅須丸", "みすまる", "ミス'マル")
        add("菅牧典", "くだまきつかさ", "クダマキツ'カサ")
        add("典", "つかさ", "ツ'カサ")
        add("飯綱丸龍", "いいづなまるめぐむ", "イイヅナマルメ'グム")
        add("飯綱丸", "いいづなまる", "イイヅナ'マル")
        add("天弓千亦", "てんきゅうちまた", "テンキューチ'マタ")
        add("千亦", "ちまた", "チ'マタ")
        add("姫虫百々世", "ひめむしももよ", "ヒメムシモ'モヨ")
        add("百々世", "ももよ", "モ'モヨ")

        // --- 獣王園 ---
        add("孫美天", "そんびてん", "ソンビ'テン")
        add("三月精", "さんげつせい", "サンゲツ'セイ")
        add("サニーミルク", "さにーみるく", "サニーミ'ルク")
        add("ルナチャイルド", "るなちゃいるど", "ルナチャ'イルド")
        add("スターサファイア", "すたーさふぁいあ", "スターサフ'ァイア")

        // --- 書籍・その他キャラ ---
        add("稗田阿求", "ひえだのあきゅう", "ヒエダノア'キュー")
        add("阿求", "あきゅう", "ア'キュー")
        add("本居小鈴", "もとおりこすず", "モトオリコ'スズ")
        add("小鈴", "こすず", "コ'スズ")
        add("森近霖之助", "もりちかりんのすけ", "モリチカリンノ'スケ")
        add("霖之助", "りんのすけ", "リンノ'スケ")
        add("こーりん", "こーりん", "コ'ーリン")
        add("宇佐見蓮子", "うさみれんこ", "ウサミレ'ンコ")
        add("蓮子", "れんこ", "レ'ンコ")
        add("マエリベリー・ハーン", "まえりべりーはーん", "マエリベリーハ'ーン")
        add("メリー", "めりー", "メ'リー")
        add("宇佐見菫子", "うさみすみれこ", "ウサミスミ'レコ")
        add("菫子", "すみれこ", "スミ'レコ")

        // --- 東方用語・地名 ---
        add("幻想郷", "げんそうきょう", "ゲンソー'キョー", .tohoTerm)
        add("博麗神社", "はくれいじんじゃ", "ハクレイジ'ンジャ", .tohoTerm)
        add("守矢神社", "もりやじんじゃ", "モリヤジ'ンジャ", .tohoTerm)
        add("紅魔館", "こうまかん", "コーマ'カン", .tohoTerm)
        add("白玉楼", "はくぎょくろう", "ハクギョク'ロー", .tohoTerm)
        add("迷いの竹林", "まよいのちくりん", "マヨイノチ'クリン", .tohoTerm)
        add("永遠亭", "えいえんてい", "エイエン'テイ", .tohoTerm)
        add("命蓮寺", "みょうれんじ", "ミョーレ'ンジ", .tohoTerm)
        add("神霊廟", "しんれいびょう", "シンレイ'ビョー", .tohoTerm)
        add("地霊殿", "ちれいでん", "チレイ'デン", .tohoTerm)
        add("妖怪の山", "ようかいのやま", "ヨーカイノ'ヤマ", .tohoTerm)
        add("霧の湖", "きりのみずうみ", "キリノミ'ズウミ", .tohoTerm)
        add("魔法の森", "まほうのもり", "マホーノ'モリ", .tohoTerm)
        add("三途の川", "さんずのかわ", "サンズノ'カワ", .tohoTerm)
        add("無縁塚", "むえんづか", "ムエン'ヅカ", .tohoTerm)
        add("彼岸", "ひがん", "ヒ'ガン", .tohoTerm)
        add("スペルカード", "すぺるかーど", "スペルカ'ード", .tohoTerm)
        add("弾幕", "だんまく", "ダン'マク", .tohoTerm)
        add("符牒", "ふちょう", "フ'チョー", .tohoTerm)
        add("夢想封印", "むそうふういん", "ムソーフ'ーイン", .tohoTerm)
        add("マスタースパーク", "ますたーすぱーく", "マスタースパ'ーク", .tohoTerm)
        add("マスパ", "ますぱ", "マス'パ", .tohoTerm)
        add("殺人ドール", "さつじんどーる", "サツジンド'ール", .tohoTerm)

        // --- 一般・ネットスラング・ゆっくり定型句 ---
        add("ゆっくりしていってね！！！", "ゆっくりしていってね", "ユックリシテイッテ'ネ", .general)
        add("ゆっくりしていってね！", "ゆっくりしていってね", "ユックリシテイッテ'ネ", .general)
        add("ゆっくりしていってね", "ゆっくりしていってね", "ユックリシテイッテ'ネ", .general)
        add("うｐ", "あっぷ", "ア'ップ", .general)
        add("うｐ主", "うぷぬし", "ウプ'ヌシ", .general)
        add("UP主", "うぷぬし", "ウプ'ヌシ", .general)
        add("w", "わら", "ワ'ラ", .general)
        add("ww", "わらわら", "ワ'ラワラ", .general)
        add("www", "わらわら", "ワ'ラワラ", .general)
        add("草", "わら", "ワ'ラ", .general)
        add("初見", "しょけん", "ショ'ケン", .general)
        add("茶番", "ちゃばん", "チャ'バン", .general)

        return presets
    }
}
