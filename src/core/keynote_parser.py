"""
Keynote ファイル解析 & 超高精度キャラクター自動判定モジュール
- AppleScript を使用して Keynote ファイルからスライド・テキスト・発表者ノート・立ち絵画像を抽出
- 話者プレフィックス（【霊夢】、魔理沙:、操夢「 等）の自動抽出 & セリフ本文クレンジング
- 口調・一人称・二人称・語尾・呼びかけ・東方固有キーワードによる多層スコアリング判定
- ナレーション・地の文はすべて主人公「操夢」（imd1 / 速度100 / 音程115）に一本化
"""

import os
import re
import json
import subprocess
from typing import List, Dict, Any, Optional, Tuple
from .path_utils import get_series_dir, get_media_dir
from .character_db import CHARACTERS, CHARACTER_ALIASES, get_character_info
from .tts_engine import get_tts_engine
from .corpus_learner import get_corpus_engine

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_KEYNOTE_DIR = get_series_dir("")
DEFAULT_VIDEO_DIR = os.path.join(PROJECT_ROOT, "動画用")


def get_keynote_app_name() -> str:
    """macOS環境で利用可能なKeynoteアプリケーション名を取得"""
    candidates = [
        "/Applications/Keynote Creator Studio.app",
        "/Applications/Keynote.app"
    ]
    for cand in candidates:
        if os.path.exists(cand):
            return os.path.splitext(os.path.basename(cand))[0]
    return "Keynote"



class VideoAssetsLibrary:
    """
    プロジェクト内の「動画用」フォルダ（動画用/）を参照・インデックス化し、
    スライド内の全オブジェクト（背景、キャラクター、テロップ枠、手作り素材、音楽素材等）の
    高精度な分類とアニメーション判定に活用するアセットマネージャー。
    """
    _instance = None

    def __new__(cls, root_dir: Optional[str] = None):
        if cls._instance is None:
            cls._instance = super(VideoAssetsLibrary, cls).__new__(cls)
            cls._instance._init_library(root_dir)
        return cls._instance

    def _init_library(self, root_dir: Optional[str] = None):
        self.root_dir = root_dir or PROJECT_ROOT
        self.video_dir = os.path.join(self.root_dir, "動画用")
        self.backgrounds = {}       # filename_lower -> full_path
        self.characters = {}        # char_name -> list of full_paths
        self.character_files = {}   # filename_lower -> (char_name, full_path)
        self.materials = {}         # filename_lower -> full_path
        self.telop_frames = {}      # filename_lower -> full_path
        self.audio_files = {}       # filename_lower -> full_path
        self._scanned = False
        self.scan_library()

    def scan_library(self, force: bool = False):
        """動画用フォルダ配下の全素材を走査してインデックス化"""
        if self._scanned and not force:
            return

        self.backgrounds.clear()
        self.characters.clear()
        self.character_files.clear()
        self.materials.clear()
        self.telop_frames.clear()
        self.audio_files.clear()

        if not os.path.exists(self.video_dir):
            self._scanned = True
            return

        valid_img_exts = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
        valid_audio_exts = {".wav", ".mp3", ".m4a", ".aac", ".aiff", ".ogg"}

        # 1. 背景素材の走査 (動画用/背景)
        bg_dir = os.path.join(self.video_dir, "背景")
        if os.path.exists(bg_dir):
            for root, _, files in os.walk(bg_dir):
                for f in files:
                    if f.startswith(".") or f.startswith("._"):
                        continue
                    ext = os.path.splitext(f)[1].lower()
                    if ext in valid_img_exts:
                        full_p = os.path.join(root, f)
                        self.backgrounds[f.lower()] = full_p
                        self.backgrounds[os.path.splitext(f)[0].lower()] = full_p

        # 2. キャラクター探索用キーワードリスト
        known_char_keys = list(CHARACTERS.keys()) + list(CHARACTER_ALIASES.keys()) + ["男", "女", "主人公"]

        # 動画用フォルダ配下の全ディレクトリを走査（キャラクター、手作り素材/psdtool、手作り素材/ゆっくりボイスメーカー等）
        for root, dirs, files in os.walk(self.video_dir):
            rel = os.path.relpath(root, self.video_dir)
            if rel.startswith("背景") or rel.startswith("音楽"):
                continue

            path_parts = rel.split(os.sep) if rel != "." else []

            # フォルダ階層からキャラ名を推定
            inferred_char = ""
            for p in reversed(path_parts):
                for cname in known_char_keys:
                    if cname in p:
                        inferred_char = CHARACTER_ALIASES.get(cname, cname)
                        if inferred_char in ["男", "女", "主人公"]:
                            inferred_char = "操夢"
                        break
                if inferred_char:
                    break

            for f in files:
                if f.startswith(".") or f.startswith("._"):
                    continue
                ext = os.path.splitext(f)[1].lower()
                full_p = os.path.join(root, f)
                f_lower = f.lower()
                f_stem = os.path.splitext(f)[0].lower()

                if ext in valid_img_exts:
                    # ファイル名またはフォルダ階層からキャラ名を特定
                    char_for_file = inferred_char
                    if not char_for_file:
                        for cname in known_char_keys:
                            if cname.lower() in f_lower:
                                char_for_file = CHARACTER_ALIASES.get(cname, cname)
                                if char_for_file in ["男", "女", "主人公"]:
                                    char_for_file = "操夢"
                                break

                    # テロップ枠・帯のチェック
                    is_telop = any(kw in f_lower for kw in ["テロップ", "枠", "frame", "telop", "帯", "ざぶとん", "座布団"])
                    if is_telop:
                        self.telop_frames[f_lower] = full_p
                        self.telop_frames[f_stem] = full_p
                    elif char_for_file:
                        if char_for_file not in self.characters:
                            self.characters[char_for_file] = []
                        self.characters[char_for_file].append(full_p)
                        self.character_files[f_lower] = (char_for_file, full_p)
                        self.character_files[f_stem] = (char_for_file, full_p)
                    else:
                        self.materials[f_lower] = full_p
                        self.materials[f_stem] = full_p

                elif ext in valid_audio_exts:
                    self.audio_files[f_lower] = full_p
                    self.audio_files[f_stem] = full_p

        # 3. 音楽フォルダの走査 (動画用/音楽)
        mus_dir = os.path.join(self.video_dir, "音楽")
        if os.path.exists(mus_dir):
            for root, _, files in os.walk(mus_dir):
                for f in files:
                    if f.startswith(".") or f.startswith("._"):
                        continue
                    ext = os.path.splitext(f)[1].lower()
                    if ext in valid_audio_exts:
                        full_p = os.path.join(root, f)
                        self.audio_files[f.lower()] = full_p
                        self.audio_files[os.path.splitext(f)[0].lower()] = full_p

        self._scanned = True

    def classify_image(self, file_path_or_name: str) -> Dict[str, Any]:
        """
        画像ファイル名またはパスから「動画用」フォルダのインデックスを参照して
        オブジェクト種別（background / character / telop_frame / material）と詳細情報を判定
        """
        if not self._scanned:
            self.scan_library()

        fname = os.path.basename(file_path_or_name)
        f_lower = fname.lower()
        f_stem = os.path.splitext(fname)[0].lower()

        # 1. キャラクター判定（立ち絵素材最優先）
        if f_lower in self.character_files or f_stem in self.character_files:
            cinfo = self.character_files.get(f_lower) or self.character_files.get(f_stem)
            return {"type": "character", "matched_path": cinfo[1], "name": fname, "character": cinfo[0]}

        for char_name, profile in CHARACTER_PROFILES.items():
            for alias in profile.get("aliases", [char_name]):
                if alias.lower() in f_lower:
                    norm = CHARACTER_ALIASES.get(char_name, char_name)
                    return {"type": "character", "matched_path": None, "name": fname, "character": norm}

        # 2. テロップ枠 / 手作り素材判定
        if f_lower in self.telop_frames or f_stem in self.telop_frames:
            full_p = self.telop_frames.get(f_lower) or self.telop_frames.get(f_stem)
            return {"type": "telop_frame", "matched_path": full_p, "name": fname, "character": None}

        if any(t_kw in f_lower for t_kw in ["テロップ", "枠", "frame", "telop", "帯"]):
            return {"type": "telop_frame", "matched_path": None, "name": fname, "character": None}

        # 3. 背景判定
        if f_lower in self.backgrounds or f_stem in self.backgrounds:
            full_p = self.backgrounds.get(f_lower) or self.backgrounds.get(f_stem)
            return {"type": "background", "matched_path": full_p, "name": fname, "character": None}

        if any(bg_kw in f_lower for bg_kw in ["背景", "部屋", "リビング", "窓際", "ベッド", "bg", "background", "nc1", "nc2", "nc3", "nc4", "nc5"]):
            if not any(c_kw in f_lower for c_kw in ["霊夢", "魔理沙", "フラン", "レミリア", "チルノ", "妖夢", "紫", "キャラ"]):
                return {"type": "background", "matched_path": None, "name": fname, "character": None}

        # 4. 手作り素材判定
        if f_lower in self.materials or f_stem in self.materials:
            full_p = self.materials.get(f_lower) or self.materials.get(f_stem)
            return {"type": "material", "matched_path": full_p, "name": fname, "character": None}

        return {"type": "general", "matched_path": None, "name": fname, "character": None}


def get_video_assets_library() -> VideoAssetsLibrary:
    return VideoAssetsLibrary()



def list_keynote_files(keynote_dir: str = DEFAULT_KEYNOTE_DIR) -> List[Dict[str, Any]]:
    """交換夫婦フォルダ内のKeynoteファイル一覧を取得（話数順ソート）"""
    if not os.path.exists(keynote_dir):
        return []

    files = []
    for fname in os.listdir(keynote_dir):
        if fname.endswith(".key") and not fname.startswith("._") and not fname.startswith("."):
            full_path = os.path.join(keynote_dir, fname)
            size = os.path.getsize(full_path)
            
            # 話数抽出（ソート用）
            ep_num = 999.0
            if "プロローグ" in fname or "プロローグ" in fname:
                ep_num = 0.0
            else:
                m = re.search(r"(\d+(?:\.\d+)?)話", fname)
                if m:
                    try:
                        ep_num = float(m.group(1))
                    except ValueError:
                        pass
                else:
                    # 全角数字対応
                    m_z = re.search(r"([０-９]+(?:\.[０-９]+)?)話", fname)
                    if m_z:
                        trans = str.maketrans('０１２３４５６７８９', '0123456789')
                        ep_num = float(m_z.group(1).translate(trans))

            files.append({
                "filename": fname,
                "path": full_path,
                "size_bytes": size,
                "episode_number": ep_num,
                "is_empty": (size == 0)
            })

    # 話数順でソート
    files.sort(key=lambda x: (x["episode_number"], x["filename"]))
    return files


# 各キャラクターの言語的特徴プロファイル（高精度スコアリング用）
CHARACTER_PROFILES = {
    "操夢": {
        "aliases": ["操夢", "そうむ", "主人公", "僕", "ソーム", "soumu", "somu"],
        "first_person": ["僕", "ぼく", "俺", "おれ", "操夢", "そうむ"],
        "second_person": ["君", "きみ", "あなた"],
        "sentence_endings": ["思いついたんです", "勝てるかな", "でした", "ました", "かもしれません", "かもしれない", "だろうか", "だった", "ですよね", "ですね", "しよう", "行こう", "と思う"],
        "keywords": ["西湖公園", "フランと", "交換", "僕とフラン", "計画", "作戦", "どう思う", "思いついた"],
        "is_monologue_default": True
    },
    "霊夢": {
        "aliases": ["霊夢", "れいむ", "博麗霊夢", "博麗", "巫女", "reimu", "hakurei"],
        "first_person": ["私", "わたし", "霊夢"],
        "second_person": ["あんた", "お前", "魔理沙", "操夢", "フラン"],
        "sentence_endings": ["わよ", "じゃない", "かしら", "のよ", "でしょ", "わね", "ことよ", "何よ", "なによ", "ちょうだい", "わよ！", "の？"],
        "keywords": ["博麗神社", "賽銭", "異変", "退治", "妖怪", "お茶", "何があったの", "どういうこと", "何よ", "結界", "陰陽玉"],
    },
    "魔理沙": {
        "aliases": ["魔理沙", "まりさ", "霧雨魔理沙", "霧雨", "魔法使い", "marisa", "kirisame"],
        "first_person": ["私", "あたい", "オレ", "魔理沙"],
        "second_person": ["お前", "あんた", "霊夢", "操夢"],
        "sentence_endings": ["だぜ", "ぜ", "なんだぜ", "ぜ！", "ぜ？", "のか？", "だな", "だろ", "ぜー", "ぜっ", "んだな", "ぜい"],
        "keywords": ["八卦炉", "マスタースパーク", "弾幕", "きのこ", "キノコ", "実験", "借りていくぜ", "だぜ", "だぜ！"],
    },
    "フラン": {
        "aliases": ["フラン", "ふらん", "フランドール", "フランドール・スカーレット", "妹様", "flan", "flandre"],
        "first_person": ["私", "フラン", "わたし"],
        "second_person": ["お姉様", "おねえさま", "操夢", "霊夢", "魔理沙"],
        "sentence_endings": ["なの？", "遊ぼう", "壊しちゃう", "いい？", "ちょうだい", "もん", "かな？", "の！", "遊んで", "なの", "なの！"],
        "keywords": ["お姉様", "おねえさま", "地下室", "レーヴァテイン", "きゅっとしてドカーン", "壊す", "遊ぶ", "西湖公園", "遊ぼうよ", "フラン"],
    },
    "レミリア": {
        "aliases": ["レミリア", "れみりあ", "レミリア・スカーレット", "お嬢様", "吸血鬼", "remilia", "remi"],
        "first_person": ["私", "わたくし", "レミリア"],
        "second_person": ["あなた", "咲夜", "フラン", "霊夢"],
        "sentence_endings": ["かしら", "なさい", "わね", "いいわよ", "寝かせて", "ちょうだい", "わ", "のよ", "わね！", "かしら？"],
        "keywords": ["紅魔館", "運命", "カリスマ", "グングニル", "スカーレット", "咲夜、", "紅茶", "夜", "寝かせてもらう", "いいわよ"],
    },
    "さとり": {
        "aliases": ["さとり", "古明地さとり", "古明地", "地霊殿の主", "satori", "komeiji_satori"],
        "first_person": ["私", "さとり"],
        "second_person": ["あなた", "こいし", "お燐", "お空"],
        "sentence_endings": ["のね", "かしら", "でしょう", "わかるわ", "見えているわ", "のよ", "わ", "のよ？"],
        "keywords": ["心", "思考", "読める", "地霊殿", "サードアイ", "隠しても", "無駄よ", "考えていること", "さとり", "読めない"],
    },
    "こいし": {
        "aliases": ["こいし", "古明地こいし", "koishi", "komeiji_koishi"],
        "first_person": ["こいし", "私"],
        "second_person": ["お姉ちゃん", "さとりお姉ちゃん", "あなた"],
        "sentence_endings": ["だよ", "遊ぼう", "ねえねえ", "キャハハ", "ないよ", "もん", "のー", "よー", "だよ！", "遊ぼうよ"],
        "keywords": ["お姉ちゃん", "無意識", "サードアイ", "どこ行こう", "遊ぼうよ", "見えないでしょ", "こいし"],
    },
    "パチュリー": {
        "aliases": ["パチュリー", "ぱちゅりー", "パチェ", "パチュリー・ノーレッジ", "patchouli", "patchy"],
        "first_person": ["私", "パチェ"],
        "second_person": ["あなた", "魔理沙", "レミリア", "咲夜", "小悪魔"],
        "sentence_endings": ["よ", "だわ", "むきゅ", "むきゅー", "かしら", "のよ", "ね", "だわね"],
        "keywords": ["むきゅ", "むきゅー", "図書館", "大図書館", "本", "魔導書", "喘息", "魔法", "ヴワル"],
    },
    "咲夜": {
        "aliases": ["咲夜", "さくや", "十六夜咲夜", "十六夜", "メイド長", "sakuya", "izayoi"],
        "first_person": ["私", "わたくし"],
        "second_person": ["お嬢様", "レミリア様", "フラン様", "貴方"],
        "sentence_endings": ["でございます", "いたします", "でしょうか", "かしら", "ですね", "ます", "でございますね"],
        "keywords": ["お嬢様", "レミリア様", "時間", "ナイフ", "メイド", "掃除", "紅茶", "準備", "咲夜"],
    },
    "チルノ": {
        "aliases": ["チルノ", "ちるの", "氷の妖精", "cirno", "chirno"],
        "first_person": ["あたい", "私"],
        "second_person": ["あんた", "お前", "大ちゃん"],
        "sentence_endings": ["だもん", "だぞ", "バーカ", "最強だ", "よ！", "もんね", "だぜ", "もん！"],
        "keywords": ["あたい", "最強", "氷", "カエル", "一番", "天才", "チルノ"],
    },
    "妖夢": {
        "aliases": ["妖夢", "ようむ", "魂魄妖夢", "魂魄", "庭師", "youmu", "konpaku"],
        "first_person": ["私", "妖夢"],
        "second_person": ["幽々子様", "あなた"],
        "sentence_endings": ["みょん", "でございます", "です", "ます", "斬れないものはありません", "みょん！"],
        "keywords": ["みょん", "幽々子様", "白玉楼", "楼観剣", "白楼剣", "剣", "修行", "妖夢"],
    },
    "文": {
        "aliases": ["文", "あや", "射命丸文", "射命丸", "天狗", "aya", "shameimaru"],
        "first_person": ["私", "文", "あや"],
        "second_person": ["あなた", "皆さん"],
        "sentence_endings": ["です", "ですね", "ですよ", "でしょうか", "あやや", "あやや！"],
        "keywords": ["あやや", "新聞", "取材", "特ダネ", "文々。新聞", "天狗", "速報", "写真", "射命丸"],
    },
    "早苗": {
        "aliases": ["早苗", "さなえ", "東風谷早苗", "東風谷", "風祝", "sanae", "kochiya"],
        "first_person": ["私", "早苗"],
        "second_person": ["神奈子様", "諏訪子様", "霊夢さん", "魔理沙さん"],
        "sentence_endings": ["です", "ですね", "ですよ", "ます", "でした", "です！"],
        "keywords": ["奇跡", "現人神", "守矢神社", "神奈子様", "諏訪子様", "常識に囚われては", "早苗"],
    },
    "妹紅": {
        "aliases": ["妹紅", "もこう", "藤原妹紅", "藤原", "mokou", "moko"],
        "first_person": ["私", "俺", "妹紅"],
        "second_person": ["お前", "あんた", "輝夜", "慧音"],
        "sentence_endings": ["だろ", "さ", "ぜ", "のかよ", "じゃねえか", "んだよ", "だろ？"],
        "keywords": ["輝夜", "不死", "蓬莱", "竹林", "炎", "焼き尽くす", "妹紅"],
    },
    "霖之助": {
        "aliases": ["霖之助", "こーりん", "森近霖之助", "森近", "rinnosuke", "korin"],
        "first_person": ["僕", "私", "霖之助"],
        "second_person": ["君", "魔理沙", "霊夢"],
        "sentence_endings": ["だな", "かい", "ということだ", "かね", "だろう", "かい？"],
        "keywords": ["香霖堂", "道具", "鑑定", "外の世界", "商品", "霖之助"],
    },
    "にとり": {
        "aliases": ["にとり", "河城にとり", "河城", "河童", "nitori", "kawashiro"],
        "first_person": ["私", "にとり"],
        "second_person": ["あんた", "お前", "操夢", "霊夢"],
        "sentence_endings": ["だよ", "だな", "じゃないか", "ね", "よ", "だよ！", "見せてやるよ", "見せてやるよ！"],
        "keywords": ["河童", "きゅうり", "エンジニア", "発明", "光学迷彩", "アーム", "にとり", "技術力"],
    },
    "幽々子": {
        "aliases": ["幽々子", "ゆゆこ", "西行寺幽々子", "西行寺", "yuyuko", "saigyouji"],
        "first_person": ["私", "幽々子"],
        "second_person": ["妖夢", "紫", "あなた"],
        "sentence_endings": ["かしら", "わね", "のよ", "ちょうだい", "わ", "なのね", "かしら？"],
        "keywords": ["妖夢、", "白玉楼", "西行妖", "お腹が空いた", "蝶", "死相", "桜", "幽々子"],
    },
    "紫": {
        "aliases": ["紫", "ゆかり", "八雲紫", "八雲", "yukari", "yakumo"],
        "first_person": ["私", "わたくし"],
        "second_person": ["霊夢", "藍", "あなた", "貴方"],
        "sentence_endings": ["かしら", "わよ", "のよ", "わね", "ことね", "こと", "わ"],
        "keywords": ["スキマ", "結界", "境界", "幻想郷", "八雲", "藍、", "紫"],
    },
    "輝夜": {
        "aliases": ["輝夜", "かぐや", "蓬莱山輝夜", "蓬莱山", "姫様", "kaguya", "houraisan"],
        "first_person": ["私", "わらわ", "輝夜"],
        "second_person": ["永琳", "妹紅", "あなた"],
        "sentence_endings": ["わ", "のよ", "かしら", "なさい", "わね", "ぞよ"],
        "keywords": ["永琳、", "妹紅", "蓬莱", "永遠亭", "五つの難題", "月", "輝夜"],
    },
    "永琳": {
        "aliases": ["永琳", "えーりん", "八意永琳", "八意", "師匠", "eirin", "yagokoro"],
        "first_person": ["私", "永琳"],
        "second_person": ["姫様", "輝夜", "鈴仙", "うどんげ"],
        "sentence_endings": ["わ", "のよ", "かしら", "なさい", "ね", "わね"],
        "keywords": ["姫様", "薬", "永遠亭", "月", "八意", "永琳", "うどんげ、"],
    },
    "天子": {
        "aliases": ["天子", "てんこ", "比那名居天子", "比那名居", "tenshi", "hinanawi"],
        "first_person": ["私", "天子"],
        "second_person": ["あんた", "お前", "衣玖"],
        "sentence_endings": ["じゃない", "ぜ", "わよ", "だわ", "のかしら", "ね！"],
        "keywords": ["要石", "有頂天", "緋想の剣", "天界", "天子", "退屈"],
    },
    "白蓮": {
        "aliases": ["白蓮", "ひじり", "聖白蓮", "聖", "byakuren", "hijiri"],
        "first_person": ["私", "白蓮"],
        "second_person": ["あなた", "皆さん", "一輪", "村紗"],
        "sentence_endings": ["です", "ですね", "ですよ", "ます", "ましょう", "南無三"],
        "keywords": ["南無三", "命蓮寺", "妖怪と人間", "法力", "白蓮", "救済"],
    },
    "神子": {
        "aliases": ["神子", "みこ", "豊聡耳神子", "豊聡耳", "太子", "miko", "toyosatomimi"],
        "first_person": ["私", "我", "余"],
        "second_person": ["そなた", "お前", "布都", "屠自古"],
        "sentence_endings": ["である", "だな", "ぞ", "のだ", "か", "であろう"],
        "keywords": ["十人の話", "道教", "仙人", "神子", "太子", "布都、"],
    },
    "布都": {
        "aliases": ["布都", "ふと", "物部布都", "物部", "futo", "mononobe"],
        "first_person": ["我", "私", "布都"],
        "second_person": ["太子様", "神子様", "お主", "そなた"],
        "sentence_endings": ["でおじゃる", "ぞ", "のだ", "でおじゃるな", "か！", "おじゃる"],
        "keywords": ["太子様", "神子様", "皿", "物部", "布都", "でおじゃる"],
    },
    "正邪": {
        "aliases": ["正邪", "せいじゃ", "鬼人正邪", "鬼人", "seija", "kijin"],
        "first_person": ["私", "俺", "正邪"],
        "second_person": ["お前", "あんた", "針妙丸"],
        "sentence_endings": ["ぜ", "だろ", "じゃねえか", "ひっくり返してやる", "だぜ", "のかよ"],
        "keywords": ["下克上", "ひっくり返す", "天邪鬼", "あまのじゃく", "正邪", "強者"],
    },
    "針妙丸": {
        "aliases": ["針妙丸", "しんみょうまる", "少名針妙丸", "少名", "shinmyoumaru", "sukuna"],
        "first_person": ["私", "ボク", "針妙丸"],
        "second_person": ["お前", "正邪", "あなた"],
        "sentence_endings": ["だよ", "だぞ", "もん", "じゃないか", "だよ！", "ぞ！"],
        "keywords": ["打ち出の小槌", "小人", "針妙丸", "お椀", "正邪"],
    },
    "クラウンピース": {
        "aliases": ["クラウンピース", "くらうんぴーす", "クラピ", "clownpiece"],
        "first_person": ["あたい", "クラピ"],
        "second_person": ["お前", "ご主人様", "ヘカーティア様"],
        "sentence_endings": ["だよ", "だもん", "狂わせちゃうよ", "あはは", "だよ！", "もん！"],
        "keywords": ["狂気", "松明", "地獄", "ヘカーティア様", "クラウンピース", "クラピ"],
    },
    "マミゾウ": {
        "aliases": ["マミゾウ", "まみぞう", "二ッ岩マミゾウ", "二ッ岩", "mamizou", "futatsuiwa"],
        "first_person": ["儂", "わし", "マミゾウ"],
        "second_person": ["お主", "あんた", "お前さん"],
        "sentence_endings": ["じゃろ", "のう", "じゃ", "のう？", "じゃな", "わい"],
        "keywords": ["化け狸", "佐渡", "マミゾウ", "煙管", "変化", "〜じゃろ"],
    },
    "美鈴": {
        "aliases": ["美鈴", "めいりん", "紅美鈴", "meiling", "hong"],
        "first_person": ["私", "美鈴"],
        "second_person": ["お嬢様", "咲夜さん", "あなた"],
        "sentence_endings": ["ですよ", "ですね", "です", "ます", "あぅ", "ですよ！"],
        "keywords": ["門番", "太極拳", "紅魔館", "咲夜さん", "美鈴", "居眠り"],
    },
    "ルーミア": {
        "aliases": ["ルーミア", "るーみあ", "rumia"],
        "first_person": ["あたい", "ルーミア"],
        "second_person": ["あんた", "お前"],
        "sentence_endings": ["なのかー", "だよ", "のかー？", "なのかー！", "もん"],
        "keywords": ["そーなのかー", "暗闇", "十文字", "ルーミア", "食べる"],
    }
}


def extract_speaker_prefix(raw_text: str) -> Tuple[Optional[str], str]:
    """
    セリフテキストから話者プレフィックス（【霊夢】、魔理沙:、操夢「 等）を検出し、
    (検出されたキャラクター名, クレンジング後のセリフ本文) を返す。
    """
    if not raw_text or not raw_text.strip():
        return None, ""

    text = raw_text.strip()

    # パターン1: 【キャラクター名】「セリフ」 または 【キャラクター名】セリフ
    m1 = re.match(r"^[\s]*[【\[［(（<〈《「]([^\s】\]］)）>〉》」]+)[】\]］)）>〉》」][\s:：]*(.*)$", text, re.DOTALL)
    if m1:
        cand = m1.group(1).strip()
        body = m1.group(2).strip()
        norm = CHARACTER_ALIASES.get(cand, cand)
        if norm in CHARACTERS or any(cand in p.get("aliases", []) for p in CHARACTER_PROFILES.values()):
            return norm, body if body else text

    # パターン2: キャラクター名:「セリフ」 または キャラクター名：セリフ
    m2 = re.match(r"^[\s]*([^\s:：]{1,10})[\s]*[:：][\s]*(.*)$", text, re.DOTALL)
    if m2:
        cand = m2.group(1).strip()
        body = m2.group(2).strip()
        norm = CHARACTER_ALIASES.get(cand, cand)
        if norm in CHARACTERS or any(cand in p.get("aliases", []) for p in CHARACTER_PROFILES.values()):
            return norm, body if body else text

    # パターン3: キャラクター名「セリフ」 (例: 霊夢「何があったの？」)
    m3 = re.match(r"^[\s]*([^\s「『]{1,8})[\s]*([「『].+[」』][\s]*)$", text, re.DOTALL)
    if m3:
        cand = m3.group(1).strip()
        body = m3.group(2).strip()
        norm = CHARACTER_ALIASES.get(cand, cand)
        if norm in CHARACTERS or any(cand in p.get("aliases", []) for p in CHARACTER_PROFILES.values()):
            return norm, body

    # パターン4: 記号付き ●キャラクター名 / ◆キャラクター名 / ■キャラクター名
    m4 = re.match(r"^[\s]*[●◆■★▲▼◎○◇□☆][\s]*([^\s:：]{1,8})[\s:：]*(.*)$", text, re.DOTALL)
    if m4:
        cand = m4.group(1).strip()
        body = m4.group(2).strip()
        norm = CHARACTER_ALIASES.get(cand, cand)
        if norm in CHARACTERS or any(cand in p.get("aliases", []) for p in CHARACTER_PROFILES.values()):
            return norm, body if body else text

    return None, text


def guess_character(
    text: str,
    notes: str = "",
    slide_idx: int = 1,
    image_names: str = "",
    prev_character: Optional[str] = None
) -> Tuple[str, str, int, int]:
    """
    セリフ、発表者ノート、スライド画像名、文脈から発話キャラクターを超高精度に特定。
    @return: (character_name, voice_type, speed, pitch)
    """
    soumu = CHARACTERS["操夢"]
    default_res = ("操夢", soumu["voice"], soumu["speed"], soumu["pitch"])

    combined_text = (text or "").strip()
    notes_text = (notes or "").strip()
    images_text = (image_names or "").strip()

    if not combined_text:
        return default_res

    # 1. 1スライド目（タイトル・あらすじ等）は操夢（ナレーション）
    if slide_idx == 1 or "東方Project二次創作" in combined_text or ("第" in combined_text and "話" in combined_text and len(combined_text) < 30):
        return default_res

    # 2. 話者プレフィックス（【霊夢】、魔理沙: 等）の最優先チェック
    prefix_char, clean_text = extract_speaker_prefix(combined_text)
    if prefix_char:
        norm_char = CHARACTER_ALIASES.get(prefix_char, prefix_char)
        if norm_char in CHARACTERS:
            c = CHARACTERS[norm_char]
            return norm_char, c["voice"], c["speed"], c["pitch"]

    # 3. 過去作コーパス (CorpusKnowledgeEngine) からの立ち絵画像照合
    corpus = get_corpus_engine()
    if images_text:
        img_char = corpus.lookup_image_character(images_text)
        if img_char and img_char in CHARACTERS:
            c = CHARACTERS[img_char]
            return img_char, c["voice"], c["speed"], c["pitch"]

    # 4. 過去作コーパスからの同一セリフ照合
    exact_match = corpus.lookup_exact_dialogue(combined_text)
    if exact_match and exact_match.get("character") in CHARACTERS:
        c_name = exact_match["character"]
        c = CHARACTERS[c_name]
        return c_name, c["voice"], c["speed"], c["pitch"]

    # 「」や『』が含まれるか（セリフか地の文かの判定）
    has_quote = ("「" in combined_text or "」" in combined_text or "『" in combined_text or "』" in combined_text)

    # 5. カギ括弧がない地の文・モノローグはすべて操夢
    if not has_quote:
        # ノート欄に明確な別キャラクター指定がない限り操夢
        if not notes_text:
            return default_res

    # 6. 多層スコアリング判定エンジンの実行
    scores: Dict[str, float] = {char_name: 0.0 for char_name in CHARACTERS.keys()}

    # (A) 過去作コーパスの発話類似度スコア加算 (+150〜+400)
    corpus_scores = corpus.score_corpus_similarity(combined_text)
    for c_name, c_score in corpus_scores.items():
        scores[c_name] += c_score

    # (B) 発表者ノート（Presenter Notes）によるスコア加算 (+500)
    if notes_text:
        for char_name, profile in CHARACTER_PROFILES.items():
            for alias in profile.get("aliases", [char_name]):
                if alias in notes_text:
                    scores[char_name] += 500.0
                    break

    # (C) スライド内画像・立ち絵ファイル名によるスコア加算 (+400 / +300)
    if images_text:
        assets_lib = get_video_assets_library()
        for fn in images_text.split(","):
            fn_clean = fn.strip()
            if fn_clean:
                classified = assets_lib.classify_image(fn_clean)
                if classified.get("type") == "character" and classified.get("character"):
                    c_name = classified["character"]
                    if c_name in scores:
                        scores[c_name] += 400.0
        for char_name, profile in CHARACTER_PROFILES.items():
            for alias in profile.get("aliases", [char_name]):
                if alias.lower() in images_text.lower():
                    scores[char_name] += 300.0
                    break


    # (D) 言語的特徴（口調・語尾・一人称・二人称・キーワード）スコアリング
    for char_name, profile in CHARACTER_PROFILES.items():
        # 一人称 (+80)
        for fp in profile.get("first_person", []):
            if fp in combined_text:
                scores[char_name] += 80.0
                break

        # 二人称・呼びかけ (+70)
        for sp in profile.get("second_person", []):
            if sp in combined_text:
                scores[char_name] += 70.0
                break

        # 語尾・文末特徴 (+60)
        for se in profile.get("sentence_endings", []):
            if combined_text.endswith(se) or (se + "」" in combined_text) or (se + "』" in combined_text) or (se + "。" in combined_text) or (se + "！" in combined_text) or (se + "？" in combined_text):
                scores[char_name] += 90.0
            elif se in combined_text:
                scores[char_name] += 40.0

        # 東方固有キーワード (+50)
        for kw in profile.get("keywords", []):
            if kw in combined_text:
                scores[char_name] += 50.0

    # (E) カギ括弧なしの地の文ボーナス
    if not has_quote:
        scores["操夢"] += 200.0

    # 最高スコアのキャラクターを選定
    best_char = max(scores, key=scores.get)
    highest_score = scores[best_char]

    if highest_score > 30.0:
        c = CHARACTERS[best_char]
        return best_char, c["voice"], c["speed"], c["pitch"]

    # スコアが拮抗または該当なしの場合のフォールバック
    if has_quote:
        # デフォルトの女性セリフは霊夢
        c = CHARACTERS["霊夢"]
        return "霊夢", c["voice"], c["speed"], c["pitch"]
    else:
        # 地の文は操夢
        return default_res


KEYNOTE_EFFECT_NAMES = {
    "wipe": "ワイプ",
    "appear": "出現",
    "bc-appear": "出現",
    "disappear": "非表示",
    "fade": "フェード",
    "dissolve": "ディゾルブ",
    "scale": "拡大/縮小",
    "move": "移動",
    "push": "プッシュ",
    "reveal": "リビール",
    "iris": "アイリス",
    "blind": "ブラインド",
    "cube": "キューブ",
    "flip": "フリップ",
    "spin": "スピン",
    "pop": "ポップ",
    "fly": "フライ",
    "drop": "ドロップ",
    "drift": "ドリフト",
    "fall": "フォール",
    "twirl": "トワール",
    "blur": "ブラー",
    "pulse": "パルス",
    "shimmer": "シマー",
    "sparkle": "スパークル",
    "action-rotation": "回転",
    "action-bounce": "バウンス",
    "action-scale": "拡大/縮小",
    "action-opacity": "不透明度",
    "action-move": "移動",
    "action-blink": "点滅",
    "action-jiggle": "ジグル",
    "action-pulse": "パルス",
    "none": "なし"
}


def snappy_decompress(data: bytes) -> bytes:
    """Snappy 圧縮バイト列の Pure Python 高速デコーダー"""
    pos = 0
    length = 0
    shift = 0
    while True:
        if pos >= len(data):
            break
        b = data[pos]
        pos += 1
        length |= (b & 0x7f) << shift
        if (b & 0x80) == 0:
            break
        shift += 7

    out = bytearray()
    while pos < len(data):
        tag = data[pos]
        pos += 1
        element_type = tag & 0x03
        if element_type == 0:
            lit_len = tag >> 2
            if lit_len < 60:
                lit_len += 1
            elif lit_len == 60:
                if pos >= len(data): break
                lit_len = data[pos] + 1
                pos += 1
            elif lit_len == 61:
                if pos + 2 > len(data): break
                import struct
                lit_len = struct.unpack("<H", data[pos:pos+2])[0] + 1
                pos += 2
            elif lit_len == 62:
                if pos + 3 > len(data): break
                import struct
                lit_len = struct.unpack("<I", data[pos:pos+3] + b"\x00")[0] + 1
                pos += 3
            elif lit_len == 63:
                if pos + 4 > len(data): break
                import struct
                lit_len = struct.unpack("<I", data[pos:pos+4])[0] + 1
                pos += 4
            out.extend(data[pos:pos+lit_len])
            pos += lit_len
        elif element_type == 1:
            copy_len = ((tag >> 2) & 0x07) + 4
            if pos >= len(data): break
            offset = ((tag >> 5) << 8) | data[pos]
            pos += 1
            for _ in range(copy_len):
                if offset <= len(out):
                    out.append(out[-offset])
                else:
                    out.append(0)
        elif element_type == 2:
            copy_len = (tag >> 2) + 1
            if pos + 2 > len(data): break
            import struct
            offset = struct.unpack("<H", data[pos:pos+2])[0]
            pos += 2
            for _ in range(copy_len):
                if offset <= len(out):
                    out.append(out[-offset])
                else:
                    out.append(0)
        elif element_type == 3:
            copy_len = (tag >> 2) + 1
            if pos + 4 > len(data): break
            import struct
            offset = struct.unpack("<I", data[pos:pos+4])[0]
            pos += 4
            for _ in range(copy_len):
                if offset <= len(out):
                    out.append(out[-offset])
                else:
                    out.append(0)
    return bytes(out)


def read_iwa_safe(data: bytes) -> bytes:
    """Keynote .iwa ファイル（Snappy Framed Chunks）の展開"""
    pos = 0
    full_out = bytearray()
    while pos < len(data):
        if pos + 4 > len(data): break
        header = data[pos]
        length = int.from_bytes(data[pos+1:pos+4], "little")
        pos += 4
        if pos + length > len(data): break
        chunk = data[pos:pos+length]
        pos += length
        try:
            decomp = snappy_decompress(chunk)
            full_out.extend(decomp)
        except Exception:
            pass
    return bytes(full_out)


def encode_varint(val: int) -> bytes:
    """Protobuf varint エンコード"""
    b = bytearray()
    while val > 0x7f:
        b.append((val & 0x7f) | 0x80)
        val >>= 7
    b.append(val & 0x7f)
    return bytes(b)


def parse_keynote_package_animations(keynote_path: str) -> Dict[int, Dict[str, Any]]:
    """
    Keynote (.key) パッケージ内の各スライドの iwa ファイルを直接走査し、
    スライドごとのビルドアニメーション（イン・アクション・アウト）、トランジション、
    テンプレート情報（セクション見出し等）、ノート、テキスト、画像情報を包括的に抽出する。
    戻り値: { slide_index: { "builds": [...], "transition": {...}, "template_name": str, "template_info": {...}, "notes": str, "slide_text": str, "images": [...] } }
    """
    import zipfile
    import struct

    if not os.path.exists(keynote_path) or os.path.getsize(keynote_path) == 0:
        return {}

    animations_by_slide = {}
    try:
        with zipfile.ZipFile(keynote_path, "r") as z:
            # 1. テンプレート (TemplateSlide-*.iwa) の名前とIDを走査
            template_map = {}
            for n in z.namelist():
                if n.startswith("Index/TemplateSlide-") and n.endswith(".iwa"):
                    tid_str = n.replace("Index/TemplateSlide-", "").replace(".iwa", "")
                    try:
                        tid = int(tid_str)
                    except ValueError:
                        continue
                    decomp_t = read_iwa_safe(z.read(n))
                    matches_t = re.finditer(rb"(?:[\x20-\x7e]|[\xc2-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}){2,}", decomp_t)
                    tname = "スライド"
                    for m in matches_t:
                        try:
                            dec = m.group(0).decode("utf-8").strip()
                            if any(k in dec for k in ["タイトル", "セクション", "見出し", "箇条書き", "空白", "写真", "画像", "議題", "ステートメント", "引用", "ビッグファクト"]):
                                tname = dec
                                break
                        except Exception:
                            pass
                    template_map[tid] = tname

            slide_names = [n for n in z.namelist() if n.startswith("Index/Slide-") and n.endswith(".iwa")]
            # ソートしてスライド番号順にマッピング
            for idx, sname in enumerate(sorted(slide_names), start=1):
                try:
                    data = z.read(sname)
                    decomp = read_iwa_safe(data)

                    # テンプレートの判定
                    matched_template = "標準"
                    for tid, tname in template_map.items():
                        if encode_varint(tid) in decomp:
                            matched_template = tname
                            break

                    is_section = any(k in matched_template for k in ["セクション", "見出し", "タイトル", "議題"])

                    builds = []
                    # 1. ビルドアニメーション (In / Out / Emphasis / Action)
                    pattern = rb"(In|Out|Emphasis|Action)[\x00-\x20]{1,4}apple:([a-zA-Z0-9_-]+)"
                    for m in re.finditer(pattern, decomp):
                        btype = m.group(1).decode("ascii")
                        effect_raw = m.group(2).decode("ascii").replace("apple:", "")
                        effect_ja = KEYNOTE_EFFECT_NAMES.get(effect_raw.lower(), effect_raw)

                        # duration
                        start_idx = m.end()
                        dur = 1.0
                        for offset in range(start_idx, min(len(decomp) - 8, start_idx + 40)):
                            if decomp[offset] == 0x19: # double tag
                                val = struct.unpack("<d", decomp[offset+1:offset+9])[0]
                                if 0.05 <= val <= 60.0:
                                    dur = val
                                    break

                        # delivery
                        delivery = "一括"
                        context = decomp[max(0, m.start()-80):min(len(decomp), m.end()+80)]
                        if b"All at Once" in context:
                            delivery = "一括"
                        elif b"By Object" in context:
                            delivery = "オブジェクトごと"
                        elif b"By Paragraph" in context:
                            delivery = "段落ごと"

                        # direction
                        direction = ""
                        if b"from-left" in context or b"left-to-right" in context or b"Left" in context:
                            direction = "左から"
                        elif b"from-right" in context or b"right-to-left" in context or b"Right" in context:
                            direction = "右から"
                        elif b"from-top" in context or b"top-to-bottom" in context or b"Top" in context:
                            direction = "上から"
                        elif b"from-bottom" in context or b"bottom-to-top" in context or b"Bottom" in context:
                            direction = "下から"

                        type_ja = "イン" if btype == "In" else ("アウト" if btype == "Out" else "アクション")

                        builds.append({
                            "type": btype,
                            "type_ja": type_ja,
                            "effect": effect_raw,
                            "effect_name": effect_ja,
                            "duration": round(dur, 2),
                            "direction": direction,
                            "delivery": delivery
                        })

                    # 2. トランジション
                    transition = None
                    t_pattern = rb"Transition[\x00-\x20]{1,4}apple:([a-zA-Z0-9_-]+)"
                    t_match = re.search(t_pattern, decomp)
                    if t_match:
                        t_effect = t_match.group(1).decode("ascii").replace("apple:", "")
                        t_ja = KEYNOTE_EFFECT_NAMES.get(t_effect.lower(), t_effect)
                        transition = {"effect": t_effect, "effect_name": t_ja}

                    # 3. テキスト文字列 / ノート / オブジェクト文字列の抽出
                    matches_s = re.finditer(rb"(?:[\x20-\x7e]|[\xc2-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}){2,}", decomp)
                    slide_strings = []
                    notes_extracted = ""
                    text_extracted = []
                    for sm in matches_s:
                        try:
                            s_dec = sm.group(0).decode("utf-8").strip()
                            if len(s_dec) >= 2 and not s_dec.startswith("apple:") and not s_dec.startswith("Transition") and s_dec not in ["none", "All at Once", "By Object", "By Paragraph", "ja", "en", "decimal"]:
                                slide_strings.append(s_dec)
                                if (s_dec.startswith("【") or s_dec.startswith("[") or "「" in s_dec) and len(s_dec) > 4:
                                    if not notes_extracted:
                                        notes_extracted = s_dec
                                elif len(s_dec) > 3 and not any(c in s_dec for c in ["0B.", "1B/", "@A-", "oD", "$3A", "$66", "$A0"]):
                                    text_extracted.append(s_dec)
                        except Exception:
                            pass

                    animations_by_slide[idx] = {
                        "builds": builds,
                        "transition": transition,
                        "template_name": matched_template,
                        "template_info": {
                            "layout_name": matched_template,
                            "is_section_header": is_section,
                            "section_title": slide_strings[0] if is_section and slide_strings else ""
                        },
                        "notes": notes_extracted,
                        "slide_text": "\n".join(text_extracted) if text_extracted else "",
                        "strings": slide_strings
                    }
                except Exception as ex_s:
                    pass
    except Exception as ex_z:
        pass

    return animations_by_slide


def has_animation_instruction(notes: str, text: str = "", builds: Optional[List[Dict[str, Any]]] = None, has_transition: bool = False) -> bool:
    """
    ノート欄、テキスト、ビルドアニメーション（イン・アクション・アウト）、自動トランジションから
    アニメーション演出があるかを高精度・包括的に判定。
    """
    if builds and len(builds) > 0:
        return True
    if has_transition:
        return True

    notes_str = (notes or "").strip()
    text_str = (text or "").strip()
    target_str = notes_str if notes_str else text_str
    if not target_str:
        return False

    # 1. アニメーション指示・表示時間・待機時間の抽出試行
    extra_del, target_dur, is_sync, _ = extract_animation_instructions(target_str)
    if extra_del is not None or target_dur is not None or is_sync:
        return True

    # 2. 無音・動画演出キーワードのチェック
    silent_pattern = r'[\[【(（](?:無音|音声なし|無音スライド|動画|動画クリップ|video|movie|animation)[\]】)）]'
    if re.search(silent_pattern, target_str, re.IGNORECASE):
        return True

    return False


def extract_animation_instructions(text: str) -> Tuple[Optional[float], Optional[float], bool, str]:
    """
    ノートやテキストからアニメーション・表示時間・待機時間に関する指示タグを抽出・クレンジングする。
    戻り値: (extra_delay, target_duration, is_animation_sync, cleaned_text)
    
    対応パターン例:
    - [アニメーション: 3.5秒] / [アニメ: 3.5s] / [animation: 3.5]
    - [表示時間: 4.0秒] / [時間: 4s] / [duration: 4.0]
    - [待機時間: 2.0秒] / [待機: 2.0秒] / [余白: 2.0s] / [delay: 2.0]
    - [アニメーションに合わせる] / [アニメ連動] / [アニメーション時間]
    - [動画] / [動画クリップ] / [video] / [movie]
    - (無音) / 音声なし
    - 括弧のバリエーション: [] 【】 () （） ［］
    """
    if not text:
        return None, None, False, ""

    extra_delay = None
    target_duration = None
    is_animation_sync = False
    cleaned = text

    # 1. アニメーション連動キーワード ([アニメーションに合わせる], [アニメ連動] など)
    sync_pattern = r'[\[【(（［](?:アニメーションに合わせる|アニメに合わせる|アニメ連動|アニメーション連動|アニメーション時間)[\]】)）］]'
    if re.search(sync_pattern, cleaned):
        is_animation_sync = True
        cleaned = re.sub(sync_pattern, '', cleaned)

    # 2. 表示時間 / 総時間指定 ([表示時間: 4.0秒], [時間: 4s], [duration: 4.0], [time: 4] など)
    duration_pattern = r'[\[【(（［](?:表示時間|スライド時間|総時間|duration|time|時間)\s*[:：=＝]\s*(\d+(?:\.\d+)?)\s*(?:秒|s|sec|seconds)?[\]】)）］]'
    m_dur = re.search(duration_pattern, cleaned, re.IGNORECASE)
    if m_dur:
        try:
            target_duration = float(m_dur.group(1))
            cleaned = re.sub(duration_pattern, '', cleaned, flags=re.IGNORECASE)
        except ValueError:
            pass

    # 3. アニメーション待機時間 / 遅延指定 ([アニメ: 2.0秒], [待機: 1.5s], [anim: 3.0], [delay: 2] など)
    delay_pattern = r'[\[【(（［](?:アニメーション|アニメ|待機時間|待機|遅延|余白|delay|anim)\s*[:：=＝]\s*(\d+(?:\.\d+)?)\s*(?:秒|s|sec|seconds)?[\]】)）］]'
    m_del = re.search(delay_pattern, cleaned, re.IGNORECASE)
    if m_del:
        try:
            extra_delay = float(m_del.group(1))
            cleaned = re.sub(delay_pattern, '', cleaned, flags=re.IGNORECASE)
        except ValueError:
            pass

    # 4. 動画・クリップ明示タグ ([動画], [動画クリップ], [video] など)
    video_tag_pattern = r'[\[【(（［](?:動画|動画クリップ|video|movie|clip)[\]】)）］]'
    if re.search(video_tag_pattern, cleaned, re.IGNORECASE):
        is_animation_sync = True
        cleaned = re.sub(video_tag_pattern, '', cleaned, flags=re.IGNORECASE)

    # 5. 無音タグのクレンジング
    silent_tag_pattern = r'[\[【(（［](?:無音|音声なし|無音スライド)[\]】)）］]|(?:^|\n)(?:無音|音声なし)(?:\n|$)'
    cleaned = re.sub(silent_tag_pattern, '', cleaned)

    return extra_delay, target_duration, is_animation_sync, cleaned.strip()


def check_all_objects_animation(
    slide_index: int,
    raw_script_text: str,
    notes: str,
    text_content: str,
    images_str: str,
    trans_effect: str,
    trans_delay: float,
    trans_duration: float,
    found_telop: bool,
    prev_slide_info: Optional[Dict[str, Any]],
    assets_lib: VideoAssetsLibrary,
    builds: Optional[List[Dict[str, Any]]] = None,
    automatic_transition: bool = False,
    template_name: str = "標準",
    template_info: Optional[Dict[str, Any]] = None,
    shapes_info: Optional[List[Dict[str, Any]]] = None,
    text_items_info: Optional[List[Dict[str, Any]]] = None,
    character_name: str = ""
) -> Dict[str, Any]:
    """
    スライド内の全要素（キャラクター、テロップ、テキスト、図形、テンプレート情報、ビルドアニメーション、トランジション）から
    オブジェクト詳細情報およびアニメーションステータスを網羅的に解析し、
    ノート時間とアニメーション時間を比較して「より長い方を優先適用（アニメーションに合わせる時はアニメーションをそのまま利用）」ルールを適用する。
    """
    animated_objects = []
    animation_details = {
        "presenter_notes": [],
        "transitions": [],
        "builds": [],
        "images": [],
        "characters": [],
        "background": [],
        "shapes": [],
        "texts": [],
        "template": []
    }

    builds_list = list(builds) if builds else []

    # 1. 発表者ノート・スクリプトからのタグ解析
    note_delay, note_dur, note_sync, _ = extract_animation_instructions(notes)
    script_delay, script_dur, script_sync, script_without_anim = extract_animation_instructions(raw_script_text)

    anim_delay = note_delay if note_delay is not None else script_delay
    target_dur = note_dur if note_dur is not None else script_dur
    is_anim_sync = note_sync or script_sync

    # 2. 画像の分類・キャラクターステータス（画像情報・アニメーション情報）の解析
    img_list = [img.strip() for img in images_str.split(",") if img.strip()]
    char_images = []
    bg_images = []
    telop_detected = found_telop
    characters_list = []

    for img in img_list:
        cls_info = assets_lib.classify_image(img) if assets_lib else {}
        cls_type = cls_info.get("type", "other") if isinstance(cls_info, dict) else str(cls_info)
        fname = os.path.basename(img)
        
        if cls_type == "character":
            char_images.append(img)
            c_name = cls_info.get("character") or character_name or "操夢"
            # このキャラクターに関連するビルドアニメーション
            char_builds = list(builds_list) # スライド全体のビルドをキャラに反映
            has_movement = len(char_builds) > 0
            if has_movement:
                b_desc_list = [f"{b.get('type_ja','イン')}: {b.get('effect_name', b.get('effect',''))} ({b.get('duration', 1.0)}秒)" for b in char_builds]
                status_desc = f"動きあり [{', '.join(b_desc_list)}]"
            else:
                status_desc = "静止画 (立ち絵表示)"

            characters_list.append({
                "name": c_name,
                "image_name": fname,
                "image_path": cls_info.get("matched_path") or img,
                "animations": char_builds,
                "has_movement": has_movement,
                "status": status_desc,
                "duration": max([float(b.get("duration", 1.0) or 1.0) for b in char_builds], default=0.0)
            })
            animation_details["characters"].append(f"【{c_name}】{fname} - {status_desc}")
            if "character" not in animated_objects and has_movement:
                animated_objects.append("character")

        elif cls_type == "background":
            bg_images.append(img)
            animation_details["background"].append(f"背景: {fname}")
            if "background" not in animated_objects and len(builds_list) > 0:
                animated_objects.append("background")
        elif cls_type in ("telop", "telop_frame"):
            telop_detected = True
            if "telop_frame" not in animated_objects:
                animated_objects.append("telop_frame")

    # 2.5 キャラクター画像の補完
    if not characters_list and character_name:
        char_builds = list(builds_list)
        has_movement = len(char_builds) > 0
        if has_movement:
            b_desc_list = [f"{b.get('type_ja','イン')}: {b.get('effect_name', b.get('effect',''))} ({b.get('duration', 1.0)}秒)" for b in char_builds]
            status_desc = f"動きあり [{', '.join(b_desc_list)}]"
        else:
            status_desc = "静止画 (立ち絵表示)"

        characters_list.append({
            "name": character_name,
            "image_name": f"{character_name}_立ち絵",
            "image_path": "",
            "animations": char_builds,
            "has_movement": has_movement,
            "status": status_desc,
            "duration": max([float(b.get("duration", 1.0) or 1.0) for b in char_builds], default=0.0)
        })
        animation_details["characters"].append(f"【{character_name}】立ち絵 - {status_desc}")
        if "character" not in animated_objects and has_movement:
            animated_objects.append("character")

    # 3. テロップオブジェクトの構築
    telop_text = text_content if telop_detected else ""
    telop_obj = {
        "detected": telop_detected,
        "text": telop_text,
        "shape_name": "テロップ枠" if telop_detected else None,
        "animations": [b for b in builds_list if "ワイプ" in b.get("effect_name", "") or "出現" in b.get("effect_name", "")]
    }

    # 4. テキストアイテムオブジェクトの構築
    texts_list = []
    if text_items_info:
        texts_list = text_items_info
    elif text_content and not telop_detected:
        texts_list.append({
            "text": text_content,
            "type": "body",
            "animations": builds_list
        })

    # 5. 図形オブジェクトの構築
    shapes_list = []
    if shapes_info:
        shapes_list = shapes_info

    # 6. テンプレート情報オブジェクトの構築
    is_sec = any(k in template_name for k in ["セクション", "見出し", "タイトル", "議題"])
    sec_title = ""
    if is_sec:
        first_line = (raw_script_text.split("\n")[0] if raw_script_text else "").strip()
        first_line = re.sub(r'^[\[【(（].*?[\]】)）]', '', first_line).strip()
        sec_title = first_line[:40]

    tmpl_obj = template_info or {
        "layout_name": template_name,
        "is_section_header": is_sec,
        "section_title": sec_title
    }
    if isinstance(tmpl_obj, dict) and not tmpl_obj.get("section_title") and sec_title:
        tmpl_obj["section_title"] = sec_title

    animation_details["template"].append(f"レイアウト: {tmpl_obj.get('layout_name', '標準')} (セクション見出し: {'はい' if tmpl_obj.get('is_section_header') else 'いいえ'})")

    # 全走査オブジェクト構造体の作成
    slide_objects = {
        "characters": characters_list,
        "telop": telop_obj,
        "texts": texts_list,
        "shapes": shapes_list,
        "template": tmpl_obj
    }

    # 7. ビルドアニメーション (イン / アクション / アウト) の解析・記録
    max_build_duration = 0.0
    for b in builds_list:
        b_type = b.get("type", "In")
        b_type_ja = b.get("type_ja", "イン")
        b_eff = b.get("effect_name", b.get("effect", ""))
        b_dur = float(b.get("duration", 1.0) or 1.0)
        b_dir = b.get("direction", "")
        b_deliv = b.get("delivery", "一括")

        max_build_duration = max(max_build_duration, b_dur)

        dir_str = f" ({b_dir})" if b_dir else ""
        desc = f"[{b_type_ja}] {b_eff} ({b_dur}秒{dir_str}, {b_deliv})"
        animation_details["builds"].append(desc)

        obj_tag = "build_in" if b_type == "In" else ("build_out" if b_type == "Out" else "build_action")
        if obj_tag not in animated_objects:
            animated_objects.append(obj_tag)

    # 8. トランジション詳細記録（自動トランジション含む）
    has_auto_transition = bool(automatic_transition and (trans_delay > 0 or trans_duration > 0))
    has_trans_effect = bool(trans_effect and trans_effect.lower() not in ["", "none", "no transition effect", "missing value"])

    if has_auto_transition or has_trans_effect:
        auto_label = "自動" if automatic_transition else "クリック時"
        eff_label = trans_effect if has_trans_effect else "エフェクトなし"
        trans_desc = f"トランジション: {eff_label} (開始: {auto_label}, 遅れ: {trans_delay}秒, 時間: {trans_duration}秒)"
        animation_details["transitions"].append(trans_desc)
        if "transition" not in animated_objects:
            animated_objects.append("transition")

    # 9. 発表者ノート指示の記録
    if anim_delay is not None:
        animation_details["presenter_notes"].append(f"アニメーション/待機時間指定: {anim_delay}秒")
    if target_dur is not None:
        animation_details["presenter_notes"].append(f"スライド総表示時間指定: {target_dur}秒")
    if is_anim_sync:
        animation_details["presenter_notes"].append("Keynoteアニメーション連動指定 (アニメーションに合わせる)")
    if "(無音)" in notes or "音声なし" in notes:
        animation_details["presenter_notes"].append("無音演出スライド指定")

    if animation_details["presenter_notes"] and "presenter_notes" not in animated_objects:
        animated_objects.append("presenter_notes")

    # 10. 包括的アニメーション判定
    has_explicit_anim_tag = (anim_delay is not None or target_dur is not None or is_anim_sync)
    has_build_animations = (len(builds_list) > 0)
    has_transition_anim = (has_auto_transition or (has_trans_effect and trans_duration > 0))

    has_animation = (
        has_explicit_anim_tag or
        has_build_animations or
        has_transition_anim or
        has_animation_instruction(notes, raw_script_text, builds=builds_list, has_transition=has_transition_anim)
    )

    # 11. 【重要】時間優先適用ルール (Duration Reconciliation & Priority)
    # キャラクターアニメーション、テキスト/図形ビルド、トランジション時間
    max_char_anim_duration = max([c.get("duration", 0.0) for c in characters_list], default=0.0)
    trans_time = (trans_delay + trans_duration) if (trans_delay > 0 or trans_duration > 0) else 0.0
    keynote_max_anim_dur = max(max_build_duration, max_char_anim_duration, trans_time, 0.0)

    final_target_duration = None
    final_extra_delay = 0.0
    duration_priority_info = {}

    if is_anim_sync:
        # パターンA: 「アニメーションに合わせる」指定
        # -> キャラクター及びスライド上のテキストや図形のアニメーション設定時間をそのまま利用
        anim_time_val = keynote_max_anim_dur if keynote_max_anim_dur > 0 else (trans_delay if trans_delay > 0 else 3.0)
        final_target_duration = round(anim_time_val, 2)
        final_extra_delay = round(final_target_duration, 2)
        duration_priority_info = {
            "applied_mode": "sync",
            "applied_duration": final_target_duration,
            "note_duration": target_dur or anim_delay,
            "anim_duration": keynote_max_anim_dur,
            "reason": "【アニメーションに合わせる】スライド上のキャラクター・テキスト・図形のアニメーション設定時間をそのまま利用"
        }
    elif target_dur is not None or anim_delay is not None:
        # パターンB: ノート上に時間指示あり
        # -> ノート上の表記とスライド上のアニメーション時間に差異がある場合、より時間が長い方を優先適用
        note_time_val = float(target_dur if target_dur is not None else anim_delay)
        if keynote_max_anim_dur > note_time_val:
            # アニメーション時間の方が長い -> アニメーション時間を優先適用
            final_target_duration = round(keynote_max_anim_dur, 2)
            final_extra_delay = max(0.1, round(keynote_max_anim_dur, 2))
            duration_priority_info = {
                "applied_mode": "longer_priority",
                "applied_duration": keynote_max_anim_dur,
                "note_duration": note_time_val,
                "anim_duration": keynote_max_anim_dur,
                "reason": f"ノート指定({note_time_val:.1f}秒)よりアニメーション時間({keynote_max_anim_dur:.1f}秒)が長いためアニメーション時間を優先適用"
            }
        else:
            # ノート指定時間の方が長い（または等しい） -> ノート指定時間を適用
            final_target_duration = round(note_time_val, 2)
            final_extra_delay = max(0.1, round(note_time_val, 2))
            duration_priority_info = {
                "applied_mode": "longer_priority",
                "applied_duration": note_time_val,
                "note_duration": note_time_val,
                "anim_duration": keynote_max_anim_dur,
                "reason": f"ノート指定({note_time_val:.1f}秒)がアニメーション時間({keynote_max_anim_dur:.1f}秒)以上の長さのためノート指定を優先適用"
            }
    elif keynote_max_anim_dur > 0:
        # パターンC: ノート指定なし・スライドにアニメーションあり
        # -> アニメーション時間を自動適用
        final_target_duration = round(keynote_max_anim_dur, 2)
        final_extra_delay = max(0.1, round(keynote_max_anim_dur, 2))
        duration_priority_info = {
            "applied_mode": "anim_auto",
            "applied_duration": keynote_max_anim_dur,
            "note_duration": None,
            "anim_duration": keynote_max_anim_dur,
            "reason": f"スライド上のキャラクター・図形アニメーション時間({keynote_max_anim_dur:.1f}秒)を自動適用"
        }
    else:
        # パターンD: 静止スライド
        final_target_duration = None
        final_extra_delay = 0.0
        duration_priority_info = {
            "applied_mode": "static",
            "applied_duration": 0.0,
            "note_duration": None,
            "anim_duration": 0.0,
            "reason": "静止スライド（音声時間に完全同期）"
        }

    return {
        "has_animation": has_animation,
        "animated_objects": animated_objects,
        "animation_details": animation_details,
        "builds": builds_list,
        "bg_images": bg_images,
        "char_images": char_images,
        "telop_frame_detected": telop_detected,
        "anim_delay": anim_delay,
        "target_duration": target_dur,
        "is_animation_sync": is_anim_sync,
        "final_extra_delay": final_extra_delay,
        "final_target_duration": final_target_duration,
        "script_without_anim": script_without_anim,
        "transition_automatic": automatic_transition,
        "template_name": tmpl_obj.get("layout_name", "標準"),
        "template_info": tmpl_obj,
        "slide_objects": slide_objects,
        "duration_priority_info": duration_priority_info
    }


def extract_slides_from_keynote(file_path: str) -> List[Dict[str, Any]]:
    """
    AppleScript および Keynote (.key) パッケージ直接走査を使って、
    全スライドの全オブジェクト（背景、キャラクター、テロップ枠、テキスト、発表者ノート）
    およびアニメーション情報（イン、アクション、アウト、自動トランジション）を高精度に抽出する。
    """
    if not os.path.exists(file_path) or os.path.getsize(file_path) == 0:
        return []

    assets_lib = get_video_assets_library()
    assets_lib.scan_library()

    # 1. Keynote パッケージからのビルドアニメーション（イン・アクション・アウト）直接走査
    pkg_anims = parse_keynote_package_animations(file_path)

    keynote_app = get_keynote_app_name()
    escaped_file_path = file_path.replace('\\', '\\\\').replace('"', '\\"')

    # AppleScript スクリプト (テキスト + ノート + 全画像 + テロップ枠 + トランジション詳細 + テンプレート名)
    applescript_code = f'''
    tell application "{keynote_app}"
        set docPath to POSIX file "{escaped_file_path}"
        set doc to open file docPath
        set slideCount to count of slides of doc
        set resultList to {{}}
        
        repeat with i from 1 to slideCount
            set s to slide i of doc
            set slideText to ""
            
            -- presenter notes
            set pNotes to ""
            try
                set pNotes to (presenter notes of s) as text
            end try
            
            -- template (base slide / master slide name)
            set tmplName to "標準"
            try
                set tmplName to (name of base slide of s) as text
            on error
                try
                    set tmplName to (name of master slide of s) as text
                on error
                    try
                        set tmplName to (name of slide layout of s) as text
                    end try
                end try
            end try
            
            -- images (全画像ファイル名)
            set imgNames to ""
            try
                repeat with img in (images of s)
                    try
                        set fn to (file of img) as text
                        if fn is not "" and fn is not missing value then
                            if imgNames is not "" then set imgNames to imgNames & ","
                            set imgNames to imgNames & fn
                        end if
                    end try
                end repeat
            end try
            
            -- 1. テロップ枠の探索 (幅~1920, 高さ~225, スライド下部)
            set telopText to ""
            set foundTelop to false
            
            try
                repeat with sh in (shapes of s)
                    try
                        set w to width of sh
                        set h to height of sh
                        set pos to position of sh
                        set yPos to item 2 of pos
                        
                        -- 幅1700〜2100 かつ 高さ150〜300、または y座標700以上で幅1500以上の図形
                        if (w >= 1700 and w <= 2100 and h >= 150 and h <= 300) or (yPos >= 700 and w >= 1500) then
                            set foundTelop to true
                            set t to (object text of sh) as text
                            if t is not "" and t is not missing value then
                                if telopText is not "" then set telopText to telopText & linefeed
                                set telopText to telopText & t
                            end if
                        end if
                    end try
                end repeat
            end try
            
            -- テロップ枠図形自体にテキストがない場合、テロップ枠の領域 (y >= 700) にあるテキストアイテムを探索
            if foundTelop and telopText is "" then
                try
                    repeat with ti in (text items of s)
                        try
                            set pos to position of ti
                            set yPos to item 2 of pos
                            if yPos >= 700 then
                                set t to (object text of ti) as text
                                if t is not "" and t is not missing value then
                                    if telopText is not "" then set telopText to telopText & linefeed
                                    set telopText to telopText & t
                                end if
                            end if
                        end try
                    end repeat
                end try
            end if
            
            if foundTelop and telopText is not "" then
                set slideText to telopText
            else
                -- テロップ枠がないスライドは従来通りの抽出（全テキストアイテム＋図形）
                try
                    repeat with ti in (text items of s)
                        set t to (object text of ti) as text
                        if t is not "" and t is not missing value then
                            if slideText is not "" then set slideText to slideText & linefeed
                            set slideText to slideText & t
                        end if
                    end repeat
                end try
                
                try
                    repeat with sh in (shapes of s)
                        try
                            set t to (object text of sh) as text
                            if t is not "" and t is not missing value and slideText does not contain t then
                                if slideText is not "" then set slideText to slideText & linefeed
                                set slideText to slideText & t
                            end if
                        end try
                    end repeat
                end try
            end if
            
            -- get existing transition properties if any
            set tAutomatic to "false"
            set tDelay to 0.0
            set tDuration to 0.0
            set tEffect to "no transition effect"
            try
                set trProps to transition properties of s
                if automatic transition of trProps is true then
                    set tAutomatic to "true"
                end if
                set tDelay to (transition delay of trProps) as real
                set tDuration to (transition duration of trProps) as real
                set tEffect to (transition effect of trProps) as text
            end try
            
            set telopFlag to "false"
            if foundTelop then set telopFlag to "true"
            
            set end of resultList to (i as text) & "\\t" & (tDelay as text) & "\\t" & (tDuration as text) & "\\t" & tEffect & "\\t" & pNotes & "\\t" & imgNames & "\\t" & slideText & "\\t" & telopFlag & "\\t" & tAutomatic & "\\t" & tmplName
        end repeat
        
        close doc saving no
        
        set AppleScript's text item delimiters to "<<SLIDE_DELIM>>"
        return resultList as text
    end tell
    '''

    # Keynote が起動していない場合の自動起動とリトライ
    raw_output = ""
    for attempt in range(2):
        try:
            if attempt > 0 or "-600" in raw_output:
                subprocess.run(["open", "-a", keynote_app], capture_output=True)
                import time
                time.sleep(2.0)

            proc = subprocess.run(
                ["osascript", "-e", applescript_code],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=300
            )
            if proc.returncode != 0:
                err_msg = proc.stderr.strip()
                print(f"[ERROR] AppleScript failed (attempt {attempt + 1}): {err_msg}")
                if "-600" in err_msg and attempt == 0:
                    subprocess.run(["open", "-a", keynote_app], capture_output=True)
                    import time
                    time.sleep(2.5)
                    continue
                break

            raw_output = proc.stdout.strip()
            if raw_output:
                break
        except Exception as e:
            print(f"[ERROR] AppleScript execution error: {e}")
            if attempt == 0:
                subprocess.run(["open", "-a", keynote_app], capture_output=True)
                import time
                time.sleep(2.0)
                continue
            break

    # スライド画像 & アニメーションムービーのエクスポート先ディレクトリ
    base_name = os.path.splitext(os.path.basename(file_path))[0]
    slides_img_dir = os.path.join(get_media_dir(base_name, "スライド画像"), base_name)
    os.makedirs(slides_img_dir, exist_ok=True)

    slides_movie_dir = get_media_dir(base_name, "スライドムービー")
    os.makedirs(slides_movie_dir, exist_ok=True)
    target_movie_path = os.path.join(slides_movie_dir, f"{base_name}.mov")

    exported_imgs = sorted([
        os.path.join(slides_img_dir, f)
        for f in os.listdir(slides_img_dir)
        if f.lower().endswith(('.jpeg', '.jpg', '.png')) and not f.startswith('.')
    ])

    if not exported_imgs:
        for alt_parent in [os.path.join(PROJECT_ROOT, "幼き日の夢", "スライド画像"), os.path.join(PROJECT_ROOT, "スライド画像")]:
            alt_dir = os.path.join(alt_parent, base_name)
            if os.path.exists(alt_dir):
                exported_imgs = sorted([
                    os.path.join(alt_dir, f)
                    for f in os.listdir(alt_dir)
                    if f.lower().endswith(('.jpeg', '.jpg', '.png')) and not f.startswith('.')
                ])
                if exported_imgs:
                    break

    tts = get_tts_engine()

    # AppleScript が利用できない場合の Pure Python (.key パッケージ & 既存プロジェクト) 完全解析
    if not raw_output:
        # 1. 既存の同名プロジェクトファイル (.tpmproj) からの復元 & オブジェクト・尺同期の完全適用
        saved_scenes = None
        for cand_proj in [
            os.path.join(PROJECT_ROOT, f"{base_name}.tpmproj"),
            os.path.join(get_series_dir(base_name), f"{base_name}.tpmproj"),
            os.path.join(PROJECT_ROOT, "幼き日の夢", f"{base_name}.tpmproj")
        ]:
            if os.path.exists(cand_proj):
                try:
                    with open(cand_proj, "r", encoding="utf-8") as f:
                        pdata = json.load(f)
                    if pdata.get("scenes"):
                        saved_scenes = pdata["scenes"]
                        print(f"[INFO] Keynote AppleScript bypassed: Recovered {len(saved_scenes)} scenes from {cand_proj}, enriching with package objects and priority rules...")
                        break
                except Exception:
                    pass

        if saved_scenes:
            enriched_slides = []
            prev_slide_info = None
            for s in saved_scenes:
                s_idx = s.get("slide_index", 1)
                s_pkg = pkg_anims.get(s_idx, {})
                s_notes = s.get("notes") or s_pkg.get("notes", "")
                s_text = s.get("text") or s_pkg.get("slide_text", "")
                s_tmpl = s_pkg.get("template_name") or s.get("template_name", "標準")
                s_tmpl_info = s_pkg.get("template_info") or s.get("template_info", {})
                s_builds = s_pkg.get("builds") or s.get("builds", [])
                s_trans = s_pkg.get("transition") or {}

                # キャラクター画像の抽出・分類
                char_name = s.get("character", "操夢")
                char_imgs_str = s.get("character_images", "")

                anim_check = check_all_objects_animation(
                    slide_index=s_idx,
                    raw_script_text=s_notes if s_notes.strip() else s_text,
                    notes=s_notes,
                    text_content=s_text,
                    images_str=char_imgs_str,
                    trans_effect=s.get("transition_effect") or s_trans.get("effect", "no transition effect"),
                    trans_delay=float(s.get("transition_delay") or 0.0),
                    trans_duration=float(s.get("transition_duration") or 0.0),
                    found_telop=bool(s.get("telop_frame_detected") or (s_text and len(s_text) > 10)),
                    prev_slide_info=prev_slide_info,
                    assets_lib=assets_lib,
                    builds=s_builds,
                    automatic_transition=bool(s.get("transition_automatic")),
                    template_name=s_tmpl,
                    template_info=s_tmpl_info,
                    character_name=char_name
                )

                s["template_name"] = anim_check["template_name"]
                s["template_info"] = anim_check["template_info"]
                s["slide_objects"] = anim_check["slide_objects"]
                s["duration_priority_info"] = anim_check["duration_priority_info"]
                s["builds"] = s_builds
                s["target_duration"] = anim_check["final_target_duration"]
                s["extra_delay"] = anim_check["final_extra_delay"]
                s["has_animation"] = anim_check["has_animation"]
                s["animated_objects"] = anim_check["animated_objects"]
                s["animation_details"] = anim_check["animation_details"]

                enriched_slides.append(s)
                prev_slide_info = {
                    "bg_images": anim_check["bg_images"],
                    "char_images": anim_check["char_images"],
                    "telop_frame_detected": anim_check["telop_frame_detected"],
                    "text_content": s_text
                }
            return enriched_slides

        # 2. Keynote パッケージ iwa ファイルからの直接完全抽出 (純粋 Python)
        if pkg_anims:
            print(f"[INFO] Parsing all {len(pkg_anims)} slides directly from Keynote (.key) package...")
            extracted_slides = []
            prev_char = None
            prev_slide_info = None

            for slide_idx in sorted(pkg_anims.keys()):
                s_pkg = pkg_anims[slide_idx]
                s_notes = s_pkg.get("notes", "")
                s_text = s_pkg.get("slide_text", "")
                s_tmpl = s_pkg.get("template_name", "標準")
                s_tmpl_info = s_pkg.get("template_info", {})
                s_builds = s_pkg.get("builds", [])
                s_trans = s_pkg.get("transition") or {}

                raw_script_text = s_notes if s_notes.strip() else (s_text if s_text.strip() else f"スライド {slide_idx}")
                
                # 話者推定
                char_name, voice_type, speed, pitch = guess_character(
                    text=s_text,
                    notes=s_notes,
                    slide_idx=slide_idx,
                    image_names="",
                    prev_character=prev_char
                )
                prev_char = char_name

                anim_check = check_all_objects_animation(
                    slide_index=slide_idx,
                    raw_script_text=raw_script_text,
                    notes=s_notes,
                    text_content=s_text,
                    images_str="",
                    trans_effect=s_trans.get("effect", "no transition effect"),
                    trans_delay=0.0,
                    trans_duration=0.0,
                    found_telop=bool(s_text and len(s_text) > 10),
                    prev_slide_info=prev_slide_info,
                    assets_lib=assets_lib,
                    builds=s_builds,
                    automatic_transition=False,
                    template_name=s_tmpl,
                    template_info=s_tmpl_info,
                    character_name=char_name
                )

                # テキストクレンジング
                prefix_char, body_text = extract_speaker_prefix(anim_check["script_without_anim"])
                final_text = body_text if body_text else anim_check["script_without_anim"]

                corpus = get_corpus_engine()
                cached_phonemes = corpus.lookup_phonemes(final_text)
                koe = cached_phonemes if cached_phonemes else (tts.kanji2koe(final_text) if final_text else "")

                slide_img = exported_imgs[slide_idx - 1] if (slide_idx - 1) < len(exported_imgs) else ""

                extracted_slides.append({
                    "slide_index": slide_idx,
                    "text": final_text,
                    "notes": s_notes,
                    "character": char_name,
                    "voice": voice_type,
                    "speed": speed,
                    "pitch": pitch,
                    "phonemes": koe,
                    "extra_delay": anim_check["final_extra_delay"],
                    "transition_delay": 0.0,
                    "transition_duration": 0.0,
                    "transition_effect": s_trans.get("effect", "no transition effect"),
                    "transition_automatic": False,
                    "template_name": anim_check["template_name"],
                    "template_info": anim_check["template_info"],
                    "slide_objects": anim_check["slide_objects"],
                    "duration_priority_info": anim_check["duration_priority_info"],
                    "builds": s_builds,
                    "target_duration": anim_check["final_target_duration"],
                    "is_animation_sync": anim_check["is_animation_sync"],
                    "has_animation": anim_check["has_animation"],
                    "animated_objects": anim_check["animated_objects"],
                    "animation_details": anim_check["animation_details"],
                    "character_images": "",
                    "bg_images": [],
                    "telop_frame_detected": anim_check["telop_frame_detected"],
                    "audio_duration": 0.0,
                    "audio_file": f"slide_{slide_idx:03d}.wav",
                    "image_path": slide_img,
                    "video_clip_path": None,
                    "animation_path": None,
                    "video_start_time": 0.0,
                    "video_duration": anim_check["final_target_duration"] if anim_check["has_animation"] else None,
                    "animation_duration": anim_check["final_target_duration"] if anim_check["has_animation"] else None,
                    "is_enabled": True
                })

            if extracted_slides:
                return extracted_slides

    slides_raw = raw_output.split("<<SLIDE_DELIM>>")

    # 1. スライド画像の一括エクスポート (Keynote AppleScript)
    if len(exported_imgs) < len(slides_raw):
        try:
            escaped_img_dir = slides_img_dir.replace('\\', '\\\\').replace('"', '\\"')
            export_script = f'''
            tell application "{keynote_app}"
                set docPath to POSIX file "{escaped_file_path}"
                set doc to open file docPath
                set outFolder to POSIX file "{escaped_img_dir}"
                export doc as slide images to file outFolder with properties {{image format:JPEG, skipped slides:false}}
                close doc saving no
                return "SUCCESS"
            end tell
            '''
            proc_exp = subprocess.run(["osascript", "-e", export_script], capture_output=True, text=True, timeout=180)
            if proc_exp.returncode != 0 and "-600" in proc_exp.stderr:
                subprocess.run(["open", "-a", keynote_app], capture_output=True)
                import time
                time.sleep(2.0)
                subprocess.run(["osascript", "-e", export_script], capture_output=True, text=True, timeout=180)
        except Exception as ex_img:
            print(f"[WARN] Failed to export slide images: {ex_img}")

    extracted_slides = []
    prev_char = None
    prev_slide_info = None

    for idx_raw, item in enumerate(slides_raw):
        if not item or not item.strip():
            continue

        parts = item.split("\t")
        if len(parts) < 10:
            parts += [""] * (10 - len(parts))

        try:
            slide_idx = int(parts[0].strip())
        except ValueError:
            slide_idx = idx_raw + 1

        try:
            trans_delay = float(parts[1].strip())
        except ValueError:
            trans_delay = 0.0

        try:
            trans_duration = float(parts[2].strip())
        except ValueError:
            trans_duration = 0.0

        trans_effect = parts[3].strip()
        notes = parts[4].strip()
        images_str = parts[5].strip()
        text_content = parts[6].strip()
        found_telop = (parts[7].strip().lower() == "true")
        automatic_trans = (parts[8].strip().lower() == "true")
        tmpl_from_as = parts[9].strip()

        # パッケージ解析からのビルドアニメーション取得
        slide_pkg_data = pkg_anims.get(slide_idx, {})
        slide_builds = slide_pkg_data.get("builds", [])
        slide_tmpl_name = tmpl_from_as if tmpl_from_as else slide_pkg_data.get("template_name", "標準")
        slide_tmpl_info = slide_pkg_data.get("template_info", {})

        # セリフ本文の選定: 発表者ノート (Presenter Notes) が存在すれば最優先で利用
        if notes and notes.strip():
            raw_script_text = notes.strip()
        else:
            raw_script_text = text_content.strip()

        # キャラクター超高精度推定（「動画用」フォルダの立ち絵情報も統合）
        char_name, voice_type, speed, pitch = guess_character(
            text=text_content,
            notes=notes,
            slide_idx=slide_idx,
            image_names=images_str,
            prev_character=prev_char
        )
        prev_char = char_name

        # 全オブジェクト（キャラクター、テロップ枠、テキスト、図形、テンプレート、ビルド、トランジション）の包括的走査 & 時間優先適用
        anim_check = check_all_objects_animation(
            slide_index=slide_idx,
            raw_script_text=raw_script_text,
            notes=notes,
            text_content=text_content,
            images_str=images_str,
            trans_effect=trans_effect,
            trans_delay=trans_delay,
            trans_duration=trans_duration,
            found_telop=found_telop,
            prev_slide_info=prev_slide_info,
            assets_lib=assets_lib,
            builds=slide_builds,
            automatic_transition=automatic_trans,
            template_name=slide_tmpl_name,
            template_info=slide_tmpl_info,
            character_name=char_name
        )

        has_animation = anim_check["has_animation"]
        animated_objects = anim_check["animated_objects"]
        animation_details = anim_check["animation_details"]
        char_imgs = anim_check["char_images"]
        char_imgs_str = ", ".join(char_imgs)
        bg_imgs = anim_check["bg_images"]
        final_target_duration = anim_check["final_target_duration"]
        final_extra_delay = anim_check["final_extra_delay"]
        is_anim_sync = anim_check["is_animation_sync"]
        script_without_anim = anim_check["script_without_anim"]

        # スライド画像の割り当て
        slide_image_path = ""
        if idx_raw < len(exported_imgs):
            slide_image_path = exported_imgs[idx_raw]
        else:
            # 番号一致の探索
            for img_p in exported_imgs:
                fn = os.path.basename(img_p)
                if f".{slide_idx:03d}." in fn or f"_{slide_idx:03d}." in fn or f"{slide_idx}." in fn:
                    slide_image_path = img_p
                    break

        # テキストを行ごとに整理・重複排除
        lines = [line.strip() for line in script_without_anim.split("\n") if line.strip()]
        
        unique_lines = []
        for l in lines:
            if l not in unique_lines:
                unique_lines.append(l)

        cleaned_text = "\n".join(unique_lines)

        # 話者プレフィックスの抽出 & 本文のクレンジング
        prefix_char, body_text = extract_speaker_prefix(cleaned_text)
        final_text = body_text if body_text else cleaned_text

        # 音声記号列の生成（過去作コーパスの記号列を優先再利用）
        corpus = get_corpus_engine()
        cached_phonemes = corpus.lookup_phonemes(final_text)
        koe = ""
        if cached_phonemes:
            koe = cached_phonemes
        elif final_text:
            koe = tts.kanji2koe(final_text)

        # スライド動画クリップ (slide_XXX.mp4) の判定（has_animation が True の場合のみ探索・バインド）
        slide_video_clip = None
        if has_animation:
            slide_clip_dir = os.path.join(get_media_dir(base_name, "スライド動画"), base_name)
            cand_clip_paths = [
                os.path.join(slide_clip_dir, f"slide_{slide_idx:03d}.mp4"),
                os.path.join(slide_clip_dir, f"slide_{slide_idx:03d}.mov"),
                os.path.join(slide_clip_dir, f"slide_{slide_idx}.mp4"),
            ]
            for ccp in cand_clip_paths:
                if os.path.exists(ccp) and os.path.getsize(ccp) > 1000:
                    slide_video_clip = ccp
                    break
        else:
            has_animation = False
            slide_video_clip = None

        extracted_slides.append({
            "slide_index": slide_idx,
            "text": final_text,
            "notes": notes,
            "character": char_name,
            "voice": voice_type,
            "speed": speed,
            "pitch": pitch,
            "phonemes": koe,
            "extra_delay": final_extra_delay,
            "transition_delay": trans_delay,
            "transition_duration": trans_duration,
            "transition_effect": trans_effect,
            "transition_automatic": automatic_trans,
            "template_name": anim_check["template_name"],
            "template_info": anim_check["template_info"],
            "slide_objects": anim_check["slide_objects"],
            "duration_priority_info": anim_check["duration_priority_info"],
            "builds": slide_builds,
            "target_duration": final_target_duration,
            "is_animation_sync": is_anim_sync,
            "has_animation": has_animation,
            "animated_objects": animated_objects,
            "animation_details": animation_details,
            "character_images": char_imgs_str,
            "bg_images": bg_imgs,
            "telop_frame_detected": anim_check["telop_frame_detected"],
            "audio_duration": 0.0,
            "audio_file": f"slide_{slide_idx:03d}.wav",
            "image_path": slide_image_path,
            "video_clip_path": slide_video_clip if has_animation else None,
            "animation_path": slide_video_clip if has_animation else None,
            "video_start_time": 0.0,
            "video_duration": final_target_duration if has_animation else None,
            "animation_duration": final_target_duration if has_animation else None,
            "is_enabled": True
        })

        # 次のスライドの比較用情報
        prev_slide_info = {
            "bg_images": bg_imgs,
            "char_images": char_imgs,
            "telop_frame_detected": anim_check["telop_frame_detected"],
            "text_content": text_content
        }

    # スライドムービーが存在する場合は、アニメーションが必要なスライドのみ動画クリップを切り出し
    if os.path.exists(target_movie_path) and os.path.getsize(target_movie_path) > 10000:
        extracted_slides = slice_slides_from_movie(target_movie_path, extracted_slides, base_name)

    return extracted_slides



def export_keynote_slide_images(keynote_path: str, force: bool = True) -> List[str]:
    """
    Keynoteファイルからスライド画像のみをエクスポートし、ファイルパスリストを返す。
    """
    if not os.path.exists(keynote_path):
        return []

    keynote_app = get_keynote_app_name()
    base_name = os.path.splitext(os.path.basename(keynote_path))[0]
    slides_img_dir = os.path.join(get_media_dir(base_name, "スライド画像"), base_name)
    os.makedirs(slides_img_dir, exist_ok=True)

    escaped_file_path = keynote_path.replace('\\', '\\\\').replace('"', '\\"')
    escaped_img_dir = slides_img_dir.replace('\\', '\\\\').replace('"', '\\"')

    try:
        subprocess.run(["open", "-a", keynote_app], capture_output=True)
        import time
        time.sleep(2.0)
        export_script = f'''
        tell application "{keynote_app}"
            activate
            set docPath to POSIX file "{escaped_file_path}"
            set doc to open file docPath
            delay 1
            set outFolder to POSIX file "{escaped_img_dir}"
            export doc as slide images to file outFolder with properties {{image format:JPEG, skipped slides:false}}
            close doc saving no
            return "SUCCESS"
        end tell
        '''
        subprocess.run(["osascript", "-e", export_script], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    except Exception as ex:
        print(f"[WARN] export_keynote_slide_images error: {ex}")

    return sorted([
        os.path.join(slides_img_dir, f)
        for f in os.listdir(slides_img_dir)
        if f.lower().endswith(('.jpeg', '.jpg', '.png')) and not f.startswith('.')
    ])


def export_keynote_media_refresh(keynote_path: str) -> Dict[str, Any]:
    """
    Keynoteファイルからスライド画像およびアニメーション付きQuickTimeムービーを一括再生成する。
    セリフや音声設定、SE/BGMを保持したまま、画像と動画のみを最新状態に同期するために使用。
    """
    if not os.path.exists(keynote_path):
        return {"success": False, "error": f"Keynote file not found: {keynote_path}"}

    keynote_app = get_keynote_app_name()
    base_name = os.path.splitext(os.path.basename(keynote_path))[0]
    slides_img_dir = os.path.join(get_media_dir(base_name, "スライド画像"), base_name)
    os.makedirs(slides_img_dir, exist_ok=True)

    escaped_file_path = keynote_path.replace('\\', '\\\\').replace('"', '\\"')
    escaped_img_dir = slides_img_dir.replace('\\', '\\\\').replace('"', '\\"')

    slides_movie_dir = get_media_dir(base_name, "スライドムービー")
    os.makedirs(slides_movie_dir, exist_ok=True)
    target_movie_path = os.path.join(slides_movie_dir, f"{base_name}.mov")
    escaped_mov_path = target_movie_path.replace('\\', '\\\\').replace('"', '\\"')

    # 既存画像を確認（すでに画像があればKeynoteの無理な再呼び出しを避けてクラッシュを完全に回避）
    existing_imgs = [
        os.path.join(slides_img_dir, f)
        for f in os.listdir(slides_img_dir)
        if f.lower().endswith(('.jpeg', '.jpg', '.png')) and not f.startswith('.')
    ]

    # 画像が未生成の場合のみ、Keynoteから安全にエクスポート
    if len(existing_imgs) == 0:
        try:
            subprocess.run(["open", "-a", keynote_app], capture_output=True)
            import time
            time.sleep(2.0)

            # 1. スライド画像の一括再エクスポート
            export_img_script = f'''
            tell application "{keynote_app}"
                activate
                set docPath to POSIX file "{escaped_file_path}"
                set doc to open file docPath
                delay 3
                set outFolder to POSIX file "{escaped_img_dir}"
                export doc as slide images to file outFolder with properties {{image format:JPEG, compression factor:80, skipped slides:false}}
                delay 2
                close doc saving no
                return "SUCCESS"
            end tell
            '''
            proc_img = subprocess.run(["osascript", "-e", export_img_script], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
            if proc_img.returncode != 0 and "-600" in proc_img.stderr:
                subprocess.run(["open", "-a", keynote_app], capture_output=True)
                time.sleep(2.0)
                subprocess.run(["osascript", "-e", export_img_script], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
        except Exception as ex:
            print(f"[WARN] export_keynote_media_refresh error: {ex}")

    images = sorted([
        os.path.join(slides_img_dir, f)
        for f in os.listdir(slides_img_dir)
        if f.lower().endswith(('.jpeg', '.jpg', '.png')) and not f.startswith('.')
    ])

    # 2. スライド動画（アニメーションムービー）の生成
    try:
        print(f"[INFO] Exporting native animated QuickTime movie from Keynote: {target_movie_path}...")
        export_mov_script = f'''
        tell application "{keynote_app}"
            activate
            set docPath to POSIX file "{escaped_file_path}"
            set doc to open file docPath
            set outPath to POSIX file "{escaped_mov_path}"
            try
                export doc to file outPath as QuickTime movie with properties {{movie format:large}}
                close doc saving no
                return "SUCCESS"
            on error errMsg
                try
                    export doc to file outPath as QuickTime movie
                    close doc saving no
                    return "SUCCESS"
                on error errMsg2
                    close doc saving no
                    return "ERROR: " & errMsg2
                end try
            end try
        end tell
        '''
        proc_mov = subprocess.run(["osascript", "-e", export_mov_script], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
        if proc_mov.returncode != 0 or "ERROR:" in proc_mov.stdout:
            print(f"[WARN] Keynote native movie export failed: {proc_mov.stdout} {proc_mov.stderr}")
    except Exception as ex_mov:
        print(f"[WARN] Failed to export native movie from Keynote: {ex_mov}")

    # フォールバック: Keynote書き出しが失敗した場合は画像からffmpeg生成
    if (not os.path.exists(target_movie_path) or os.path.getsize(target_movie_path) < 10000) and images:
        try:
            print(f"[INFO] Fallback: Building 60fps high quality slide movie for {len(images)} slides: {target_movie_path}...")
            concat_tmp = os.path.join(slides_movie_dir, f"{base_name}_concat.txt")
            with open(concat_tmp, "w", encoding="utf-8") as f:
                for img in images:
                    f.write(f"file '{img}'\n")
                    f.write(f"duration 3.0\n")
                if images:
                    f.write(f"file '{images[-1]}'\n")

            cmd_mov = [
                "ffmpeg", "-y",
                "-f", "concat", "-safe", "0", "-i", concat_tmp,
                "-vf", "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p,fps=60",
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "fast", "-crf", "18",
                "-movflags", "+faststart",
                target_movie_path
            ]
            subprocess.run(cmd_mov, capture_output=True, timeout=300)

            if os.path.exists(concat_tmp):
                try: os.remove(concat_tmp)
                except Exception: pass
        except Exception as e_mov:
            print(f"[WARN] Slide movie generation error: {e_mov}")

    return {
        "success": True,
        "images": images,
        "video_source": target_movie_path if (os.path.exists(target_movie_path) and os.path.getsize(target_movie_path) > 10000) else None,
        "images_count": len(images)
    }


def slice_slides_from_movie(movie_path: str, scenes: List[Dict[str, Any]], base_name: str) -> List[Dict[str, Any]]:
    """
    Keynoteスライドムービー (.mov/.mp4) から各スライドのアニメーション区間を切り出し、
    ブラウザで確実に再生可能な H.264 MP4 クリップ (slide_001.mp4 ...) を生成して各シーンに紐づける。
    【重要】ノート欄にアニメーションや表示時間の明示指示があるスライドのみ動画クリップを生成・紐付けし、
    セリフのみのスライドは静止画像として保持（古い動画クリップは削除・バインド解除）。
    """
    if not scenes or not isinstance(scenes, list):
        return scenes if isinstance(scenes, list) else []

    if not os.path.exists(movie_path):
        # 動画ソースが存在しない場合、アニメーション指示のないシーンを画像モードに整流
        for s in scenes:
            if isinstance(s, dict):
                n_str = str(s.get("notes") or "")
                t_str = str(s.get("text") or "")
                if not has_animation_instruction(n_str, t_str):
                    s["video_clip_path"] = None
                    s["animation_path"] = None
                    s["video_duration"] = None
                    s["animation_duration"] = None
                    s["target_duration"] = None
                    s["extra_delay"] = 0.0
                    s["has_animation"] = False
        return scenes

    out_dir = os.path.join(get_media_dir(base_name, "スライド動画"), base_name)
    os.makedirs(out_dir, exist_ok=True)

    # 全体の動画尺を取得
    cmd_dur = ["ffprobe", "-v", "quiet", "-show_entries", "format=duration", "-of", "csv=p=0", movie_path]
    res_dur = subprocess.run(cmd_dur, capture_output=True, text=True, encoding="utf-8", errors="replace")
    try:
        total_mov_dur = float(res_dur.stdout.strip())
    except Exception:
        total_mov_dur = len(scenes) * 4.0

    avg_dur = max(1.0, total_mov_dur / max(1, len(scenes)))
    cur_movie_time = 0.0

    for idx, scene in enumerate(scenes):
        if not isinstance(scene, dict):
            continue
        s_idx = scene.get("slide_index", idx + 1)
        clip_name = f"slide_{s_idx:03d}.mp4"
        clip_path = os.path.join(out_dir, clip_name)

        # 1. Keynote設定のトランジション遅延・持続時間
        try:
            t_delay = float(scene.get("transition_delay") or 0.0)
        except (ValueError, TypeError):
            t_delay = 0.0
        try:
            t_duration = float(scene.get("transition_duration") or 0.0)
        except (ValueError, TypeError):
            t_duration = 0.0
        slide_actual_dur = (t_delay + t_duration) if (t_delay + t_duration) > 0 else 0.0

        # Keynote ムービー内でのこのスライドの尺
        k_slide_dur = slide_actual_dur if slide_actual_dur > 0 else avg_dur
        slide_mov_start = cur_movie_time

        # 2. 発表者ノートに指定された目標時間・アニメーション時間・セリフ音声尺
        raw_target_dur = scene.get("target_duration") or scene.get("animation_duration")
        try:
            raw_target_val = float(raw_target_dur) if raw_target_dur is not None else 0.0
        except (ValueError, TypeError):
            raw_target_val = 0.0

        try:
            audio_dur_val = float(scene.get("audio_duration") or 0.0)
        except (ValueError, TypeError):
            audio_dur_val = 0.0

        try:
            extra_delay_val = float(scene.get("extra_delay") or 0.0)
        except (ValueError, TypeError):
            extra_delay_val = 0.0

        if raw_target_val > 0:
            clip_dur = min(max(1.0, raw_target_val), 120.0)
        elif audio_dur_val > 0 and extra_delay_val > 0:
            clip_dur = max(audio_dur_val + extra_delay_val + 0.05, k_slide_dur)
        elif k_slide_dur > 0:
            clip_dur = k_slide_dur
        else:
            clip_dur = avg_dur

        # アニメーション指示・ビルドアニメーション・自動トランジションがあるかどうかの包括判定
        notes_str = str(scene.get("notes") or "")
        text_str = str(scene.get("text") or "")
        s_builds = scene.get("builds", [])
        s_has_auto = bool(scene.get("transition_automatic") and float(scene.get("transition_delay") or 0.0) > 0)
        is_animated = bool(scene.get("has_animation") or has_animation_instruction(notes_str, text_str, builds=s_builds, has_transition=s_has_auto))

        if is_animated:
            # アニメーション指定あり: Keynoteムービーの正確な開始位置からH.264 MP4クリップを切り出し
            scene["video_start_time"] = 0.0
            scene["video_duration"] = round(clip_dur, 3)
            scene["animation_duration"] = round(clip_dur, 3)
            scene["has_animation"] = True

            if not os.path.exists(clip_path) or os.path.getsize(clip_path) < 1000:
                if os.path.exists(movie_path) and os.path.getsize(movie_path) > 10000:
                    # 正確な slide_mov_start 位置から切り出し (yuv420p, +faststart でWebプレビュー完全互換)
                    cmd = [
                        "ffmpeg", "-y",
                        "-ss", f"{slide_mov_start:.3f}",
                        "-i", movie_path,
                        "-t", f"{clip_dur:.3f}",
                        "-vf", "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p,fps=60",
                        "-c:v", "libx264", "-preset", "ultrafast", "-crf", "20",
                        "-pix_fmt", "yuv420p",
                        "-movflags", "+faststart",
                        "-an",
                        clip_path
                    ]
                    subprocess.run(cmd, capture_output=True)

            if os.path.exists(clip_path) and os.path.getsize(clip_path) > 1000:
                scene["video_clip_path"] = clip_path
                scene["animation_path"] = clip_path
            else:
                scene["video_clip_path"] = None
                scene["animation_path"] = None
        else:
            # アニメーション指示なし（セリフのみ）: すべて画像として扱い、余白をゼロにして音声長に合わせる
            scene["video_clip_path"] = None
            scene["animation_path"] = None
            scene["video_duration"] = None
            scene["animation_duration"] = None
            scene["target_duration"] = None
            scene["extra_delay"] = 0.0
            scene["has_animation"] = False
            scene["video_start_time"] = 0.0

            # 過去の古いクリップファイルがあれば削除
            if os.path.exists(clip_path):
                try:
                    os.remove(clip_path)
                except Exception:
                    pass

        cur_movie_time += k_slide_dur
        if cur_movie_time >= total_mov_dur:
            cur_movie_time = 0.0

    return scenes

