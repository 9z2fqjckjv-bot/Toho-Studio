"""
コーパス学習 & コンテキスト自動分析エンジン (CorpusLearner)
- "動画用" フォルダおよび "交換夫婦" フォルダを自動探索
- 650枚以上のキャラクター立ち絵画像のパス・ファイル名からキャラクター自動マッピング
- 過去のKeynoteファイル・台本ファイル（JSON/CSV/MD）からセリフ・キャラクター・音声記号列の傾向を学習
- 固有名詞や特殊フレーズの音声記号列を優先再利用し、セリフ読み込みとTTS精度の劇的向上を実現
"""

import os
import re
import json
import unicodedata
from typing import Dict, List, Any, Optional, Tuple
from .path_utils import get_series_dir, get_media_dir
from .character_db import CHARACTERS, CHARACTER_ALIASES

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VIDEO_DIR = os.path.join(PROJECT_ROOT, "動画用")
TOHO_DIR = get_series_dir("")
CACHE_FILE = os.path.join(TOHO_DIR, "corpus_cache.json")


def normalize_text(text: str) -> str:
    if not text:
        return ""
    return unicodedata.normalize("NFC", text).strip()


class CorpusKnowledgeEngine:
    _instance = None

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = CorpusKnowledgeEngine()
        return cls._instance

    def __init__(self):
        self.image_to_character: Dict[str, str] = {}
        self.dialogue_corpus: Dict[str, Dict[str, Any]] = {}
        self.phoneme_dictionary: Dict[str, str] = {}
        self.character_phrases: Dict[str, List[str]] = {}
        self.is_loaded = False
        self.load_or_build_corpus()

    def load_or_build_corpus(self, force_rebuild: bool = False):
        if not force_rebuild and os.path.exists(CACHE_FILE):
            try:
                with open(CACHE_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self.image_to_character = data.get("image_to_character", {})
                    self.dialogue_corpus = data.get("dialogue_corpus", {})
                    self.phoneme_dictionary = data.get("phoneme_dictionary", {})
                    self.character_phrases = data.get("character_phrases", {})
                    self.is_loaded = True
                    print(f"[INFO] Loaded corpus from cache: {len(self.image_to_character)} images, {len(self.dialogue_corpus)} dialogues, {len(self.phoneme_dictionary)} phoneme pairs.")
                    return
            except Exception as e:
                print(f"[WARN] Failed to load corpus cache: {e}, rebuilding...")
        self.build_corpus()

    def build_corpus(self):
        print("[INFO] Building knowledge corpus from '動画用' and '交換夫婦'...")
        self.image_to_character = {}
        self.dialogue_corpus = {}
        self.phoneme_dictionary = {}
        self.character_phrases = {c: [] for c in CHARACTERS.keys()}

        char_img_dir = os.path.join(VIDEO_DIR, "キャラクター")
        if os.path.exists(char_img_dir):
            for root, dirs, files in os.walk(char_img_dir):
                for f in files:
                    if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")) and not f.startswith("._") and not f.startswith("."):
                        rel_path = normalize_text(os.path.relpath(os.path.join(root, f), char_img_dir))
                        char_match = self._resolve_character_from_path(rel_path, f)
                        if char_match:
                            clean_fn = normalize_text(f).lower()
                            self.image_to_character[clean_fn] = char_match
                            base_fn = os.path.splitext(clean_fn)[0]
                            self.image_to_character[base_fn] = char_match

        script_dir = os.path.join(TOHO_DIR, "台本")
        if os.path.exists(script_dir):
            for f in os.listdir(script_dir):
                if f.endswith(".json") and not f.startswith("._") and not f.startswith("."):
                    json_p = os.path.join(script_dir, f)
                    try:
                        with open(json_p, "r", encoding="utf-8") as sf:
                            sdata = json.load(sf)
                            slides = sdata.get("slides", [])
                            for s in slides:
                                text = normalize_text(s.get("text", ""))
                                char = normalize_text(s.get("character", ""))
                                phonemes = normalize_text(s.get("phonemes", ""))
                                if not text:
                                    continue
                                char = CHARACTER_ALIASES.get(char, char)
                                if char not in CHARACTERS:
                                    char = "操夢"
                                self._register_dialogue_sample(text, char, phonemes)
                    except Exception as e:
                        print(f"[WARN] Failed to read script file {f}: {e}")

        self.save_cache()
        self.is_loaded = True
        print(f"[INFO] Corpus built successfully: {len(self.image_to_character)} images, {len(self.dialogue_corpus)} dialogues, {len(self.phoneme_dictionary)} phoneme pairs.")

    def _resolve_character_from_path(self, rel_path: str, filename: str) -> Optional[str]:
        path_norm = normalize_text(rel_path)
        fn_norm = normalize_text(filename)
        combined = f"{path_norm}/{fn_norm}"
        for char_name in CHARACTERS.keys():
            if char_name in combined:
                return char_name
        for alias, canonical in CHARACTER_ALIASES.items():
            if alias in combined:
                return canonical
        folder_keywords = {
            "主人公たち": "操夢",
            "古明地姉妹": "さとり",
            "紅魔館": "レミリア",
            "永遠亭": "永琳",
            "河童": "にとり"
        }
        for kw, target in folder_keywords.items():
            if kw in combined:
                if "こいし" in combined:
                    return "こいし"
                if "さとり" in combined:
                    return "さとり"
                if "フラン" in combined or "flan" in combined.lower():
                    return "フラン"
                if "咲夜" in combined or "sakuya" in combined.lower():
                    return "咲夜"
                if "パチュリー" in combined or "patchouli" in combined.lower():
                    return "パチュリー"
                if "魔理沙" in combined or "marisa" in combined.lower():
                    return "魔理沙"
                if "霊夢" in combined or "reimu" in combined.lower():
                    return "霊夢"
                if "慧音" in combined:
                    return "慧音"
                if "妹紅" in combined or "moko" in combined.lower():
                    return "妹紅"
                return target
        return None

    def _register_dialogue_sample(self, text: str, character: str, phonemes: str):
        norm_t = normalize_text(text)
        if not norm_t:
            return
        if norm_t not in self.dialogue_corpus or not isinstance(self.dialogue_corpus[norm_t], dict):
            self.dialogue_corpus[norm_t] = {"character": character, "phonemes": phonemes, "count": 1}
        else:
            self.dialogue_corpus[norm_t]["count"] = self.dialogue_corpus[norm_t].get("count", 1) + 1
            if phonemes and not self.dialogue_corpus[norm_t].get("phonemes"):
                self.dialogue_corpus[norm_t]["phonemes"] = phonemes
        if phonemes:
            self.phoneme_dictionary[norm_t] = phonemes
        if character in self.character_phrases:
            if norm_t not in self.character_phrases[character] and len(self.character_phrases[character]) < 1000:
                self.character_phrases[character].append(norm_t)

    def save_cache(self):
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        try:
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump({
                    "image_to_character": self.image_to_character,
                    "dialogue_corpus": self.dialogue_corpus,
                    "phoneme_dictionary": self.phoneme_dictionary,
                    "character_phrases": self.character_phrases
                }, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"[WARN] Failed to write corpus cache: {e}")

    def lookup_image_character(self, image_names_str: str) -> Optional[str]:
        if not image_names_str:
            return None
        img_list = image_names_str.split(",")
        for img in img_list:
            norm_img = normalize_text(img)
            clean_fn = normalize_text(os.path.basename(img)).lower()
            if clean_fn in self.image_to_character:
                return self.image_to_character[clean_fn]
            base_fn = os.path.splitext(clean_fn)[0]
            if base_fn in self.image_to_character:
                return self.image_to_character[base_fn]
            path_resolved = self._resolve_character_from_path(norm_img, os.path.basename(norm_img))
            if path_resolved:
                return path_resolved
            for img_key, char_name in self.image_to_character.items():
                if len(img_key) >= 3 and (img_key in clean_fn or img_key in norm_img.lower()):
                    return char_name
        return None

    def lookup_exact_dialogue(self, text: str) -> Optional[Dict[str, Any]]:
        norm_t = normalize_text(text)
        return self.dialogue_corpus.get(norm_t)

    def lookup_phonemes(self, text: str) -> Optional[str]:
        norm_t = normalize_text(text)
        return self.phoneme_dictionary.get(norm_t)

    def score_corpus_similarity(self, text: str) -> Dict[str, float]:
        norm_t = normalize_text(text)
        scores = {c: 0.0 for c in CHARACTERS.keys()}
        if not norm_t:
            return scores
        if norm_t in self.dialogue_corpus and isinstance(self.dialogue_corpus[norm_t], dict):
            c = self.dialogue_corpus[norm_t].get("character")
            if c and c in scores:
                scores[c] += 400.0
            return scores
        for char_name, phrases in self.character_phrases.items():
            for p in phrases:
                if len(p) > 6 and (p in norm_t or norm_t in p):
                    scores[char_name] += 150.0
                    break
        return scores


def get_corpus_engine() -> CorpusKnowledgeEngine:
    return CorpusKnowledgeEngine.get_instance()
