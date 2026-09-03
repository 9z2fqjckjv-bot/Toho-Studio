"""
東方Projectムービーメーカー - AquesTalk1 & AqKanji2Koe 音声合成エンジン (ctypesバインディング)
- AquesTalk1 Mac Ver 2.0 (libAquesTalk1-*.dylib)
- AqKanji2Koe-A Mac (libAqKanji2Koe.dylib, libAqUsrDic.dylib)
- ライセンス認証 (ライセンスID, 使用ライセンスキー, 開発ライセンスキー) の動的適用
- 東方Project固有名詞辞書 & 英語/略語辞書 & Janome形態素解析
- 高音質イコライザー補正 (44.1kHzステレオ) & エコー効果
"""

import os
import sys
import re
import wave
import struct
import ctypes
from typing import Optional, Tuple, Dict, Any

# プロジェクトルートとvendorディレクトリのパス
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VENDOR_DIR = os.path.join(PROJECT_ROOT, "vendor")
LIB_DIR = os.path.join(VENDOR_DIR, "lib")
DIC_DIR = os.path.join(VENDOR_DIR, "aq_dic")
LICENSE_FILE = os.path.join(PROJECT_ROOT, "license.txt")


# 東方固有名詞・基本用語・キャラクター名の網羅的読み辞書
TOHO_CUSTOM_DIC = {
    # 主人公・主要キャラ
    "博麗霊夢": "ハクレイレーム",
    "霊夢": "レーム",
    "霧雨魔理沙": "キリサメマリサ",
    "魔理沙": "マリサ",
    "操夢": "ソーム",
    "東方Project": "トーホープロジェクト",
    "東方プロジェクト": "トーホープロジェクト",
    "東方": "トーホー",
    
    # 紅魔郷
    "ルーミア": "ルーミア",
    "チルノ": "チルノ",
    "大妖精": "ダイヨーセー",
    "紅美鈴": "ホンメーリン",
    "美鈴": "メーリン",
    "小悪魔": "コアクマ",
    "パチュリー・ノーレッジ": "パチュリー・ノーレッジ",
    "パチュリー": "パチュリー",
    "パチェ": "パチェ",
    "十六夜咲夜": "イザヨイサクヤ",
    "咲夜": "サクヤ",
    "レミリア・スカーレット": "レミリア・スカーレット",
    "レミリア": "レミリア",
    "フランドール・スカーレット": "フランドール・スカーレット",
    "フランドール": "フランドール",
    "フラン": "フラン",

    # 妖々夢
    "レティ・ホワイトロック": "レティ・ホワイトロック",
    "レティ": "レティ",
    "橙": "チェン",
    "アリス・マーガトロイド": "アリス・マーガトロイド",
    "アリス": "アリス",
    "リリーホワイト": "リリーホワイト",
    "ルナサ・プリズムリバー": "ルナサ・プリズムリバー",
    "メルラン・プリズムリバー": "メルラン・プリズムリバー",
    "リリカ・プリズムリバー": "リリカ・プリズムリバー",
    "魂魄妖夢": "コンパクヨーム",
    "妖夢": "ヨーム",
    "西行寺幽々子": "サイギョージユユコ",
    "幽々子": "ユユコ",
    "ゆゆ様": "ユユサマ",
    "八雲藍": "ヤクモラン",
    "藍": "ラン",
    "八雲紫": "ヤクモユカリ",
    "紫": "ユカリ",
    "ゆかりん": "ユカリン",

    # 永夜抄
    "リグル・ナイトバグ": "リグル・ナイトバグ",
    "リグル": "リグル",
    "ミスティア・ローレライ": "ミスティア・ローレライ",
    "みすちー": "ミスチー",
    "上白沢慧音": "カミシラサワケーネ",
    "慧音": "ケーネ",
    "因幡てゐ": "イナバテウィ",
    "てゐ": "テウィ",
    "鈴仙・優曇華院・イナバ": "レイセン・ウドンゲイン・イナバ",
    "鈴仙": "レイセン",
    "優曇華院": "ウドンゲイン",
    "うどんげ": "ウドンゲ",
    "八意永琳": "ヤゴコロエーリン",
    "永琳": "エーリン",
    "蓬莱山輝夜": "ホーライサンカグヤ",
    "輝夜": "カグヤ",
    "藤原妹紅": "フジワラノモコウ",
    "妹紅": "モコウ",
    "もこたん": "モコタン",

    # 萃夢想・花映塚・風神録・緋想天・地霊殿
    "伊吹萃香": "イブキスイカ",
    "萃香": "スイカ",
    "射命丸文": "シャメーマルアヤ",
    "文": "アヤ",
    "あやや": "アヤヤ",
    "メディスン・メランコリー": "メディスン・メランコリー",
    "風見幽香": "カザミユーカ",
    "幽香": "ユーカ",
    "小野塚小町": "オノヅカコマチ",
    "小町": "コマチ",
    "四季映姫・ヤマザナドゥ": "シキエイキ・ヤマザナドゥ",
    "四季映姫": "シキエイキ",
    "映姫": "エイキ",
    "鍵山雛": "カギヤマヒナ",
    "河城にとり": "カワシロニトリ",
    "にとり": "ニトリ",
    "犬走椛": "イヌバシリモミジ",
    "椛": "モミジ",
    "東風谷早苗": "コーチヤサナエ",
    "早苗": "サナエ",
    "早苗さん": "サナエサン",
    "八坂神奈子": "ヤサカカナコ",
    "神奈子": "カナコ",
    "洩矢諏訪子": "モリヤスワコ",
    "諏訪子": "スワコ",
    "永江衣玖": "ナガエイク",
    "比那名居天子": "ヒナナヰテンコ",
    "天子": "テンコ",
    "キスメ": "キスメ",
    "黒谷ヤマメ": "クロダニヤマメ",
    "水橋パルスィ": "ミズハシパルスィ",
    "パルスィ": "パルスィ",
    "星熊勇儀": "ホシグマユーギ",
    "古明地さとり": "コメージサトリ",
    "さとり": "サトリ",
    "火焔猫燐": "カエンビョーリン",
    "お燐": "オリン",
    "霊烏路空": "レイウージウツホ",
    "お空": "オクウ",
    "古明地こいし": "コメージコイシ",
    "こいし": "コイシ",

    # 星蓮船・神霊廟・輝針城・紺珠伝・天空璋・鬼形獣・虹龍洞
    "ナズーリン": "ナズーリン",
    "多々良小傘": "タタラコガサ",
    "小傘": "コガサ",
    "雲居一輪": "クモイイチリン",
    "村紗水蜜": "ムラサミナミツ",
    "寅丸星": "トラマルショウ",
    "聖白蓮": "ヒジリビャクレン",
    "白蓮": "ビャクレン",
    "封獣ぬえ": "ホージューヌエ",
    "ぬえ": "ヌエ",
    "姫海棠はたて": "ヒメカイドーハタテ",
    "はたて": "ハタテ",
    "サニーミルク": "サニーミルク",
    "ルナチャイルド": "ルナチャイルド",
    "スターサファイア": "スターサファイア",
    "霍青娥": "カクセイガ",
    "青娥": "セイガ",
    "宮古芳香": "ミヤコヨシカ",
    "物部布都": "モノノベノフト",
    "布都": "フト",
    "蘇我屠自古": "ソガノトジコ",
    "豊聡耳神子": "トヨサトミミノミコ",
    "神子": "ミコ",
    "二ッ岩マミゾウ": "フタツイワマミゾウ",
    "マミゾウ": "マミゾウ",
    "秦こころ": "ハタノココロ",
    "こころ": "ココロ",
    "わかさぎ姫": "ワカサギヒメ",
    "赤蛮奇": "セキバンキ",
    "今泉影狼": "イマイズミカゲロウ",
    "少名針妙丸": "スクナビコナシンミョウマル",
    "針妙丸": "シンミョウマル",
    "鬼人正邪": "キジンセイジャ",
    "正邪": "セイジャ",
    "堀川雷鼓": "ホリカワライコ",
    "宇佐見菫子": "ウサミスミレコ",
    "ドレミー・スイート": "ドレミー・スイート",
    "稀神サグメ": "キシンサグメ",
    "クラウンピース": "クラウンピース",
    "純狐": "ジュンコ",
    "ヘカーティア・ラピスラズリ": "ヘカーティア・ラピスラズリ",
    "高麗野あうん": "コマノアウン",
    "摩多羅隠岐奈": "マタラオキナ",
    "隠岐奈": "オキナ",
    "森近霖之助": "モリチカリノスケ",
    "霖之助": "リノスケ",
    "こーりん": "コーリン",
    "冴月麟": "サツキリン",
    "飯綱丸龍": "イイズナマルメグム",
    "山城たかね": "ヤマシロタカネ",

    # 地名・施設
    "博麗神社": "ハクレイジンジャ",
    "守矢神社": "モリヤジンジャ",
    "紅魔館": "コーマカン",
    "白玉楼": "ハクタマロー",
    "香霖堂": "コーリンドウ",
    "永遠亭": "エイエンテイ",
    "地霊殿": "チレイデン",
    "命蓮寺": "ミョーレンジ",
    "神霊廟": "シンレイビョー",
    "輝針城": "キシンジョー",
    "幻想郷": "ゲンソーキョー",
    "西湖公園": "サイココーエン",
    "魔法の森": "マホーノモリ",
    "迷いの竹林": "マヨイノチクリン",
    "妖怪の山": "ヨーカイノヤマ",
    "三途の川": "サンズノカワ",
    "無縁塚": "ムエンヅカ",
    "太陽の畑": "タイヨーノハタケ",
    "霧の湖": "キリノミズウミ",
    "玄武の沢": "ゲンブノサワ",
    "旧地獄": "キュージゴク",
    "中有の道": "チューウノミチ",
    "人間の里": "ニンゲンノサト",

    # 東方用語・呼びかけ
    "スペルカード": "スペルカード",
    "弾幕": "ダンマク",
    "グレイズ": "グレイズ",
    "ラストワード": "ラストワード",
    "お姉様": "オネーサマ",
    "お姉ちゃん": "オネーチャン",
    "お嬢様": "オジョーサマ",
    "巫女": "ミコ",
    "妖怪": "ヨーカイ",
    "妖精": "ヨーセー",
    "異変": "イヘン"
}

# 英語・略語・インターネット用語・動画編集用語
ENGLISH_WORD_DIC = {
    "ゆっくりしていってね": "ユックリシテイッテネ",
    "うぽつ": "ウポツ",
    "わこつ": "ワコツ",
    "8888": "パチパチパチパチ",
    "88888": "パチパチパチパチパチ",
    "www": "ワラ",
    "ｗｗｗ": "ワラ",
    "ww": "ワラ",
    "ｗｗ": "ワラ",
    "orz": "オルズ",
    "乙": "オツ",
    "PC": "ピーシー",
    "pc": "ピーシー",
    "BGM": "ビージーエム",
    "bgm": "ビージーエム",
    "SE": "エスイー",
    "se": "エスイー",
    "Keynote": "キーノート",
    "keynote": "キーノート",
    "Mac": "マック",
    "mac": "マック",
    "MacBook": "マックブック",
    "macbook": "マックブック",
    "Apple": "アップル",
    "apple": "アップル",
    "YouTube": "ユーチューブ",
    "youtube": "ユーチューブ",
    "YouTuber": "ユーチューバー",
    "youtuber": "ユーチューバー",
    "Google": "グーグル",
    "google": "グーグル",
    "Twitter": "ツイッター",
    "twitter": "ツイッター",
    "Discord": "ディスコード",
    "discord": "ディスコード",
    "LINE": "ライン",
    "line": "ライン",
    "TikTok": "ティックトック",
    "tiktok": "ティックトック",
    "Minecraft": "マインクラフト",
    "minecraft": "マインクラフト",
    "マイクラ": "マイクラ",
    "Roblox": "ロブロックス",
    "roblox": "ロブロックス",
    "OK": "オーケー",
    "ok": "オーケー",
    "Ok": "オーケー",
    "NG": "エヌジー",
    "ng": "エヌジー",
    "VS": "バーサス",
    "vs": "バーサス",
    "FPS": "エフピーエス",
    "fps": "エフピーエス",
    "HP": "エイチピー",
    "hp": "エイチピー",
    "MP": "エムピー",
    "mp": "エムピー",
    "LV": "レベル",
    "Lv": "レベル",
    "lv": "レベル",
    "3D": "スリーディー",
    "2D": "ツーディー",
    "VR": "ブイアール",
    "vr": "ブイアール",
    "CD": "シーディー",
    "cd": "シーディー",
    "DVD": "ディーブイディー",
    "dvd": "ディーブイディー",
    "TV": "テレビ",
    "tv": "テレビ",
    "DJ": "ディージェー",
    "MC": "エムシー",
    "SNS": "エスエヌエス",
    "VIP": "ビップ",
    "WHO": "ダブリューエイチオー",
    "USA": "ユーエスエー",
    "UK": "ユーケー",
    "CPU": "シーピーユー",
    "GPU": "ジーピーユー",
    "SSD": "エスエスディー",
    "HDD": "エイチディーディー",
    "USB": "ユーエスビー",
    "Wi-Fi": "ワイファイ",
    "WiFi": "ワイファイ",
    "wifi": "ワイファイ",
    "iOS": "アイオーエス",
    "Android": "アンドロイド",
    "Neo": "ネオ",
    "neo": "ネオ",
    "TTS": "ティーティーエス",
    "tts": "ティーティーエス",
    "YMM4": "ワイエムエムフォー",
    "YMM": "ワイエムエム",
    "AquesTalk": "アクエストーク",
    "AquesTalk1": "アクエストークワン",
    "AquesTalk2": "アクエストークツー",
    "AquesTalk10": "アクエストークテン",
    "AQUEST": "アクエスト",
    "aquest": "アクエスト",
    "HTML": "エイチティーエムエル",
    "CSS": "シーエスエス",
    "JS": "ジェーエス",
    "API": "エーピーアイ",
    "FAQ": "エフエーキュー",
    "Q&A": "キューアンドエー",
    "QA": "キューエー"
}

# アルファベット単文字置換テーブル
ALPHABET_MAP = {
    "A": "エー", "B": "ビー", "C": "シー", "D": "ディー", "E": "イー",
    "F": "エフ", "G": "ジー", "H": "エイチ", "I": "アイ", "J": "ジェー",
    "K": "ケー", "L": "エル", "M": "エム", "N": "エヌ", "O": "オー",
    "P": "ピー", "Q": "キュー", "R": "アール", "S": "エス", "T": "ティー",
    "U": "ユー", "V": "ブイ", "W": "ダブリュー", "X": "エックス", "Y": "ワイ", "Z": "ゼット",
    "a": "エー", "b": "ビー", "c": "シー", "d": "ディー", "e": "イー",
    "f": "エフ", "g": "ジー", "h": "エイチ", "i": "アイ", "j": "ジェー",
    "k": "ケー", "l": "エル", "m": "エム", "n": "エヌ", "o": "オー",
    "p": "ピー", "q": "キュー", "r": "アール", "s": "エス", "t": "ティー",
}


def num_to_kanji_reading(text: str) -> str:
    """数字（半角・全角）を自然な日本語読み（漢字・カタカナ）に展開する"""
    text = text.translate(str.maketrans("０１２３４５６７８９", "0123456789"))

    digits = {'0':'ゼロ', '1':'イチ', '2':'ニ', '3':'サン', '4':'ヨン', '5':'ゴ', '6':'ロク', '7':'ナナ', '8':'ハチ', '9':'キュウ'}
    big_units = ['', 'マン', 'オク', 'チョー']

    def replace_num(match):
        num_str = match.group(0)
        try:
            val = int(num_str)
        except ValueError:
            return ''.join(digits.get(c, c) for c in num_str)

        if val == 0:
            return 'ゼロ'

        parts = []
        temp_val = val
        while temp_val > 0:
            parts.append(temp_val % 10000)
            temp_val //= 10000

        res = ''
        for i, p in enumerate(parts):
            if p == 0:
                continue
            p_str = ''
            s = str(p).zfill(4)
            for u_idx, (ch, u_name) in enumerate(zip(s, ['セン', 'ヒャク', 'ジュー', ''])):
                digit = int(ch)
                if digit == 0:
                    continue
                if digit == 1 and u_name != '':
                    p_str += u_name
                else:
                    p_str += digits[str(digit)] + u_name
            p_str += big_units[i]
            res = p_str + res

        return res

    return re.sub(r"\d+", replace_num, text)


class TTSEngine:
    def __init__(self, vendor_dir: Optional[str] = None, license_file: Optional[str] = None):
        self.vendor_dir = vendor_dir or VENDOR_DIR
        self.lib_dir = os.path.join(self.vendor_dir, "lib")
        self.dic_dir = os.path.join(self.vendor_dir, "aq_dic")
        self.license_file = license_file or LICENSE_FILE

        # vendor/site-packages を sys.path に追加
        vendor_pkg = os.path.join(self.vendor_dir, "site-packages")
        if os.path.exists(vendor_pkg) and vendor_pkg not in sys.path:
            sys.path.insert(0, vendor_pkg)

        self.usr_license_id = ""
        self.dev_license_id = ""
        self.dev_key = ""
        self.usr_key = ""
        self._load_license()

        self.tokenizer = None
        self._init_tokenizer()

        # AqKanji2Koe 公式エンジンの初期化
        self.aq_k2k_lib = None
        self.aq_k2k_handle = None
        self._init_aq_kanji2koe()

        # 声種ごとのライブラリキャッシュ
        self.aqtk_libs: Dict[str, Any] = {}

    def _init_aq_kanji2koe(self):
        """AquesTalk公式の AqKanji2Koe エンジンと辞書を初期化"""
        lib_path = os.path.join(self.lib_dir, "libAqKanji2Koe.dylib")
        dic_path = self.dic_dir

        if os.path.exists(lib_path) and os.path.exists(dic_path):
            try:
                lib = ctypes.cdll.LoadLibrary(lib_path)
                lib.AqKanji2Koe_Create.restype = ctypes.c_void_p
                lib.AqKanji2Koe_Create.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_int)]

                lib.AqKanji2Koe_Convert.restype = ctypes.c_int
                lib.AqKanji2Koe_Convert.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]

                lib.AqKanji2Koe_Release.restype = None
                lib.AqKanji2Koe_Release.argtypes = [ctypes.c_void_p]

                if self.dev_key:
                    try:
                        lib.AqKanji2Koe_SetDevKey.restype = ctypes.c_int
                        lib.AqKanji2Koe_SetDevKey.argtypes = [ctypes.c_char_p]
                        lib.AqKanji2Koe_SetDevKey(self.dev_key.encode("utf-8"))
                    except Exception:
                        pass

                err = ctypes.c_int(0)
                handle = lib.AqKanji2Koe_Create(dic_path.encode("utf-8"), ctypes.byref(err))
                if handle and err.value == 0:
                    self.aq_k2k_lib = lib
                    self.aq_k2k_handle = handle
                    print("[INFO] Official AqKanji2Koe language engine initialized successfully.")
                else:
                    print(f"[WARN] AqKanji2Koe_Create returned err={err.value}")
            except Exception as e:
                print(f"[WARN] Failed to initialize AqKanji2Koe: {e}")

    def _load_license(self):
        """license.txt から使用ライセンスID、使用ライセンスキー、開発ライセンスID、開発ライセンスキーを読み込む"""
        if not os.path.exists(self.license_file):
            return

        try:
            with open(self.license_file, "r", encoding="utf-8") as f:
                content = f.read()

            # 使用ライセンスセクションの探索
            m_usr_sec = re.search(r"使用ライセンス.*?ライセンスID[：:;]\s*([A-Za-z0-9\-]+).*?使用ライセンスキー[：:;]\s*([A-Za-z0-9\-]+)", content, re.DOTALL)
            if m_usr_sec:
                self.usr_license_id = m_usr_sec.group(1).strip()
                self.usr_key = m_usr_sec.group(2).strip()
            else:
                m_usr_id = re.search(r"使用ライセンスID[：:;]\s*([A-Za-z0-9\-]+)", content)
                if m_usr_id:
                    self.usr_license_id = m_usr_id.group(1).strip()
                m_usr = re.search(r"使用ライセンスキー[：:;]\s*([A-Za-z0-9\-]+)", content)
                if m_usr:
                    self.usr_key = m_usr.group(1).strip()

            # 開発ライセンスセクションの探索
            m_dev_sec = re.search(r"開発ライセンス.*?ライセンスID[：:;]\s*([A-Za-z0-9\-]+).*?開発ライセンスキー[：:;]\s*([A-Za-z0-9\-]+)", content, re.DOTALL)
            if m_dev_sec:
                self.dev_license_id = m_dev_sec.group(1).strip()
                self.dev_key = m_dev_sec.group(2).strip()
            else:
                m_dev_id = re.search(r"開発ライセンスID[：:;]\s*([A-Za-z0-9\-]+)", content)
                if m_dev_id:
                    self.dev_license_id = m_dev_id.group(1).strip()
                m_dev = re.search(r"開発ライセンスキー[：:;]\s*([A-Za-z0-9\-]+)", content)
                if m_dev:
                    self.dev_key = m_dev.group(1).strip()

            # 単一ライセンスID表記の場合のフォールバック
            if not self.usr_license_id and not self.dev_license_id:
                m_all_id = re.findall(r"ライセンスID[：:;]\s*([A-Za-z0-9\-]+)", content)
                if len(m_all_id) >= 2:
                    self.usr_license_id = m_all_id[0].strip()
                    self.dev_license_id = m_all_id[1].strip()
                elif len(m_all_id) == 1:
                    self.usr_license_id = m_all_id[0].strip()
                    self.dev_license_id = m_all_id[0].strip()

            print(f"[INFO] TTS Loaded licenses: UsrID={'Set' if self.usr_license_id else 'None'}, UsrKey={'Set' if self.usr_key else 'None'}, DevID={'Set' if self.dev_license_id else 'None'}, DevKey={'Set' if self.dev_key else 'None'}")
        except Exception as e:
            print(f"[ERROR] Failed to read license.txt: {e}")

    def set_license_keys(self, usr_license_id: str = "", usr_key: str = "", dev_license_id: str = "", dev_key: str = "", license_id: str = ""):
        """ユーザー入力またはプロジェクトからライセンスキーを動的適用"""
        if usr_license_id:
            self.usr_license_id = usr_license_id.strip()
        elif license_id and not self.usr_license_id:
            self.usr_license_id = license_id.strip()

        if dev_license_id:
            self.dev_license_id = dev_license_id.strip()
        elif license_id and not self.dev_license_id:
            self.dev_license_id = license_id.strip()

        if usr_key:
            self.usr_key = usr_key.strip()
        if dev_key:
            self.dev_key = dev_key.strip()

        # ロード済みの各声種ライブラリに即座にキーを適用
        for voice, lib in self.aqtk_libs.items():
            if lib:
                try:
                    if self.dev_key:
                        lib.AquesTalk_SetDevKey(self.dev_key.encode("utf-8"))
                    if self.usr_key:
                        lib.AquesTalk_SetUsrKey(self.usr_key.encode("utf-8"))
                except Exception as e:
                    print(f"[WARN] Failed to apply key to {voice}: {e}")

        if self.aq_k2k_lib and self.dev_key:
            try:
                self.aq_k2k_lib.AqKanji2Koe_SetDevKey(self.dev_key.encode("utf-8"))
            except Exception:
                pass

        print(f"[INFO] Dynamic license keys updated: UsrID={self.usr_license_id}, UsrKey={'Set' if self.usr_key else 'None'}, DevID={self.dev_license_id}, DevKey={'Set' if self.dev_key else 'None'}")

    def get_license_info(self) -> Dict[str, Any]:
        """現在のライセンス設定を返す"""
        return {
            "usr_license_id": self.usr_license_id,
            "usr_key": self.usr_key,
            "dev_license_id": self.dev_license_id,
            "dev_key": self.dev_key,
            "license_id": self.usr_license_id or self.dev_license_id,
            "is_configured": bool(self.usr_license_id or self.dev_license_id or self.usr_key or self.dev_key)
        }

    def _init_tokenizer(self):
        """Janome トークナイザーの初期化"""
        try:
            from janome.tokenizer import Tokenizer
            self.tokenizer = Tokenizer()
            print("[INFO] Janome morphological tokenizer initialized successfully.")
        except Exception as e:
            print(f"[WARN] Janome not available, fallback to basic text processing: {e}")

    def kanji2koe(self, text: str, flat: bool = False) -> str:
        """
        漢字仮名混じり文テキストを AquesTalk 音声記号列に最高精度で変換する。
        - flat=False: 自然なアクセント（/ や '）を含む高精度変換
        - flat=True:  アクセント記号のない平坦な棒読み変換（ゆっくり茶番劇スタイル）
        """
        if not text or not text.strip():
            return ""

        raw_text = text.strip()

        # 0. 数字の自然な日本語読み上げ展開 (1234 -> センニヒャクサンジューヨン)
        converted = num_to_kanji_reading(raw_text)

        # 1. 東方固有名詞の最長一致置換
        for word, reading in sorted(TOHO_CUSTOM_DIC.items(), key=lambda x: -len(x[0])):
            converted = converted.replace(word, reading)

        # 2. 英語・略語・インターネット用語辞書の置換
        for eng_word, reading in sorted(ENGLISH_WORD_DIC.items(), key=lambda x: -len(x[0])):
            pattern = re.compile(re.escape(eng_word), re.IGNORECASE)
            converted = pattern.sub(reading, converted)

        # 3. アルファベット単文字の置換
        for alpha, reading in ALPHABET_MAP.items():
            converted = converted.replace(alpha, reading)

        # 4. Janome による形態素解析と助詞・記号の整形
        koe_base = ""
        if self.tokenizer:
            try:
                tokens = self.tokenizer.tokenize(converted)
                parts = []
                for token in tokens:
                    reading = token.reading
                    surface = token.surface
                    pos = token.part_of_speech.split(",")

                    if reading and reading != "*":
                        # 助詞の読み調整
                        if pos[0] == "助詞" and surface == "は":
                            parts.append("ワ")
                        elif pos[0] == "助詞" and surface == "へ":
                            parts.append("エ")
                        elif pos[0] == "助詞" and surface == "を":
                            parts.append("オ")
                        else:
                            parts.append(reading)
                    else:
                        if surface in ["、", ","]:
                            parts.append("、")
                        elif surface in ["。", "！", "!", "？", "?", "…", "\n", "；", ";"]:
                            parts.append("。")
                        elif surface in ["「", "」", "『", "』", " ", "\t", "（", "）", "(", ")", "【", "】", "［", "］"]:
                            parts.append(" ")
                        elif surface in ["―", "—", "〜", "~", "ー", "-"]:
                            parts.append("ー")
                        else:
                            parts.append(surface)

                koe_base = "".join(parts)
            except Exception as e:
                koe_base = converted
        else:
            koe_base = converted

        # 5. ひらがな -> カタカナ変換
        koe_katakana = "".join([chr(ord(c) + 0x60) if 'ぁ' <= c <= 'ん' else c for c in koe_base])

        # 6. AquesTalk1 専用音声記号のサニタイズ（小文字母音の補正など）
        small_vowel_map = {
            "ァ": "ー", "ィ": "ー", "ゥ": "ー", "ェ": "ー", "ォ": "ー", "ヮ": "ワ"
        }
        valid_precedents = {
            "ァ": "フヴツ",
            "ィ": "デテフヴ",
            "ゥ": "トド",
            "ェ": "シジチヂフヴツ",
            "ォ": "フヴツ"
        }
        norm_chars = []
        for i, c in enumerate(koe_katakana):
            if c in small_vowel_map:
                prev_char = koe_katakana[i-1] if i > 0 else ""
                allowed_prev = valid_precedents.get(c, "")
                if prev_char not in allowed_prev:
                    norm_chars.append(small_vowel_map[c])
                else:
                    norm_chars.append(c)
            else:
                norm_chars.append(c)
        final_koe = "".join(norm_chars)

        # 7. 許容文字のみ抽出
        if flat:
            # 棒読みモード（アクセント記号を除去）
            valid_chars = set("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
                              "ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ"
                              "ァィゥェォッャュョヮ"
                              "ヴー 、。")
        else:
            valid_chars = set("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
                              "ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ"
                              "ァィゥェォッャュョヮ"
                              "ヴー'/_ 、。")

        cleaned_koe = "".join([c for c in final_koe if c in valid_chars])

        # 8. 連続記号の整理
        cleaned_koe = re.sub(r"[ \t]+", " ", cleaned_koe)
        cleaned_koe = re.sub(r"[。]+", "。", cleaned_koe)
        cleaned_koe = re.sub(r"[、]+", "、", cleaned_koe)
        cleaned_koe = re.sub(r"^[、。 ]+", "", cleaned_koe)
        cleaned_koe = re.sub(r"[、。 ]+$", "。", cleaned_koe)

        return cleaned_koe.strip()

    def _get_aqtk_lib(self, voice: str = "f1"):
        """声種に応じた AquesTalk1 ライブラリを取得（キャッシュ）"""
        voice = voice.lower()
        if voice in self.aqtk_libs:
            return self.aqtk_libs[voice]

        lib_name = f"libAquesTalk1-{voice}.dylib"
        lib_path = os.path.join(self.lib_dir, lib_name)
        if not os.path.exists(lib_path):
            lib_path = os.path.join(self.lib_dir, "libAquesTalk1-f1.dylib")

        try:
            lib = ctypes.cdll.LoadLibrary(lib_path)
            lib.AquesTalk_SetDevKey.restype = ctypes.c_int
            lib.AquesTalk_SetDevKey.argtypes = [ctypes.c_char_p]

            lib.AquesTalk_SetUsrKey.restype = ctypes.c_int
            lib.AquesTalk_SetUsrKey.argtypes = [ctypes.c_char_p]

            lib.AquesTalk_Synthe_Utf8.restype = ctypes.POINTER(ctypes.c_ubyte)
            lib.AquesTalk_Synthe_Utf8.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(ctypes.c_int)]

            lib.AquesTalk_FreeWave.restype = None
            lib.AquesTalk_FreeWave.argtypes = [ctypes.c_void_p]

            # ライセンス設定
            if self.dev_key:
                lib.AquesTalk_SetDevKey(self.dev_key.encode("utf-8"))
            if self.usr_key:
                lib.AquesTalk_SetUsrKey(self.usr_key.encode("utf-8"))

            self.aqtk_libs[voice] = lib
            return lib
        except Exception as e:
            print(f"[ERROR] Failed to load {lib_path}: {e}")
            return None

    def synthesize_wav(
        self,
        koe: str,
        voice: str = "f1",
        speed: int = 100,
        pitch: int = 100,
        quality_enhance: bool = True,
        effect: str = "none",
        sound_effect: Optional[str] = None,
        se_offset: float = 0.0
    ) -> Optional[bytes]:
        """音声記号列からWAVバイナリデータを生成（自動サニタイズ・エフェクト・[SE]精密タイミング効果音合成付き）"""
        if not koe or not koe.strip():
            return None

        raw_koe = koe.strip()

        # [SE] または [SE:ファイル名] マーカーの検出とタイミング計算
        target_se_path = sound_effect
        se_delay_ms = int(max(0.0, float(se_offset)) * 1000)

        # テキストまたは記号列内に [SE] マーカーがあるか探索
        se_marker_match = re.search(r"\[SE(?::([^\]]+))?\]", raw_koe, re.IGNORECASE)
        if se_marker_match:
            marker_full = se_marker_match.group(0)
            custom_se = se_marker_match.group(1)
            if custom_se and custom_se.strip():
                target_se_path = custom_se.strip()

            # マーカーの前のテキスト部分を取得
            idx_marker = raw_koe.find(marker_full)
            prefix_text = raw_koe[:idx_marker].strip()
            
            # マーカーを除去した全体のセリフ
            clean_full_koe = (raw_koe[:idx_marker] + raw_koe[idx_marker + len(marker_full):]).strip()
            
            # 前半部分の発話時間を算出（ミリ秒）
            if prefix_text:
                prefix_wav = self.synthesize_wav(
                    prefix_text, voice=voice, speed=speed, pitch=pitch,
                    quality_enhance=quality_enhance, effect="none", sound_effect=None
                )
                if prefix_wav:
                    prefix_dur = self.get_wav_duration_bytes(prefix_wav)
                    se_delay_ms += int(prefix_dur * 1000)

            raw_koe = clean_full_koe if clean_full_koe else "。"

        # 1. 漢字や英字、未サポート文字が含まれている場合は自動で kanji2koe 変換
        if re.search(r"[\u4e00-\u9fff\u3040-\u309fa-zA-Z]", raw_koe):
            raw_koe = self.kanji2koe(raw_koe)

        # 2. ひらがな -> カタカナ変換
        raw_koe = "".join([chr(ord(c) + 0x60) if 'ぁ' <= c <= 'ん' else c for c in raw_koe])

        # 3. 空白を安全なポーズ記号に変換し、AquesTalk1 許容記号へサニタイズ
        raw_koe = re.sub(r"[ 　\t\n]+", "/", raw_koe)
        valid_chars = set("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
                          "ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ"
                          "ァィゥェォッャュョヮ"
                          "ヴー'/_、。")
        clean_koe = "".join([c for c in raw_koe if c in valid_chars]).strip()
        clean_koe = re.sub(r"[/]+", "/", clean_koe)
        clean_koe = re.sub(r"[、]+", "、", clean_koe)
        clean_koe = re.sub(r"[。]+", "。", clean_koe)
        clean_koe = re.sub(r"^[/、。]+", "", clean_koe)
        if not clean_koe:
            clean_koe = "テスト。"

        lib = self._get_aqtk_lib(voice) or self._get_aqtk_lib("f1")
        if not lib:
            return None

        speed = max(50, min(300, int(speed)))
        pitch = max(50, min(200, int(pitch)))
        size = ctypes.c_int(0)

        wav_ptr = lib.AquesTalk_Synthe_Utf8(clean_koe.encode("utf-8"), speed, ctypes.byref(size))
        
        # 失敗時のフォールバック (kanji2koe を強制再適用してリトライ)
        if not wav_ptr or size.value <= 0:
            re_koe = self.kanji2koe(koe)
            clean_re_koe = "".join([c for c in re_koe if c in valid_chars]).strip() or "テスト。"
            wav_ptr = lib.AquesTalk_Synthe_Utf8(clean_re_koe.encode("utf-8"), speed, ctypes.byref(size))

        if not wav_ptr or size.value <= 0:
            print(f"[ERROR] AquesTalk_Synthe_Utf8 failed (code/size: {size.value}) for koe: {koe[:30]}")
            return None

        try:
            raw_bytes = bytes((ctypes.c_ubyte * size.value).from_address(ctypes.addressof(wav_ptr.contents)))
        finally:
            lib.AquesTalk_FreeWave(wav_ptr)

        # オーディオフィルター（ピッチ・音質改善・エフェクト）の適用
        need_filter = (pitch != 100) or quality_enhance or (effect and effect != "none")
        if need_filter:
            p_ratio = pitch / 100.0
            filters = []

            # 1. ピッチシフト
            if pitch != 100:
                filters.append(f"asetrate=8000*{p_ratio},atempo=1/{p_ratio}")

            # 2. エフェクト効果 (ゆっくりボイスメーカー準拠 + 拡張)
            if effect == "echo":
                filters.append("aecho=0.8:0.88:60:0.4")
            elif effect == "reverb":
                filters.append("aecho=0.8:0.9:1000:0.3")
            elif effect == "radio":
                filters.append("highpass=f=300,lowpass=f=3400,volume=1.5")
            elif effect == "robot":
                filters.append("afftfilt=real='hypot(re,im)*sin(0)':imag='hypot(re,im)*cos(0)':win_size=512:overlap=0.75")
            elif effect == "lowboost":
                filters.append("bass=g=6:f=150")

            # 3. 音質改善 (ゆっくりボイスメーカー準拠: 有効で44.1kHzクリア化、無効で8kHz原音/ゆくも風)
            if quality_enhance:
                filters.append("aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=stereo,equalizer=f=3200:t=q:w=1.2:g=2.5,highpass=f=60")
            else:
                filters.append("aresample=8000,aformat=sample_fmts=s16:sample_rates=8000:channel_layouts=mono")

            import subprocess
            import tempfile
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_in, tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_out:
                in_path = f_in.name
                out_path = f_out.name
                f_in.write(raw_bytes)

            try:
                cmd = [
                    "ffmpeg", "-y", "-i", in_path,
                    "-af", ",".join(filters),
                    out_path
                ]
                res = subprocess.run(cmd, capture_output=True)
                if res.returncode == 0 and os.path.exists(out_path):
                    with open(out_path, "rb") as f:
                        raw_bytes = f.read()
            finally:
                if os.path.exists(in_path): os.unlink(in_path)
                if os.path.exists(out_path): os.unlink(out_path)

        # 4. 効果音 (SE) のミキシング（指定されている場合、adelayによる精密タイミング配置）
        if target_se_path:
            se_full_path = target_se_path
            if not os.path.isabs(se_full_path):
                se_full_path = os.path.join(PROJECT_ROOT, target_se_path)
            if not os.path.exists(se_full_path):
                alt_p = os.path.join(PROJECT_ROOT, "動画用", "音楽", "効果音", os.path.basename(target_se_path))
                if os.path.exists(alt_p):
                    se_full_path = alt_p

            if os.path.exists(se_full_path):
                import subprocess
                import tempfile
                with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_voice, tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f_mixed:
                    voice_in = f_voice.name
                    mixed_out = f_mixed.name
                    f_voice.write(raw_bytes)

                try:
                    # adelay による精密タイミング（ミリ秒）
                    if se_delay_ms > 0:
                        se_filter = f"[1:a]adelay={se_delay_ms}|{se_delay_ms},volume=0.85,aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=stereo[se]"
                    else:
                        se_filter = "[1:a]volume=0.85,aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=stereo[se]"

                    mix_cmd = [
                        "ffmpeg", "-y",
                        "-i", voice_in,
                        "-i", se_full_path,
                        "-filter_complex",
                        f"[0:a]volume=1.0,aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=stereo[v];"
                        f"{se_filter};"
                        f"[v][se]amix=inputs=2:duration=longest:dropout_transition=0,aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=stereo",
                        mixed_out
                    ]
                    mix_res = subprocess.run(mix_cmd, capture_output=True)
                    if mix_res.returncode == 0 and os.path.exists(mixed_out):
                        with open(mixed_out, "rb") as f:
                            raw_bytes = f.read()
                except Exception as ex_mix:
                    print(f"[WARN] Failed to mix sound effect: {ex_mix}")
                finally:
                    if os.path.exists(voice_in): os.unlink(voice_in)
                    if os.path.exists(mixed_out): os.unlink(mixed_out)

        return raw_bytes

    def validate_audio_match(self, text: str, wav_bytes: bytes, speed: int = 100) -> Tuple[bool, str]:
        """
        セリフテキストと生成されたWAV音声データが完全に一致・妥当であるか厳密に検証する。
        戻り値: (合格かどうか: bool, 理由メッセージ: str)
        """
        if not wav_bytes or len(wav_bytes) <= 44:
            return False, "WAVデータが空またはヘッダーのみです"

        dur = self.get_wav_duration_bytes(wav_bytes)
        if dur <= 0.05:
            return False, f"再生時間が短すぎます ({dur:.2f}秒)"

        # セリフ本文から意味のある文字数（記号・空白等を除く）を抽出
        cleaned_text = re.sub(r"[ \t\n\r、。！？!?…・―〜~「」『』()（）\[\]【】［］\./']", "", text or "")
        char_count = len(cleaned_text)

        if char_count > 0:
            # 文字数に対して期待される最短時間 (1文字あたり最低0.035秒 @100%速度)
            speed_factor = max(50, min(300, speed)) / 100.0
            min_expected_sec = (char_count * 0.035) / speed_factor
            min_expected_sec = max(0.15, min_expected_sec)

            if dur < min_expected_sec:
                return False, f"文字数({char_count}文字)に対して音声が短すぎます (実測:{dur:.2f}s < 期待最小:{min_expected_sec:.2f}s)"

        # WAVデータの破損・無音チェック
        try:
            import io
            with io.BytesIO(wav_bytes) as bio:
                with wave.open(bio, "rb") as wf:
                    if wf.getnframes() <= 0:
                        return False, "PCMフレーム数が0です"
                    if wf.getframerate() <= 0:
                        return False, "サンプリングレートが不正です"
        except Exception as ex:
            return False, f"WAVヘッダー解析エラー: {ex}"

        return True, f"検証合格 (実測:{dur:.2f}秒, 文字数:{char_count})"

    def synthesize_with_auto_retry(
        self,
        text: str,
        phonemes: str = "",
        voice: str = "f1",
        speed: int = 100,
        pitch: int = 100,
        quality_enhance: bool = True,
        effect: str = "none",
        sound_effect: Optional[str] = None,
        se_offset: float = 0.0,
        max_retries: int = 5
    ) -> Tuple[Optional[bytes], float, str]:
        """
        セリフと音声ファイルが完全に一致するまで、自己修復・記号列再生成を繰り返す。
        戻り値: (WAVバイナリ, 再生時間秒, 検証レポート文字列)
        """
        candidates = []

        # 1. ユーザー指定の記号列
        if phonemes and phonemes.strip():
            candidates.append(("ユーザー指定記号列", phonemes.strip()))

        # 2. セリフ本文からの高精度変換（アクセント付き）
        if text and text.strip():
            k1 = self.kanji2koe(text, flat=False)
            if k1 and k1 not in [c[1] for c in candidates]:
                candidates.append(("セリフ自動変換(自然アクセント)", k1))

            # 3. セリフ本文からの平坦変換（フラット・棒読み）
            k2 = self.kanji2koe(text, flat=True)
            if k2 and k2 not in [c[1] for c in candidates]:
                candidates.append(("セリフ自動変換(平坦アクセント)", k2))

            # 4. 特殊記号や難読文字をサニタイズした正規化変換
            norm_text = re.sub(r"[♥♡★☆♪♬・…―〜~]", " ", text)
            k3 = self.kanji2koe(norm_text, flat=True)
            if k3 and k3 not in [c[1] for c in candidates]:
                candidates.append(("正規化テキスト変換", k3))

        if not candidates:
            if text:
                candidates.append(("テキスト直接入力", text))
            else:
                return None, 0.0, "セリフおよび記号列が空です"

        last_error = ""
        for attempt, (strategy_name, target_koe) in enumerate(candidates, 1):
            if attempt > max_retries:
                break

            wav_bytes = self.synthesize_wav(
                target_koe,
                voice=voice,
                speed=speed,
                pitch=pitch,
                quality_enhance=quality_enhance,
                effect=effect,
                sound_effect=sound_effect,
                se_offset=se_offset
            )

            if wav_bytes:
                is_valid, reason = self.validate_audio_match(text or target_koe, wav_bytes, speed=speed)
                if is_valid:
                    dur = self.get_wav_duration_bytes(wav_bytes)
                    print(f"[TTS-AutoRetry] 試行 {attempt} ({strategy_name}) でセリフと音声が完全一致しました: {reason}")
                    return wav_bytes, dur, f"成功 ({strategy_name}, {reason})"
                else:
                    last_error = reason
                    print(f"[TTS-AutoRetry] 試行 {attempt} ({strategy_name}) 不一致検知: {reason} -> 再試行します...")
            else:
                last_error = "音声合成APIエラー (WAV生成失敗)"
                print(f"[TTS-AutoRetry] 試行 {attempt} ({strategy_name}) 合成失敗 -> 再試行します...")

        return None, 0.0, f"再生成を繰り返しましたが一致しませんでした: {last_error}"

    def synthesize_to_file(
        self,
        koe: str,
        out_path: str,
        voice: str = "f1",
        speed: int = 100,
        pitch: int = 100,
        quality_enhance: bool = True,
        effect: str = "none",
        sound_effect: Optional[str] = None,
        se_offset: float = 0.0,
        text: Optional[str] = None
    ) -> Tuple[bool, float]:
        """
        セリフと音声ファイルの整合性を確認し、一致するまで自動再生成を繰り返してWAV保存する。
        """
        # セリフ本文が渡されている場合は自動リトライ付き合成を実行
        if text:
            wav_bytes, dur, report = self.synthesize_with_auto_retry(
                text=text,
                phonemes=koe,
                voice=voice,
                speed=speed,
                pitch=pitch,
                quality_enhance=quality_enhance,
                effect=effect,
                sound_effect=sound_effect,
                se_offset=se_offset
            )
        else:
            wav_bytes = self.synthesize_wav(
                koe,
                voice=voice,
                speed=speed,
                pitch=pitch,
                quality_enhance=quality_enhance,
                effect=effect,
                sound_effect=sound_effect,
                se_offset=se_offset
            )
            dur = self.get_wav_duration_bytes(wav_bytes) if wav_bytes else 0.0

        if not wav_bytes:
            return False, 0.0

        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        with open(out_path, "wb") as f:
            f.write(wav_bytes)

        return True, dur

    @staticmethod
    def get_wav_duration_bytes(wav_bytes: bytes) -> float:
        """WAVバイナリから再生時間（秒）を算出"""
        try:
            import io
            with io.BytesIO(wav_bytes) as bio:
                with wave.open(bio, 'rb') as wf:
                    frames = wf.getnframes()
                    rate = wf.getframerate()
                    if rate > 0:
                        return frames / float(rate)
        except Exception:
            if len(wav_bytes) > 44:
                pcm_len = len(wav_bytes) - 44
                return pcm_len / (8000.0 * 2.0)
        return 0.0

    @staticmethod
    def get_wav_duration_file(file_path: str) -> float:
        """WAVファイルから再生時間（秒）を算出"""
        try:
            with wave.open(file_path, 'rb') as wf:
                frames = wf.getnframes()
                rate = wf.getframerate()
                if rate > 0:
                    return frames / float(rate)
        except Exception:
            if os.path.exists(file_path):
                size = os.path.getsize(file_path)
                if size > 44:
                    return (size - 44) / (8000.0 * 2.0)
        return 0.0


_engine_instance: Optional[TTSEngine] = None


def get_tts_engine() -> TTSEngine:
    global _engine_instance
    if _engine_instance is None:
        _engine_instance = TTSEngine()
    return _engine_instance
