"""
東方Project キャラクター定義 & 音声プリセット
ゆっくりボイスメーカー (https://tts.siyukatu.com/maker) 完全準拠
- 重複項目を単一の標準表記に一本化
- ナレーションと操夢（主人公）を同一ボイス（imd1 / 速度100 / 音程115）に一本化
"""

VOICE_TYPES = [
    {"id": "f1", "name": "AquesTalk1 女声1 (f1: 霊夢/レミリア/咲夜/早苗)", "default_speed": 100, "default_pitch": 100},
    {"id": "f2", "name": "AquesTalk1 女声2 (f2: 魔理沙/こいし/パチュリー/チルノ/妖夢/文/妹紅)", "default_speed": 100, "default_pitch": 100},
    {"id": "f3", "name": "AquesTalk1 女声3 (f3: 脱力系)", "default_speed": 100, "default_pitch": 100},
    {"id": "imd1", "name": "AquesTalk1 中性 (imd1: 操夢/ナレーション/お空/小傘/萃香/てゐ/白蓮/橙)", "default_speed": 100, "default_pitch": 115},
    {"id": "m1", "name": "AquesTalk1 男声1 (m1: 霖之助/リグル/きめぇ丸)", "default_speed": 100, "default_pitch": 100},
    {"id": "m2", "name": "AquesTalk1 男声2 (m2: 低音男性)", "default_speed": 95, "default_pitch": 100},
    {"id": "jgr", "name": "AquesTalk1 機械1 (jgr: さとり/フラン/にとり/サニーミルク)", "default_speed": 100, "default_pitch": 100},
    {"id": "dvd", "name": "AquesTalk1 機械2 (dvd: デイブ)", "default_speed": 100, "default_pitch": 100},
    {"id": "r1", "name": "AquesTalk1 ロボット (r1)", "default_speed": 100, "default_pitch": 100},
]

# キャラクター標準定義（重複なし）
# ナレーションは操夢（主人公視点の語り・地の文）と完全に一本化
CHARACTERS = {
    # 主人公 & ナレーション（一本化）
    "操夢": {
        "voice": "imd1",
        "speed": 100,
        "pitch": 115,
        "color": "#3498db",
        "description": "操夢（主人公・ナレーション・地の文）",
        "keywords": ["操夢", "そうむ", "僕", "俺", "西湖公園", "ナレーション", "地の文"]
    },

    # 主要東方キャラクター (ゆっくりボイスメーカー準拠)
    "霊夢": {
        "voice": "f1",
        "speed": 100,
        "pitch": 100,
        "color": "#e74c3c",
        "description": "博麗霊夢",
        "keywords": ["霊夢", "れいむ", "巫女", "あんた"]
    },
    "魔理沙": {
        "voice": "f2",
        "speed": 100,
        "pitch": 100,
        "color": "#f1c40f",
        "description": "霧雨魔理沙",
        "keywords": ["魔理沙", "まりさ", "だぜ"]
    },
    "さとり": {
        "voice": "jgr",
        "speed": 115,
        "pitch": 125,
        "color": "#ff7675",
        "description": "古明地さとり",
        "keywords": ["さとり", "古明地さとり", "心"]
    },
    "こいし": {
        "voice": "f2",
        "speed": 50,
        "pitch": 181,
        "color": "#55efc4",
        "description": "古明地こいし",
        "keywords": ["こいし", "古明地こいし", "無意識"]
    },
    "レミリア": {
        "voice": "f1",
        "speed": 80,
        "pitch": 150,
        "color": "#9b59b6",
        "description": "レミリア・スカーレット",
        "keywords": ["レミリア", "れみりあ", "お嬢様"]
    },
    "フラン": {
        "voice": "jgr",
        "speed": 100,
        "pitch": 100,
        "color": "#e67e22",
        "description": "フランドール・スカーレット",
        "keywords": ["フラン", "ふらん", "フランドール", "お姉様"]
    },
    "パチュリー": {
        "voice": "f2",
        "speed": 120,
        "pitch": 115,
        "color": "#8e44ad",
        "description": "パチュリー・ノーレッジ",
        "keywords": ["パチュリー", "ぱちゅりー", "パチェ", "むきゅー"]
    },
    "咲夜": {
        "voice": "f1",
        "speed": 105,
        "pitch": 125,
        "color": "#95a5a6",
        "description": "十六夜咲夜",
        "keywords": ["咲夜", "さくや", "メイド"]
    },
    "チルノ": {
        "voice": "f2",
        "speed": 115,
        "pitch": 120,
        "color": "#00a8ff",
        "description": "チルノ",
        "keywords": ["チルノ", "ちるの", "あたい", "最強", "バーカ"]
    },
    "妖夢": {
        "voice": "f2",
        "speed": 115,
        "pitch": 120,
        "color": "#2ecc71",
        "description": "魂魄妖夢",
        "keywords": ["妖夢", "ようむ", "みょん", "幽々子様"]
    },
    "文": {
        "voice": "f2",
        "speed": 100,
        "pitch": 125,
        "color": "#2d3436",
        "description": "射命丸文",
        "keywords": ["文", "しゃめいまる", "射命丸", "あやや", "新聞"]
    },
    # 冥界・白玉楼
    "幽々子": {
        "voice": "f1",
        "speed": 95,
        "pitch": 105,
        "color": "#ff9ff3",
        "description": "西行寺幽々子",
        "keywords": ["幽々子", "ゆゆこ", "西行寺", "妖夢、", "死相"]
    },

    # 妖怪の山・守矢神社
    "椛": {
        "voice": "f1",
        "speed": 120,
        "pitch": 110,
        "color": "#b2bec3",
        "description": "犬走椛",
        "keywords": ["椛", "もみじ", "犬走"]
    },
    "早苗": {
        "voice": "f1",
        "speed": 130,
        "pitch": 95,
        "color": "#1abc9c",
        "description": "東風谷早苗",
        "keywords": ["早苗", "さなえ", "東風谷", "常識に囚われては"]
    },
    "神奈子": {
        "voice": "f1",
        "speed": 115,
        "pitch": 90,
        "color": "#6c5ce7",
        "description": "八坂神奈子",
        "keywords": ["神奈子", "かなこ", "八坂", "オンバシラ"]
    },
    "諏訪子": {
        "voice": "f1",
        "speed": 80,
        "pitch": 175,
        "color": "#81ecec",
        "description": "洩矢諏訪子",
        "keywords": ["諏訪子", "すわこ", "洩矢", "あーうー"]
    },
    "にとり": {
        "voice": "jgr",
        "speed": 105,
        "pitch": 105,
        "color": "#0984e3",
        "description": "河城にとり",
        "keywords": ["にとり", "河城", "河童", "きゅうり"]
    },
    "はたて": {
        "voice": "f2",
        "speed": 84,
        "pitch": 121,
        "color": "#e84393",
        "description": "姫海棠はたて",
        "keywords": ["はたて", "姫海棠", "念写"]
    },

    # 永遠亭・迷いの竹林
    "妹紅": {
        "voice": "f2",
        "speed": 100,
        "pitch": 120,
        "color": "#d63031",
        "description": "藤原妹紅",
        "keywords": ["妹紅", "もこう", "藤原", "不死鳥"]
    },
    "輝夜": {
        "voice": "f1",
        "speed": 100,
        "pitch": 120,
        "color": "#a29bfe",
        "description": "蓬莱山輝夜",
        "keywords": ["輝夜", "かぐや", "蓬莱山", "永琳、"]
    },
    "永琳": {
        "voice": "f2",
        "speed": 96,
        "pitch": 100,
        "color": "#0984e3",
        "description": "八意永琳",
        "keywords": ["永琳", "えーりん", "八意", "姫様"]
    },
    "鈴仙": {
        "voice": "f1",
        "speed": 80,
        "pitch": 120,
        "color": "#e056fd",
        "description": "鈴仙・優曇華院・イナバ",
        "keywords": ["鈴仙", "うどんげ", "レイセン", "狂気"]
    },
    "てゐ": {
        "voice": "imd1",
        "speed": 110,
        "pitch": 120,
        "color": "#fab1a0",
        "description": "因幡てゐ",
        "keywords": ["てゐ", "因幡", "ウサギ"]
    },
    "慧音": {
        "voice": "f1",
        "speed": 98,
        "pitch": 100,
        "color": "#00cec9",
        "description": "上白沢慧音",
        "keywords": ["慧音", "けーね", "上白沢", "歴史"]
    },

    # 地霊殿・旧地獄
    "お燐": {
        "voice": "imd1",
        "speed": 110,
        "pitch": 135,
        "color": "#ff7675",
        "description": "火焔猫燐",
        "keywords": ["お燐", "おりん", "火焔猫燐", "あたいの怨霊"]
    },
    "お空": {
        "voice": "imd1",
        "speed": 80,
        "pitch": 170,
        "color": "#e17055",
        "description": "霊烏路空",
        "keywords": ["お空", "おくう", "霊烏路空", "うにゅ"]
    },
    "勇儀": {
        "voice": "f2",
        "speed": 95,
        "pitch": 90,
        "color": "#e67e22",
        "description": "星熊勇儀",
        "keywords": ["勇儀", "ゆうぎ", "星熊"]
    },
    "パルスィ": {
        "voice": "f2",
        "speed": 80,
        "pitch": 130,
        "color": "#00b894",
        "description": "水橋パルスィ",
        "keywords": ["パルスィ", "ぱるすぃ", "水橋", "妬ましい"]
    },
    "ヤマメ": {
        "voice": "f2",
        "speed": 110,
        "pitch": 115,
        "color": "#81ecec",
        "description": "黒谷ヤマメ",
        "keywords": ["ヤマメ", "やまめ", "黒谷"]
    },

    # 命蓮寺・神霊廟
    "白蓮": {
        "voice": "imd1",
        "speed": 102,
        "pitch": 97,
        "color": "#fd79a8",
        "description": "聖白蓮",
        "keywords": ["白蓮", "ひじり", "聖", "南無三"]
    },
    "一輪": {
        "voice": "f2",
        "speed": 65,
        "pitch": 145,
        "color": "#bdc3c7",
        "description": "雲居一輪",
        "keywords": ["一輪", "いちりん", "雲居", "雲山"]
    },
    "村紗": {
        "voice": "f2",
        "speed": 100,
        "pitch": 110,
        "color": "#3498db",
        "description": "村紗水蜜",
        "keywords": ["村紗", "むらさ", "水蜜", "聖輦船"]
    },
    "星": {
        "voice": "f2",
        "speed": 120,
        "pitch": 110,
        "color": "#fdcb6e",
        "description": "寅丸星",
        "keywords": ["星", "寅丸", "とらまる", "宝塔"]
    },
    "ナズーリン": {
        "voice": "f1",
        "speed": 90,
        "pitch": 115,
        "color": "#b2bec3",
        "description": "ナズーリン",
        "keywords": ["ナズーリン", "なずーりん", "ダウジング"]
    },
    "ぬえ": {
        "voice": "f2",
        "speed": 100,
        "pitch": 180,
        "color": "#6c5ce7",
        "description": "封獣ぬえ",
        "keywords": ["ぬえ", "封獣", "正体不明"]
    },
    "響子": {
        "voice": "imd1",
        "speed": 115,
        "pitch": 130,
        "color": "#55efc4",
        "description": "幽谷響子",
        "keywords": ["響子", "きょうこ", "幽谷", "ぎゃーてー"]
    },
    "神子": {
        "voice": "f1",
        "speed": 100,
        "pitch": 110,
        "color": "#f1c40f",
        "description": "豊聡耳神子",
        "keywords": ["神子", "みこ", "豊聡耳", "太子"]
    },
    "布都": {
        "voice": "f1",
        "speed": 110,
        "pitch": 115,
        "color": "#dfe6e9",
        "description": "物部布都",
        "keywords": ["布都", "ふと", "物部", "おじゃる"]
    },
    "屠自古": {
        "voice": "f2",
        "speed": 100,
        "pitch": 105,
        "color": "#00cec9",
        "description": "蘇我屠自古",
        "keywords": ["屠自古", "とじこ", "蘇我", "雷"]
    },
    "青娥": {
        "voice": "f1",
        "speed": 95,
        "pitch": 105,
        "color": "#74b9ff",
        "description": "霍青娥",
        "keywords": ["青娥", "せいが", "青娥娘々", "霍"]
    },
    "芳香": {
        "voice": "f3",
        "speed": 80,
        "pitch": 90,
        "color": "#b2bec3",
        "description": "宮古芳香",
        "keywords": ["芳香", "よしか", "キョンシー"]
    },

    # 魔法使い・香霖堂
    "アリス": {
        "voice": "f1",
        "speed": 110,
        "pitch": 130,
        "color": "#f39c12",
        "description": "アリス・マーガトロイド",
        "keywords": ["アリス", "ありす", "人形", "上海"]
    },
    "霖之助": {
        "voice": "m1",
        "speed": 100,
        "pitch": 105,
        "color": "#7f8c8d",
        "description": "森近霖之助",
        "keywords": ["霖之助", "こーりん", "香霖堂", "森近"]
    },

    # 八雲一家・結界・閻魔
    "紫": {
        "voice": "f2",
        "speed": 95,
        "pitch": 100,
        "color": "#6c5ce7",
        "description": "八雲紫",
        "keywords": ["紫", "ゆかり", "八雲紫", "スキマ"]
    },
    "藍": {
        "voice": "f2",
        "speed": 100,
        "pitch": 100,
        "color": "#ffeaa7",
        "description": "八雲藍",
        "keywords": ["藍", "らん", "八雲藍", "九尾"]
    },
    "橙": {
        "voice": "imd1",
        "speed": 108,
        "pitch": 100,
        "color": "#e17055",
        "description": "橙",
        "keywords": ["橙", "チェン", "ちぇん"]
    },
    "映姫": {
        "voice": "f2",
        "speed": 87,
        "pitch": 117,
        "color": "#00b894",
        "description": "四季映姫・ヤマザナドゥ",
        "keywords": ["映姫", "えいき", "四季映姫", "白黒つける"]
    },
    "小町": {
        "voice": "f1",
        "speed": 90,
        "pitch": 100,
        "color": "#ff7675",
        "description": "小野塚小町",
        "keywords": ["小町", "こまち", "小野塚", "死神", "サボり"]
    },

    # 天界・鬼・仙人
    "天子": {
        "voice": "f2",
        "speed": 75,
        "pitch": 134,
        "color": "#00cec9",
        "description": "比那名居天子",
        "keywords": ["天子", "てんこ", "比那名居", "要石"]
    },
    "衣玖": {
        "voice": "f1",
        "speed": 95,
        "pitch": 105,
        "color": "#e056fd",
        "description": "永江衣玖",
        "keywords": ["衣玖", "いく", "永江", "空気"]
    },
    "萃香": {
        "voice": "imd1",
        "speed": 100,
        "pitch": 150,
        "color": "#e84393",
        "description": "伊吹萃香",
        "keywords": ["萃香", "すいか", "伊吹", "酒"]
    },
    "華扇": {
        "voice": "f1",
        "speed": 100,
        "pitch": 105,
        "color": "#fd79a8",
        "description": "茨木華扇",
        "keywords": ["華扇", "かせん", "茨木", "仙人"]
    },
    "幽香": {
        "voice": "f2",
        "speed": 95,
        "pitch": 100,
        "color": "#27ae60",
        "description": "風見幽香",
        "keywords": ["幽香", "ゆうか", "風見", "ひまわり"]
    },

    # 紅魔館従者・妖精・怪異
    "美鈴": {
        "voice": "f1",
        "speed": 100,
        "pitch": 100,
        "color": "#e17055",
        "description": "紅美鈴",
        "keywords": ["美鈴", "めいりん", "紅美鈴", "門番"]
    },
    "小悪魔": {
        "voice": "f1",
        "speed": 102,
        "pitch": 100,
        "color": "#d63031",
        "description": "小悪魔",
        "keywords": ["小悪魔", "こあくま"]
    },
    "ルーミア": {
        "voice": "imd1",
        "speed": 105,
        "pitch": 100,
        "color": "#fdcb6e",
        "description": "ルーミア",
        "keywords": ["ルーミア", "るーみあ", "そーなのかー"]
    },
    "大妖精": {
        "voice": "imd1",
        "speed": 102,
        "pitch": 100,
        "color": "#a8e6cf",
        "description": "大妖精",
        "keywords": ["大妖精", "大ちゃん"]
    },
    "リリーホワイト": {
        "voice": "f1",
        "speed": 110,
        "pitch": 115,
        "color": "#dfe6e9",
        "description": "リリーホワイト",
        "keywords": ["リリーホワイト", "りりーほわいと", "春ですよ"]
    },
    "ミスティア": {
        "voice": "f1",
        "speed": 100,
        "pitch": 105,
        "color": "#ff7675",
        "description": "ミスティア・ローレライ",
        "keywords": ["ミスティア", "みすちー", "八目鰻"]
    },
    "リグル": {
        "voice": "m1",
        "speed": 110,
        "pitch": 140,
        "color": "#55efc4",
        "description": "リグル・ナイトバグ",
        "keywords": ["リグル", "りぐる", "蟲"]
    },

    # 三月精・プリズムリバー
    "サニーミルク": {
        "voice": "jgr",
        "speed": 125,
        "pitch": 120,
        "color": "#ffeaa7",
        "description": "サニーミルク",
        "keywords": ["サニーミルク", "さにーみるく"]
    },
    "ルナチャイルド": {
        "voice": "f2",
        "speed": 120,
        "pitch": 125,
        "color": "#ffeaa7",
        "description": "ルナチャイルド",
        "keywords": ["ルナチャイルド", "るなちゃいるど"]
    },
    "スターサファイア": {
        "voice": "f1",
        "speed": 105,
        "pitch": 115,
        "color": "#74b9ff",
        "description": "スターサファイア",
        "keywords": ["スターサファイア", "すたーさふぁいあ", "スター"]
    },
    "ルナサ": {
        "voice": "f2",
        "speed": 90,
        "pitch": 95,
        "color": "#bdc3c7",
        "description": "ルナサ・プリズムリバー",
        "keywords": ["ルナサ", "るなさ", "バイオリン"]
    },
    "メルラン": {
        "voice": "f1",
        "speed": 110,
        "pitch": 125,
        "color": "#ff7675",
        "description": "メルラン・プリズムリバー",
        "keywords": ["メルラン", "めるらん", "トランペット"]
    },
    "リリカ": {
        "voice": "f1",
        "speed": 95,
        "pitch": 135,
        "color": "#fab1a0",
        "description": "リリカ・プリズムリバー",
        "keywords": ["リリカ", "りりか", "キーボード"]
    },

    # 輝針城・紺珠伝・天空璋・鬼形獣・虹龍洞
    "正邪": {
        "voice": "f2",
        "speed": 110,
        "pitch": 120,
        "color": "#d63031",
        "description": "鬼人正邪",
        "keywords": ["正邪", "せいじゃ", "鬼人", "下克上", "ひっくり返す"]
    },
    "針妙丸": {
        "voice": "f1",
        "speed": 115,
        "pitch": 145,
        "color": "#0984e3",
        "description": "少名針妙丸",
        "keywords": ["針妙丸", "しんみょうまる", "少名", "打ち出の小槌"]
    },
    "こころ": {
        "voice": "f3",
        "speed": 90,
        "pitch": 100,
        "color": "#fd79a8",
        "description": "秦こころ",
        "keywords": ["こころ", "秦こころ", "希望の面", "感情"]
    },
    "わかさぎ姫": {
        "voice": "f1",
        "speed": 100,
        "pitch": 110,
        "color": "#74b9ff",
        "description": "わかさぎ姫",
        "keywords": ["わかさぎ姫", "わかさぎひめ", "人魚"]
    },
    "赤蛮奇": {
        "voice": "f2",
        "speed": 100,
        "pitch": 105,
        "color": "#d63031",
        "description": "赤蛮奇",
        "keywords": ["赤蛮奇", "せきばんき", "ろくろ首"]
    },
    "影狼": {
        "voice": "f1",
        "speed": 100,
        "pitch": 115,
        "color": "#636e72",
        "description": "今泉影狼",
        "keywords": ["影狼", "かげろう", "今泉", "人狼"]
    },
    "クラウンピース": {
        "voice": "f1",
        "speed": 115,
        "pitch": 135,
        "color": "#e74c3c",
        "description": "クラウンピース",
        "keywords": ["クラウンピース", "くらうんぴーす", "クラピ", "狂気"]
    },
    "純狐": {
        "voice": "f1",
        "speed": 90,
        "pitch": 95,
        "color": "#f1c40f",
        "description": "純狐",
        "keywords": ["純狐", "じゅんこ", "嫦娥"]
    },
    "ヘカーティア": {
        "voice": "f1",
        "speed": 100,
        "pitch": 110,
        "color": "#e84393",
        "description": "ヘカーティア・ラピスラズリ",
        "keywords": ["ヘカーティア", "へかーてぃあ", "地獄の女神"]
    },
    "サグメ": {
        "voice": "f2",
        "speed": 90,
        "pitch": 95,
        "color": "#bdc3c7",
        "description": "稀神サグメ",
        "keywords": ["サグメ", "さぐめ", "稀神", "口にした事"]
    },
    "ドレミー": {
        "voice": "f1",
        "speed": 95,
        "pitch": 100,
        "color": "#d63031",
        "description": "ドレミー・スイート",
        "keywords": ["ドレミー", "どれみー", "夢魂"]
    },
    "清蘭": {
        "voice": "f1",
        "speed": 105,
        "pitch": 120,
        "color": "#0984e3",
        "description": "清蘭",
        "keywords": ["清蘭", "せいらん", "玉兎"]
    },
    "鈴瑚": {
        "voice": "f2",
        "speed": 100,
        "pitch": 110,
        "color": "#fdcb6e",
        "description": "鈴瑚",
        "keywords": ["鈴瑚", "りんご", "団子"]
    },
    "隠岐奈": {
        "voice": "f2",
        "speed": 96,
        "pitch": 100,
        "color": "#e84393",
        "description": "摩多羅隠岐奈",
        "keywords": ["隠岐奈", "おきな", "摩多羅", "秘神"]
    },
    "舞": {
        "voice": "f1",
        "speed": 105,
        "pitch": 120,
        "color": "#a8e6cf",
        "description": "丁礼田舞",
        "keywords": ["舞", "丁礼田舞", "ていれいだ"]
    },
    "里乃": {
        "voice": "f2",
        "speed": 105,
        "pitch": 110,
        "color": "#ffd3b6",
        "description": "爾子田里乃",
        "keywords": ["里乃", "爾子田里乃", "にしだ"]
    },
    "マミゾウ": {
        "voice": "f2",
        "speed": 95,
        "pitch": 100,
        "color": "#a29bfe",
        "description": "二ッ岩マミゾウ",
        "keywords": ["マミゾウ", "まみぞう", "二ッ岩", "〜じゃろ", "化け狸"]
    },
    "女苑": {
        "voice": "f1",
        "speed": 110,
        "pitch": 125,
        "color": "#ff7675",
        "description": "依神女苑",
        "keywords": ["女苑", "じょおん", "依神", "ゴージャス", "散財"]
    },
    "紫苑": {
        "voice": "f3",
        "speed": 85,
        "pitch": 95,
        "color": "#74b9ff",
        "description": "依神紫苑",
        "keywords": ["紫苑", "しおん", "貧乏神"]
    },
    "袿姫": {
        "voice": "f1",
        "speed": 100,
        "pitch": 105,
        "color": "#ffeaa7",
        "description": "埴安神袿姫",
        "keywords": ["袿姫", "けいき", "埴安神", "造形術"]
    },
    "磨弓": {
        "voice": "f2",
        "speed": 100,
        "pitch": 105,
        "color": "#fab1a0",
        "description": "杖刀偶磨弓",
        "keywords": ["磨弓", "まゆみ", "埴輪", "兵長"]
    },
    "千亦": {
        "voice": "f1",
        "speed": 100,
        "pitch": 100,
        "color": "#e056fd",
        "description": "天弓千亦",
        "keywords": ["千亦", "ちまた", "天弓", "市場"]
    },
    "百々世": {
        "voice": "f2",
        "speed": 105,
        "pitch": 95,
        "color": "#2d3436",
        "description": "姫虫百々世",
        "keywords": ["百々世", "ももよ", "姫虫", "大百足"]
    },
    "典": {
        "voice": "f1",
        "speed": 105,
        "pitch": 125,
        "color": "#dfe6e9",
        "description": "菅牧典",
        "keywords": ["典", "つか", "菅牧", "管狐"]
    },
    "魅魔": {
        "voice": "f1",
        "speed": 95,
        "pitch": 100,
        "color": "#6c5ce7",
        "description": "魅魔",
        "keywords": ["魅魔", "みま", "悪霊"]
    },
    "神綺": {
        "voice": "f1",
        "speed": 90,
        "pitch": 110,
        "color": "#ff7675",
        "description": "神綺",
        "keywords": ["神綺", "しんき", "魔界の神"]
    },
    "きめぇ丸": {
        "voice": "m1",
        "speed": 80,
        "pitch": 140,
        "color": "#636e72",
        "description": "きめぇ丸",
        "keywords": ["きめぇ丸", "きめぇまる"]
    }
}

# 表記ゆれ・別名の正規化マッピング
CHARACTER_ALIASES = {
    "ナレーション": "操夢",
    "地の文": "操夢",
    "そうむ": "操夢",
    "主人公": "操夢",
    "れいむ": "霊夢",
    "博麗霊夢": "霊夢",
    "まりさ": "魔理沙",
    "霧雨魔理沙": "魔理沙",
    "古明地さとり": "さとり",
    "古明地こいし": "こいし",
    "ふらん": "フラン",
    "フランドール": "フラン",
    "フランドール・スカーレット": "フラン",
    "れみりあ": "レミリア",
    "レミリア・スカーレット": "レミリア",
    "ぱちゅりー": "パチュリー",
    "パチュリー・ノーレッジ": "パチュリー",
    "パチェ": "パチュリー",
    "さくや": "咲夜",
    "十六夜咲夜": "咲夜",
    "ちるの": "チルノ",
    "ようむ": "妖夢",
    "魂魄妖夢": "妖夢",
    "ゆゆこ": "幽々子",
    "西行寺幽々子": "幽々子",
    "しゃめいまる": "文",
    "射命丸文": "文",
    "射命丸": "文",
    "もみじ": "椛",
    "犬走椛": "椛",
    "さなえ": "早苗",
    "東風谷早苗": "早苗",
    "もこう": "妹紅",
    "藤原妹紅": "妹紅",
    "こーりん": "霖之助",
    "森近霖之助": "霖之助",
    "河城にとり": "にとり",
    "河童": "にとり",
    "ありす": "アリス",
    "アリス・マーガトロイド": "アリス",
    "いちりん": "一輪",
    "雲居一輪": "一輪",
    "むらさ": "村紗",
    "村紗水蜜": "村紗",
    "うどんげ": "鈴仙",
    "レイセン": "鈴仙",
    "鈴仙・優曇華院・イナバ": "鈴仙",
    "えいき": "映姫",
    "四季映姫": "映姫",
    "四季映姫・ヤマザナドゥ": "映姫",
    "こまち": "小町",
    "小野塚小町": "小町",
    "おくう": "お空",
    "霊烏路空": "お空",
    "おりん": "お燐",
    "火焔猫燐": "お燐",
    "ゆうぎ": "勇儀",
    "星熊勇儀": "勇儀",
    "かぐや": "輝夜",
    "蓬莱山輝夜": "輝夜",
    "かなこ": "神奈子",
    "八坂神奈子": "神奈子",
    "こがさ": "小傘",
    "多々良小傘": "小傘",
    "さにーみるく": "サニーミルク",
    "すいか": "萃香",
    "伊吹萃香": "萃香",
    "すわこ": "諏訪子",
    "洩矢諏訪子": "諏訪子",
    "てんこ": "天子",
    "比那名居天子": "天子",
    "いく": "衣玖",
    "永江衣玖": "衣玖",
    "かせん": "華扇",
    "茨木華扇": "華扇",
    "とらまる": "星",
    "寅丸星": "星",
    "なずーりん": "ナズーリン",
    "はたて": "はたて",
    "姫海棠はたて": "はたて",
    "ぱるすぃ": "パルスィ",
    "水橋パルスィ": "パルスィ",
    "ひじり": "白蓮",
    "聖白蓮": "白蓮",
    "きょうこ": "響子",
    "幽谷響子": "響子",
    "みこ": "神子",
    "豊聡耳神子": "神子",
    "ふと": "布都",
    "物部布都": "布都",
    "とじこ": "屠自古",
    "蘇我屠自古": "屠自古",
    "せいが": "青娥",
    "霍青娥": "青娥",
    "よしか": "芳香",
    "宮古芳香": "芳香",
    "みすちー": "ミスティア",
    "ミスティア・ローレライ": "ミスティア",
    "やまめ": "ヤマメ",
    "黒谷ヤマメ": "ヤマメ",
    "りぐる": "リグル",
    "リグル・ナイトバグ": "リグル",
    "りりーほわいと": "リリーホワイト",
    "るなさ": "ルナサ",
    "ルナサ・プリズムリバー": "ルナサ",
    "めるらん": "メルラン",
    "メルラン・プリズムリバー": "メルラン",
    "りりか": "リリカ",
    "リリカ・プリズムリバー": "リリカ",
    "るなちゃいるど": "ルナチャイルド",
    "すたーさふぁいあ": "スターサファイア",
    "スター": "スターサファイア",
    "八雲紫": "紫",
    "ゆかり": "紫",
    "八雲藍": "藍",
    "らん": "藍",
    "チェン": "橙",
    "ちぇん": "橙",
    "八意永琳": "永琳",
    "えーりん": "永琳",
    "上白沢慧音": "慧音",
    "けーね": "慧音",
    "風見幽香": "幽香",
    "ゆうか": "幽香",
    "紅美鈴": "美鈴",
    "めいりん": "美鈴",
    "こあくま": "小悪魔",
    "るーみあ": "ルーミア",
    "せいじゃ": "正邪",
    "鬼人正邪": "正邪",
    "しんみょうまる": "針妙丸",
    "少名針妙丸": "針妙丸",
    "秦こころ": "こころ",
    "わかさぎひめ": "わかさぎ姫",
    "せきばんき": "赤蛮奇",
    "かげろう": "影狼",
    "今泉影狼": "影狼",
    "くらうんぴーす": "クラウンピース",
    "クラピ": "クラウンピース",
    "じゅんこ": "純狐",
    "へかーてぃあ": "ヘカーティア",
    "ヘカーティア・ラピスラズリ": "ヘカーティア",
    "さぐめ": "サグメ",
    "稀神サグメ": "サグメ",
    "どれみー": "ドレミー",
    "ドレミー・スイート": "ドレミー",
    "せいらん": "清蘭",
    "りんご": "鈴瑚",
    "二ッ岩マミゾウ": "マミゾウ",
    "まみぞう": "マミゾウ",
    "摩多羅隠岐奈": "隠岐奈",
    "おきな": "隠岐奈",
    "ていれいだ": "舞",
    "丁礼田舞": "舞",
    "にしだ": "里乃",
    "爾子田里乃": "里乃",
    "じょおん": "女苑",
    "依神女苑": "女苑",
    "しおん": "紫苑",
    "依神紫苑": "紫苑",
    "けいき": "袿姫",
    "埴安神袿姫": "袿姫",
    "まゆみ": "磨弓",
    "杖刀偶磨弓": "磨弓",
    "ちまた": "千亦",
    "天弓千亦": "千亦",
    "ももよ": "百々世",
    "姫虫百々世": "百々世",
    "つか": "典",
    "菅牧典": "典",
    "みま": "魅魔",
    "しんき": "神綺",
    "きめぇまる": "きめぇ丸"
}


def get_character_info(name: str) -> dict:
    """
    キャラクター名に対応する設定を返す。
    表記ゆれや別名を正規化して取得。
    未登録やナレーションはすべて操夢（主人公設定）を返す。
    """
    # エイリアス解決
    canonical_name = CHARACTER_ALIASES.get(name, name)
    if canonical_name in CHARACTERS:
        return CHARACTERS[canonical_name]
    
    # 未知のキャラクターまたはナレーションはデフォルトで操夢（imd1/100/115）
    soumu = CHARACTERS["操夢"]
    return {
        "voice": soumu["voice"],
        "speed": soumu["speed"],
        "pitch": soumu["pitch"],
        "color": "#3498db",
        "description": name,
        "keywords": []
    }
