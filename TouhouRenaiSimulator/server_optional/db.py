#!/usr/bin/env python3
"""
省リソース SQLite ミニデータベース & カタログ管理 (db.py)
【外部素材クライアントローカル参照方式】:
  - 立ち絵・背景の外部画像ファイルはホストサーバーからは一切配信せず、DBにも画像パスを保持しない
  - サーバーSQLiteは「キャラクター定義・AquesTalk1声種設定」「性格50種マスター」「ユーザー・課金台帳」のみを軽量管理（約100KB）
"""

import os
import re
import sys
import json
import math
import sqlite3
import threading
import unicodedata
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

SERVER_DIR = os.path.abspath(os.path.dirname(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SERVER_DIR, ".."))
DEFAULT_DOC_ROOT = os.path.abspath(os.path.join(PROJECT_ROOT, ".."))
DOC_ROOT = os.environ.get("DOC_ROOT") or (
    "~/Documents" if os.path.exists("~/Documents") else DEFAULT_DOC_ROOT
)

DATA_DIR = os.path.join(SERVER_DIR, "data")
DB_PATH = os.path.join(DATA_DIR, "touhou_renai.sqlite3")
PERSONALITY_JSON_PATH = os.path.join(DATA_DIR, "personality_catalog.json")

SERIF_MAKER_DIR = os.path.join(DOC_ROOT, "キャラセリフメーカー")
HARUKA_DIR = os.path.join(DOC_ROOT, "はるか式立ち絵")

os.makedirs(DATA_DIR, exist_ok=True)

_DB_WRITE_LOCK = threading.Lock()

# Keynote Slide 19: プロンプト価格表（全10プラン・3ページ構成・月間購入制限付き）
PROMPT_PLANS: List[Dict[str, Any]] = [
    {"id": "p10", "prompts": 10, "price_yen": 100, "unit_yen": 10.0, "monthly_limit": None, "page": 1, "tagline": "お試し利用に最適"},
    {"id": "p20", "prompts": 20, "price_yen": 200, "unit_yen": 10.0, "monthly_limit": None, "page": 1, "tagline": "短時間利用なら"},
    {"id": "p50", "prompts": 50, "price_yen": 400, "unit_yen": 8.0, "monthly_limit": None, "page": 1, "tagline": "10prompt分お得"},
    {"id": "p100", "prompts": 100, "price_yen": 800, "unit_yen": 8.0, "monthly_limit": None, "page": 1, "tagline": "ボリューミー"},
    {"id": "p200", "prompts": 200, "price_yen": 1200, "unit_yen": 6.0, "monthly_limit": None, "page": 2, "tagline": "さらにコスパアップ"},
    {"id": "p500", "prompts": 500, "price_yen": 1500, "unit_yen": 3.0, "monthly_limit": None, "page": 2, "tagline": "一番人気の高コスパ"},
    {"id": "p1000", "prompts": 1000, "price_yen": 2000, "unit_yen": 2.0, "monthly_limit": 3, "page": 2, "tagline": "毎日たっぷり話せる"},
    {"id": "p2000", "prompts": 2000, "price_yen": 3000, "unit_yen": 1.5, "monthly_limit": 2, "page": 2, "tagline": "長期間の相棒に"},
    {"id": "p5000", "prompts": 5000, "price_yen": 4000, "unit_yen": 0.8, "monthly_limit": 1, "page": 3, "tagline": "限界突破の大容量"},
    {"id": "p10000", "prompts": 10000, "price_yen": 5000, "unit_yen": 0.5, "monthly_limit": 1, "page": 3, "tagline": "最安値・究極のまとめ買い"},
]
PROMPT_PLANS_MAP = {p["id"]: p for p in PROMPT_PLANS}

# Keynote Slide 20: オートチャージプラン（8選択肢）
AUTO_CHARGE_PLANS: List[Dict[str, Any]] = [
    {"id": "ac1", "prompts": 1, "price_yen": 10, "label": "1prompt : ¥10"},
    {"id": "ac10", "prompts": 10, "price_yen": 100, "label": "10prompt : ¥100"},
    {"id": "ac20", "prompts": 20, "price_yen": 200, "label": "20prompt : ¥200"},
    {"id": "ac50", "prompts": 50, "price_yen": 400, "label": "50prompt : ¥400"},
    {"id": "ac100", "prompts": 100, "price_yen": 800, "label": "100prompt : ¥800"},
    {"id": "ac200", "prompts": 200, "price_yen": 800, "label": "200prompt : ¥800"},
    {"id": "ac500", "prompts": 500, "price_yen": 800, "label": "500prompt : ¥800"},
    {"id": "none", "prompts": 0, "price_yen": 0, "label": "オートチャージなし"},
]
AUTO_CHARGE_MAP = {p["id"]: p for p in AUTO_CHARGE_PLANS}

# Keynote Slide 21: デポジット追加代金
DEPOSIT_OPTIONS_YEN: List[int] = [500, 1000, 2000, 3000, 5000, 10000]
BG_GENERATION_COST_YEN = 100
DEFAULT_VOICE_TRIAL_TURNS = 5

# AI料金とは独立した AquesTalk1 ライセンス実費回収プラン（期間パス ＋ 従量セリフ枠のハイブリッド）
VOICE_PLANS: List[Dict[str, Any]] = [
    {"id": "vp_30d", "kind": "pass", "days": 30, "credits": 0, "price_yen": 200, "label": "30日間フルボイスパス : ¥200", "desc": "30日間回数無制限でAquesTalk1ボイス再生"},
    {"id": "vp_365d", "kind": "pass", "days": 365, "credits": 0, "price_yen": 1200, "label": "1年間フルボイスパス : ¥1,200", "desc": "365日間回数無制限（年間サーバー維持費の約90分の1を分担）"},
    {"id": "vt_100", "kind": "ticket", "days": 0, "credits": 100, "price_yen": 100, "label": "ボイス100セリフ枠 : ¥100", "desc": "使った分だけ消費（1セリフ再生＝1消費・期限なし）"},
    {"id": "vt_300", "kind": "ticket", "days": 0, "credits": 300, "price_yen": 250, "label": "ボイス300セリフ枠 : ¥250", "desc": "まとめ買いでお得な従量ボイス枠（期限なし）"},
]
VOICE_PLANS_MAP = {vp["id"]: vp for vp in VOICE_PLANS}


def get_aquestalk_period_and_target() -> Tuple[str, int]:
    period = os.environ.get("AQUESTALK_COST_PERIOD", "year_1").strip() or "year_1"
    target = max(1, int(os.environ.get("AQUESTALK_ANNUAL_TARGET_YEN", "157300")))
    return period, target


def _norm(s: str) -> str:
    return unicodedata.normalize("NFKC", s or "").strip()


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _current_ym() -> str:
    return datetime.now().strftime("%Y-%m")


def calc_deposit_net(gross_yen: int) -> Tuple[int, int]:
    rate = float(os.environ.get("PAYPAL_FEE_RATE", "0.036"))
    fixed = int(os.environ.get("PAYPAL_FEE_FIXED_YEN", "40"))
    fee = int(math.ceil(gross_yen * rate)) + fixed
    net = max(0, gross_yen - fee)
    return fee, net


@contextmanager
def get_conn():
    conn = sqlite3.connect(DB_PATH, timeout=8.0, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA synchronous = NORMAL;")
    conn.execute("PRAGMA temp_store = MEMORY;")
    conn.execute("PRAGMA cache_size = -2000;")  # 最大約2MBに制限
    conn.execute("PRAGMA mmap_size = 0;")
    conn.execute("PRAGMA busy_timeout = 5000;")
    try:
        yield conn
    finally:
        conn.close()


def init_schema() -> None:
    with _DB_WRITE_LOCK, get_conn() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS characters (
                char_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                kana TEXT NOT NULL,
                category TEXT NOT NULL,
                category_order INTEGER NOT NULL DEFAULT 100,
                aliases_json TEXT NOT NULL,
                aq1_voice TEXT NOT NULL DEFAULT 'f1',
                aq1_spd INTEGER NOT NULL DEFAULT 100,
                aq1_fsc INTEGER NOT NULL DEFAULT 100,
                aq1_vol INTEGER NOT NULL DEFAULT 100,
                default_bg_keyword TEXT NOT NULL DEFAULT '博麗神社',
                canon_profile TEXT NOT NULL DEFAULT ''
            );
            CREATE INDEX IF NOT EXISTS idx_chars_cat ON characters(category_order, category, name);

            CREATE TABLE IF NOT EXISTS personalities (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                kana TEXT NOT NULL,
                category TEXT NOT NULL,
                description TEXT NOT NULL,
                sample_line TEXT NOT NULL,
                behavior_pattern TEXT NOT NULL,
                source TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS users (
                user_id TEXT PRIMARY KEY,
                email TEXT NOT NULL,
                display_name TEXT NOT NULL,
                deposit_yen INTEGER NOT NULL DEFAULT 0,
                prompt_balance INTEGER NOT NULL DEFAULT 0,
                auto_charge_plan_id TEXT NOT NULL DEFAULT 'none',
                voice_credits INTEGER NOT NULL DEFAULT 0,
                voice_pass_until TEXT NOT NULL DEFAULT '',
                voice_trial_left INTEGER NOT NULL DEFAULT 5,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS auth_sessions (
                token TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS deposit_orders (
                order_id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                gross_yen INTEGER NOT NULL,
                fee_yen INTEGER NOT NULL,
                net_yen INTEGER NOT NULL,
                initial_plan_id TEXT NOT NULL DEFAULT '',
                initial_voice_plan_id TEXT NOT NULL DEFAULT '',
                auto_charge_plan_id TEXT NOT NULL DEFAULT 'none',
                paypal_order_id TEXT NOT NULL DEFAULT '',
                approve_url TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'PENDING',
                created_at TEXT NOT NULL,
                completed_at TEXT NOT NULL DEFAULT ''
            );

            CREATE TABLE IF NOT EXISTS voice_cost_pool (
                period_key TEXT PRIMARY KEY,
                target_yen INTEGER NOT NULL,
                collected_yen INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS voice_purchases (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                period_key TEXT NOT NULL,
                voice_plan_id TEXT NOT NULL,
                charged_yen INTEGER NOT NULL,
                credits_added INTEGER NOT NULL DEFAULT 0,
                pass_until TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS prompt_purchases (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                plan_id TEXT NOT NULL,
                prompts_added INTEGER NOT NULL,
                cost_yen INTEGER NOT NULL,
                year_month TEXT NOT NULL,
                is_auto_charge INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_purchases_user_ym ON prompt_purchases(user_id, plan_id, year_month);

            CREATE TABLE IF NOT EXISTS usage_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                action_type TEXT NOT NULL,
                delta_prompts INTEGER NOT NULL DEFAULT 0,
                delta_deposit_yen INTEGER NOT NULL DEFAULT 0,
                detail TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL
            );
            """
        )
        # 既存DBへの後方互換カラム追加
        u_cols = {r["name"] for r in conn.execute("PRAGMA table_info(users)").fetchall()}
        if "voice_credits" not in u_cols:
            conn.execute("ALTER TABLE users ADD COLUMN voice_credits INTEGER NOT NULL DEFAULT 0")
        if "voice_pass_until" not in u_cols:
            conn.execute("ALTER TABLE users ADD COLUMN voice_pass_until TEXT NOT NULL DEFAULT ''")
        if "voice_trial_left" not in u_cols:
            conn.execute(f"ALTER TABLE users ADD COLUMN voice_trial_left INTEGER NOT NULL DEFAULT {DEFAULT_VOICE_TRIAL_TURNS}")

        o_cols = {r["name"] for r in conn.execute("PRAGMA table_info(deposit_orders)").fetchall()}
        if "initial_voice_plan_id" not in o_cols:
            conn.execute("ALTER TABLE deposit_orders ADD COLUMN initial_voice_plan_id TEXT NOT NULL DEFAULT ''")

        period, target = get_aquestalk_period_and_target()
        conn.execute(
            """
            INSERT INTO voice_cost_pool (period_key, target_yen, collected_yen, updated_at)
            VALUES (?, ?, 0, ?)
            ON CONFLICT(period_key) DO UPDATE SET target_yen = excluded.target_yen
            """,
            (period, target, _now_iso()),
        )
        conn.commit()


CATEGORY_SORT_ORDER = [
    "主人公", "紅魔郷", "妖々夢", "永夜抄", "花映塚、文花帖", "風神録",
    "地霊殿", "星蓮船", "神霊廟", "輝針城", "紺珠伝", "天空璋",
    "鬼形獣", "虹龍洞", "獣王園", "錦上京",
    "萃夢想、緋想天、心綺楼、深秘録、憑依華、剛欲異聞",
    "三月精", "儚月抄", "鈴奈庵", "秘封倶楽部", "未分類",
    "靈異伝", "封魔録", "夢時空", "幻想郷", "怪綺談",
]

CANON_PROFILES: Dict[str, str] = {
    "博麗霊夢": "博麗神社の巫女。一人称は「私」。裏表がなくマイペースで少し素っ気ないが面倒見が良く、外来人に対しても分け隔てなく接する。口調は「〜ね」「〜わ」「〜かしら？」。",
    "霧雨魔理沙": "普通の魔法使い。一人称は「私」。明るく快活で努力家、語尾に「〜だぜ」「〜だな」「〜のぜ」を使う竹を割ったような性格。",
    "アリス・マーガトロイド": "魔法の森に住む七色の人形遣い。一人称は「私」。上品で落ち着いた都会的な話し方（「〜わ」「〜かしら」）をするが、親しくなると世話焼き。",
    "レミリア・スカーレット": "紅魔館の主である吸血鬼。一人称は「私」。カリスマ性と気品あるお嬢様口調と子供っぽい無邪気さを併せ持つ。",
    "フランドール・スカーレット": "レミリアの妹。一人称は「私」。純粋無垢で好奇心旺盛、少し危うい可愛らしさがある。",
    "十六夜咲夜": "紅魔館の完璧で瀟洒なメイド長。一人称は「私」。丁寧かつ凛とした落ち着きのある口調。",
    "パチュリー・ノーレッジ": "紅魔館の大図書館に籠もる知識と日陰の少女。一人称は「私」。物静かで落ち着いた知的な話し方。",
    "チルノ": "霧の湖の氷の妖精。一人称は「あたい」。元気いっぱいで自信家（「あたいったら最強ね！」）。",
    "魂魄妖夢": "白玉楼の半人半霊の庭師兼剣術指南役。一人称は「私」（または「みょん」）。真面目で一生懸命、少し天然でお化けが苦手。",
    "西行寺幽々子": "白玉楼の亡霊の姫。一人称は「私」。おっとりマイペースで食通、掴みどころのない優雅な包容力がある。",
    "八雲紫": "境界を操る大妖怪。一人称は「私」。妖艶で謎めいた大人の余裕を漂わせる丁寧語・お姉さん口調。",
    "藤原妹紅": "迷いの竹林の蓬莱人。一人称は「私」または「俺」。ぶっきらぼうでサバサバしているが情に厚く義理堅い。",
    "鈴仙・優曇華院・イナバ": "永遠亭の月の兎。一人称は「私」。真面目で常識人、周囲に振り回されやすい苦労人。",
    "東風谷早苗": "守矢神社の風祝（外の世界出身の現人神）。一人称は「私」。礼儀正しく明るい常識人だが、奇跡やロボの話になると熱くなる。",
    "古明地さとり": "地霊殿の主で心を読む覚（さとり）。一人称は「私」。穏やかで落ち着いた丁寧な口調、動物好き。",
    "古明地こいし": "無意識を操るさとりの妹。一人称は「私」。無邪気で自由奔放、予測不能な明るさを持つ。",
}


def _load_serif_maker_presets() -> List[Dict[str, Any]]:
    if os.path.exists(SERIF_MAKER_DIR) and SERIF_MAKER_DIR not in sys.path:
        sys.path.insert(0, SERIF_MAKER_DIR)
    try:
        from presets_catalog import CHARACTER_PRESETS  # type: ignore
        return list(CHARACTER_PRESETS)
    except Exception:
        return []


def _default_bg_keyword_for_char(raw_cat: str, full_name: str) -> str:
    if any(k in raw_cat or k in full_name for k in ("紅魔", "レミリア", "フラン", "咲夜", "パチュリー", "美鈴", "小悪魔")):
        return "紅魔館"
    if any(k in full_name for k in ("早苗", "神奈子", "諏訪子")):
        return "守矢神社"
    if any(k in full_name for k in ("霊夢",)):
        return "博麗神社"
    return "神社"


def bootstrap_assets_if_needed(force: bool = False) -> Dict[str, int]:
    """キャラクター声種定義および性癖リスト50種のメタデータのみをSQLiteへ登録（外部画像は一切保持・配信しない）"""
    init_schema()
    with get_conn() as conn:
        char_count = conn.execute("SELECT COUNT(*) FROM characters").fetchone()[0]
        pers_count = conn.execute("SELECT COUNT(*) FROM personalities").fetchone()[0]
        if not force and char_count > 0 and pers_count > 0:
            return {"characters": char_count, "personalities": pers_count}

    personalities_data: List[Dict[str, Any]] = []
    if os.path.exists(PERSONALITY_JSON_PATH):
        with open(PERSONALITY_JSON_PATH, "r", encoding="utf-8") as f:
            personalities_data = json.load(f)

    presets = _load_serif_maker_presets()
    preset_by_alias: Dict[str, Dict[str, Any]] = {}
    for pr in presets:
        for al in [pr.get("name", "")] + list(pr.get("aliases", [])):
            nal = _norm(al)
            if nal and nal not in preset_by_alias:
                preset_by_alias[nal] = pr

    char_rows = []
    seen_char_ids = set()
    seen_names = set()

    # 1) プリセット登録キャラクターを登録
    for idx, pr in enumerate(presets):
        full_name = _norm(pr["name"])
        kana = _norm(pr.get("kana", full_name))
        char_id = str(pr["char_id"])
        raw_cat = _norm(pr.get("category", "未分類"))
        cat_order = CATEGORY_SORT_ORDER.index(raw_cat) if raw_cat in CATEGORY_SORT_ORDER else 99

        aq1_voice, aq1_spd, aq1_fsc, aq1_vol = "f1", 100, 105, 100
        aq1_vars = [v for v in pr.get("variants", []) if v.get("engine") == "AquesTalk1"]
        if aq1_vars:
            v0 = aq1_vars[0]
            aq1_voice = str(v0.get("voice", "f1"))
            aq1_spd = int(v0.get("spd", 100))
            aq1_fsc = int(v0.get("fsc", 100))
            aq1_vol = int(v0.get("vol", 100))

        aliases = list(dict.fromkeys([full_name] + [_norm(a) for a in pr.get("aliases", []) if _norm(a)]))
        bg_kw = _default_bg_keyword_for_char(raw_cat, full_name)
        canon_prof = CANON_PROFILES.get(
            full_name,
            f"東方Project『{raw_cat}』に登場する「{full_name}」。原作の世界観・口調・一人称に忠実に振る舞う。",
        )
        char_rows.append((
            char_id, full_name, kana, raw_cat, cat_order,
            json.dumps(aliases, ensure_ascii=False),
            aq1_voice, aq1_spd, aq1_fsc, aq1_vol, bg_kw, canon_prof,
        ))
        seen_char_ids.add(char_id)
        for al in aliases:
            seen_names.add(al)

    # 2) ディレクトリ名のみから追加キャラクター名補完（ファイル自体は一切読み込まない）
    if os.path.isdir(HARUKA_DIR):
        extra_idx = 0
        for cat_raw in sorted(os.listdir(HARUKA_DIR)):
            cat_p = os.path.join(HARUKA_DIR, cat_raw)
            if not os.path.isdir(cat_p) or cat_raw.startswith("."):
                continue
            cat_short = re.split(r"[(（]", _norm(cat_raw), maxsplit=1)[0].strip()
            cat_order = CATEGORY_SORT_ORDER.index(cat_short) if cat_short in CATEGORY_SORT_ORDER else 99
            for c_dir in sorted(os.listdir(cat_p)):
                if c_dir.startswith(".") or not os.path.isdir(os.path.join(cat_p, c_dir)):
                    continue
                nd = _norm(c_dir)
                if "(" in nd or "ちび" in nd or "やられ" in nd:
                    continue
                base_nm = re.split(r"[(（]", nd, maxsplit=1)[0].strip()
                if not base_nm or base_nm in seen_names or any(len(s) >= 2 and (s in base_nm or base_nm in s) for s in seen_names):
                    continue
                extra_idx += 1
                cid = f"th_extra_{extra_idx:03d}"
                seen_names.add(base_nm)
                char_rows.append((
                    cid, base_nm, base_nm, cat_short, cat_order,
                    json.dumps([base_nm], ensure_ascii=False),
                    "f1", 100, 108, 100,
                    _default_bg_keyword_for_char(cat_short, base_nm),
                    f"東方Project『{cat_short}』に登場する「{base_nm}」。原作の世界観・口調・一人称に忠実に振る舞う。",
                ))

    with _DB_WRITE_LOCK, get_conn() as conn:
        conn.execute("DROP TABLE IF EXISTS portraits")
        conn.execute("DROP TABLE IF EXISTS backgrounds")
        if force:
            conn.execute("DELETE FROM personalities")
            conn.execute("DELETE FROM characters")

        for p in personalities_data:
            conn.execute(
                """
                INSERT OR REPLACE INTO personalities
                (id, name, kana, category, description, sample_line, behavior_pattern, source)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    int(p["id"]), p["name"], p.get("kana", ""), p.get("category", ""),
                    p.get("description", ""), p.get("sample_line", ""),
                    p.get("behavior_pattern", ""), p.get("source", ""),
                ),
            )

        conn.executemany(
            """
            INSERT OR REPLACE INTO characters
            (char_id, name, kana, category, category_order, aliases_json,
             aq1_voice, aq1_spd, aq1_fsc, aq1_vol, default_bg_keyword, canon_profile)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            char_rows,
        )
        conn.execute(
            "INSERT OR REPLACE INTO meta (key, value) VALUES ('bootstrapped_at', ?)",
            (_now_iso(),),
        )
        conn.commit()
        conn.execute("VACUUM")

    return {"characters": len(char_rows), "personalities": len(personalities_data)}


def list_categories_with_characters() -> List[Dict[str, Any]]:
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT char_id, name, kana, category, category_order, aliases_json,
                   aq1_voice, aq1_spd, aq1_fsc, default_bg_keyword, canon_profile
            FROM characters
            ORDER BY category_order ASC, category ASC, name ASC
            """
        ).fetchall()

    cats: Dict[str, List[Dict[str, Any]]] = {}
    cat_order_list: List[str] = []
    for r in rows:
        d = dict(r)
        try:
            d["aliases"] = json.loads(d.pop("aliases_json", "[]"))
        except Exception:
            d["aliases"] = [d["name"]]
        cat = d["category"]
        if cat not in cats:
            cats[cat] = []
            cat_order_list.append(cat)
        cats[cat].append(d)

    return [{"category": c, "characters": cats[c]} for c in cat_order_list]


def get_character(char_id: str) -> Optional[Dict[str, Any]]:
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM characters WHERE char_id = ?", (char_id,)).fetchone()
        if not r:
            return None
        d = dict(r)
        try:
            d["aliases"] = json.loads(d.get("aliases_json", "[]"))
        except Exception:
            d["aliases"] = [d["name"]]
        return d


def list_personalities() -> List[Dict[str, Any]]:
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM personalities ORDER BY id ASC").fetchall()
        return [dict(r) for r in rows]


def get_personalities_by_ids(ids: List[int]) -> List[Dict[str, Any]]:
    if not ids:
        return []
    placeholders = ",".join("?" for _ in ids)
    with get_conn() as conn:
        rows = conn.execute(f"SELECT * FROM personalities WHERE id IN ({placeholders})", ids).fetchall()
        return [dict(r) for r in rows]


def upsert_user(user_id: str, email: str, display_name: str) -> Dict[str, Any]:
    now = _now_iso()
    with _DB_WRITE_LOCK, get_conn() as conn:
        existing = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        if existing:
            conn.execute(
                "UPDATE users SET email = ?, display_name = ?, updated_at = ? WHERE user_id = ?",
                (email, display_name, now, user_id),
            )
        else:
            conn.execute(
                """
                INSERT INTO users (user_id, email, display_name, deposit_yen, prompt_balance, auto_charge_plan_id, created_at, updated_at)
                VALUES (?, ?, ?, 0, 0, 'none', ?, ?)
                """,
                (user_id, email, display_name, now, now),
            )
        conn.commit()
        row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        return dict(row)


def get_user(user_id: str) -> Optional[Dict[str, Any]]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        return dict(row) if row else None


def save_auth_session(token: str, user_id: str, expires_at: str) -> None:
    with _DB_WRITE_LOCK, get_conn() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO auth_sessions (token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
            (token, user_id, _now_iso(), expires_at),
        )
        conn.commit()


def get_user_by_session_token(token: str) -> Optional[Dict[str, Any]]:
    if not token:
        return None
    with get_conn() as conn:
        sess = conn.execute("SELECT user_id, expires_at FROM auth_sessions WHERE token = ?", (token,)).fetchone()
        if not sess:
            return None
        if sess["expires_at"] < _now_iso():
            return None
        row = conn.execute("SELECT * FROM users WHERE user_id = ?", (sess["user_id"],)).fetchone()
        return dict(row) if row else None


def get_monthly_purchase_counts(user_id: str, year_month: Optional[str] = None) -> Dict[str, int]:
    ym = year_month or _current_ym()
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT plan_id, COUNT(*) AS cnt
            FROM prompt_purchases
            WHERE user_id = ? AND year_month = ? AND is_auto_charge = 0
            GROUP BY plan_id
            """,
            (user_id, ym),
        ).fetchall()
        return {r["plan_id"]: int(r["cnt"]) for r in rows}


def _ensure_pool_row(conn: sqlite3.Connection) -> Dict[str, Any]:
    period, target = get_aquestalk_period_and_target()
    row = conn.execute("SELECT * FROM voice_cost_pool WHERE period_key = ?", (period,)).fetchone()
    if not row:
        conn.execute(
            "INSERT INTO voice_cost_pool (period_key, target_yen, collected_yen, updated_at) VALUES (?, ?, 0, ?)",
            (period, target, _now_iso()),
        )
        row = conn.execute("SELECT * FROM voice_cost_pool WHERE period_key = ?", (period,)).fetchone()
    return dict(row)


def get_aquestalk_pool_status() -> Dict[str, Any]:
    """今年度のAquesTalk1ライセンス実費回収状況（100%到達で全員無料開放・儲けゼロ保証）"""
    with _DB_WRITE_LOCK, get_conn() as conn:
        pool = _ensure_pool_row(conn)
        conn.commit()
    target = max(1, int(pool["target_yen"]))
    collected = int(pool["collected_yen"])
    remaining = max(0, target - collected)
    pct = min(100.0, round(collected * 100.0 / target, 1))
    return {
        "period_key": pool["period_key"],
        "target_yen": target,
        "collected_yen": collected,
        "remaining_yen": remaining,
        "progress_pct": pct,
        "is_goal_reached": remaining <= 0,
    }


def _apply_voice_plan_in_tx(
    conn: sqlite3.Connection,
    user_row: sqlite3.Row,
    current_deposit: int,
    voice_plan_id: str,
    now_iso: str,
) -> Tuple[int, int, str]:
    """
    トランザクション内でボイスパスまたはボイス枠を購入適用し、(new_deposit, new_voice_credits, new_pass_until) を返す。
    【儲けゼロ上限ストッパー】: 目標残額 (remaining) を超える金額は絶対に徴収しない。
    """
    vp = VOICE_PLANS_MAP[voice_plan_id]
    pool = _ensure_pool_row(conn)
    remaining = max(0, int(pool["target_yen"]) - int(pool["collected_yen"]))

    cur_credits = int(user_row["voice_credits"])
    cur_pass = str(user_row["voice_pass_until"] or "")

    # 既に今年度の目標額100%達成済みの場合は0円で自動無料開放中
    if remaining <= 0:
        return current_deposit, cur_credits, cur_pass

    actual_charge = min(int(vp["price_yen"]), remaining)
    if current_deposit < actual_charge:
        raise ValueError(f"ボイスプラン購入のデポジット残高が不足しています（残高 ¥{current_deposit} / 必要額 ¥{actual_charge}）。")

    new_deposit = current_deposit - actual_charge
    new_credits = cur_credits + int(vp["credits"])
    new_pass = cur_pass

    if vp["kind"] == "pass" and int(vp["days"]) > 0:
        base_dt = datetime.now(timezone.utc)
        if cur_pass and cur_pass > now_iso:
            try:
                base_dt = datetime.fromisoformat(cur_pass)
            except Exception:
                pass
        new_pass = (base_dt + timedelta(days=int(vp["days"]))).isoformat(timespec="seconds")

    conn.execute(
        "UPDATE voice_cost_pool SET collected_yen = collected_yen + ?, updated_at = ? WHERE period_key = ?",
        (actual_charge, now_iso, pool["period_key"]),
    )
    conn.execute(
        """
        INSERT INTO voice_purchases (user_id, period_key, voice_plan_id, charged_yen, credits_added, pass_until, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (user_row["user_id"], pool["period_key"], voice_plan_id, actual_charge, int(vp["credits"]), new_pass, now_iso),
    )
    conn.execute(
        """
        INSERT INTO usage_logs (user_id, action_type, delta_prompts, delta_deposit_yen, detail, created_at)
        VALUES (?, 'AQUESTALK_VOICE_PLAN', 0, ?, ?, ?)
        """,
        (user_row["user_id"], -actual_charge, f"voice_plan={voice_plan_id}", now_iso),
    )
    return new_deposit, new_credits, new_pass


def purchase_voice_plan_from_deposit(user_id: str, voice_plan_id: str) -> Dict[str, Any]:
    if voice_plan_id not in VOICE_PLANS_MAP:
        raise ValueError("無効なボイスプランです。")
    now = _now_iso()
    with _DB_WRITE_LOCK, get_conn() as conn:
        user = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        if not user:
            raise ValueError("ユーザーが見つかりません。")
        new_dep, new_cred, new_pass = _apply_voice_plan_in_tx(
            conn, user, int(user["deposit_yen"]), voice_plan_id, now
        )
        conn.execute(
            "UPDATE users SET deposit_yen = ?, voice_credits = ?, voice_pass_until = ?, updated_at = ? WHERE user_id = ?",
            (new_dep, new_cred, new_pass, now, user_id),
        )
        conn.commit()
        updated_user = dict(conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone())
    return {"user": updated_user, "voice_pool": get_aquestalk_pool_status()}


def _has_local_serif_maker_license() -> bool:
    lic_path = os.path.join(SERIF_MAKER_DIR, "data", "licenses.json")
    if os.path.isfile(lic_path):
        try:
            with open(lic_path, "r", encoding="utf-8") as f:
                d = json.load(f)
            if isinstance(d, dict) and any(str(v).strip() for k, v in d.items() if k.endswith("_key")):
                return True
        except Exception:
            pass
    return bool(os.environ.get("AQUESTALK_DEV_KEY", "").strip() or os.environ.get("AQUESTALK_USR_KEY", "").strip())


def check_and_consume_voice_entitlement(
    user_id: Optional[str],
    consume: bool = True,
    is_local_client: bool = False,
) -> Dict[str, Any]:
    """
    AquesTalk1 ボイス再生権の判定・消費を行う。
    優先順: 1) 今年度ライセンス回収100%達成（全員無料） -> 2) 期間パス有効 -> 3) 従量ボイス枠
           -> 4) ローカル/開発環境でキャラセリフメーカーにライセンス登録済みの実行 -> 5) 初回無料お試し枠(5回)
    """
    now = _now_iso()
    allow_dev = os.environ.get("ALLOW_DEV_AUTH", "true").lower() in ("1", "true", "yes")
    allow_local_owner = (allow_dev or is_local_client) and _has_local_serif_maker_license()

    with _DB_WRITE_LOCK, get_conn() as conn:
        pool = _ensure_pool_row(conn)
        if int(pool["collected_yen"]) >= int(pool["target_yen"]):
            conn.commit()
            u_row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone() if user_id else None
            return {"allowed": True, "source": "goal_reached_free", "user": dict(u_row) if u_row else None}

        if not user_id:
            conn.commit()
            if allow_local_owner:
                return {"allowed": True, "source": "chara_serif_maker_licensed", "user": None}
            return {"allowed": False, "source": "unauthenticated", "reason": "ボイス再生にはログインとボイス枠が必要です。", "user": None}

        user = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        if not user:
            conn.commit()
            if allow_local_owner:
                return {"allowed": True, "source": "chara_serif_maker_licensed", "user": None}
            return {"allowed": False, "source": "no_user", "reason": "ユーザーが見つかりません。", "user": None}

        pass_until = str(user["voice_pass_until"] or "")
        if pass_until and pass_until > now:
            conn.commit()
            return {"allowed": True, "source": "voice_pass", "user": dict(user)}

        credits = int(user["voice_credits"])
        if credits > 0:
            if consume:
                credits -= 1
                conn.execute("UPDATE users SET voice_credits = ?, updated_at = ? WHERE user_id = ?", (credits, now, user_id))
                conn.commit()
            updated = dict(conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone())
            return {"allowed": True, "source": "voice_credits", "user": updated}

        if allow_local_owner:
            conn.commit()
            return {"allowed": True, "source": "chara_serif_maker_licensed", "user": dict(user)}

        trial = int(user["voice_trial_left"])
        if trial > 0:
            if consume:
                trial -= 1
                conn.execute("UPDATE users SET voice_trial_left = ?, updated_at = ? WHERE user_id = ?", (trial, now, user_id))
                conn.commit()
            updated = dict(conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone())
            return {"allowed": True, "source": "free_trial", "user": updated}

        conn.commit()
        return {
            "allowed": False,
            "source": "exhausted",
            "reason": "ボイス無料お試し枠が終了しました。フルボイスを継続するには「🔊 ボイス枠/パス」からAquesTalk実費分担プランを有効化してください（テキスト会話はそのまま続行できます）。",
            "user": dict(user),
        }


def create_deposit_order(
    order_id: str,
    user_id: str,
    gross_yen: int,
    initial_plan_id: str,
    auto_charge_plan_id: str,
    initial_voice_plan_id: str = "",
    paypal_order_id: str = "",
    approve_url: str = "",
) -> Dict[str, Any]:
    fee_yen, net_yen = calc_deposit_net(gross_yen)
    now = _now_iso()
    with _DB_WRITE_LOCK, get_conn() as conn:
        conn.execute(
            """
            INSERT INTO deposit_orders
            (order_id, user_id, gross_yen, fee_yen, net_yen, initial_plan_id, initial_voice_plan_id,
             auto_charge_plan_id, paypal_order_id, approve_url, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING', ?)
            """,
            (
                order_id, user_id, gross_yen, fee_yen, net_yen,
                initial_plan_id, initial_voice_plan_id, auto_charge_plan_id,
                paypal_order_id, approve_url, now,
            ),
        )
        conn.commit()
        r = conn.execute("SELECT * FROM deposit_orders WHERE order_id = ?", (order_id,)).fetchone()
        return dict(r)


def get_deposit_order(order_id: str) -> Optional[Dict[str, Any]]:
    with get_conn() as conn:
        r = conn.execute("SELECT * FROM deposit_orders WHERE order_id = ?", (order_id,)).fetchone()
        return dict(r) if r else None


def complete_deposit_and_initial_purchase(order_id: str) -> Dict[str, Any]:
    ym = _current_ym()
    now = _now_iso()
    with _DB_WRITE_LOCK, get_conn() as conn:
        order = conn.execute("SELECT * FROM deposit_orders WHERE order_id = ?", (order_id,)).fetchone()
        if not order:
            raise ValueError("注文が見つかりません。")
        user_id = order["user_id"]
        if order["status"] == "COMPLETED":
            user = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
            return {"order": dict(order), "user": dict(user), "already_completed": True}

        user = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        if not user:
            raise ValueError("ユーザーが見つかりません。")

        new_deposit = int(user["deposit_yen"]) + int(order["net_yen"])
        new_prompts = int(user["prompt_balance"])
        new_v_credits = int(user["voice_credits"])
        new_v_pass = str(user["voice_pass_until"] or "")
        ac_id = order["auto_charge_plan_id"] if order["auto_charge_plan_id"] in AUTO_CHARGE_MAP else user["auto_charge_plan_id"]

        plan_id = order["initial_plan_id"]
        if plan_id and plan_id in PROMPT_PLANS_MAP:
            plan = PROMPT_PLANS_MAP[plan_id]
            limit = plan["monthly_limit"]
            if limit is not None:
                cnt = conn.execute(
                    "SELECT COUNT(*) FROM prompt_purchases WHERE user_id = ? AND plan_id = ? AND year_month = ? AND is_auto_charge = 0",
                    (user_id, plan_id, ym),
                ).fetchone()[0]
                if cnt >= limit:
                    raise ValueError(f"プラン {plan['prompts']}prompt は月{limit}回までの購入制限に達しています。")
            if new_deposit < plan["price_yen"]:
                raise ValueError(
                    f"手数料差引後のデポジット残高 (¥{new_deposit}) がプラン料金 (¥{plan['price_yen']}) に不足しています。"
                )
            new_deposit -= int(plan["price_yen"])
            new_prompts += int(plan["prompts"])
            conn.execute(
                """
                INSERT INTO prompt_purchases (user_id, plan_id, prompts_added, cost_yen, year_month, is_auto_charge, created_at)
                VALUES (?, ?, ?, ?, ?, 0, ?)
                """,
                (user_id, plan_id, plan["prompts"], plan["price_yen"], ym, now),
            )

        v_plan_id = order["initial_voice_plan_id"] if "initial_voice_plan_id" in order.keys() else ""
        if v_plan_id and v_plan_id in VOICE_PLANS_MAP:
            new_deposit, new_v_credits, new_v_pass = _apply_voice_plan_in_tx(
                conn, user, new_deposit, v_plan_id, now
            )

        conn.execute("UPDATE deposit_orders SET status = 'COMPLETED', completed_at = ? WHERE order_id = ?", (now, order_id))
        conn.execute(
            """
            UPDATE users
            SET deposit_yen = ?, prompt_balance = ?, auto_charge_plan_id = ?,
                voice_credits = ?, voice_pass_until = ?, updated_at = ?
            WHERE user_id = ?
            """,
            (new_deposit, new_prompts, ac_id, new_v_credits, new_v_pass, now, user_id),
        )
        conn.execute(
            """
            INSERT INTO usage_logs (user_id, action_type, delta_prompts, delta_deposit_yen, detail, created_at)
            VALUES (?, 'DEPOSIT_AND_PURCHASE', ?, ?, ?, ?)
            """,
            (user_id, new_prompts - int(user["prompt_balance"]), new_deposit - int(user["deposit_yen"]), f"order={order_id}", now),
        )
        conn.commit()
        updated_user = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        updated_order = conn.execute("SELECT * FROM deposit_orders WHERE order_id = ?", (order_id,)).fetchone()
        return {"order": dict(updated_order), "user": dict(updated_user), "already_completed": False}


def purchase_prompt_from_deposit(user_id: str, plan_id: str, auto_charge_plan_id: Optional[str] = None) -> Dict[str, Any]:
    if plan_id not in PROMPT_PLANS_MAP:
        raise ValueError("無効なプロンプトプランです。")
    plan = PROMPT_PLANS_MAP[plan_id]
    ym = _current_ym()
    now = _now_iso()
    with _DB_WRITE_LOCK, get_conn() as conn:
        user = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        if not user:
            raise ValueError("ユーザーが見つかりません。")
        limit = plan["monthly_limit"]
        if limit is not None:
            cnt = conn.execute(
                "SELECT COUNT(*) FROM prompt_purchases WHERE user_id = ? AND plan_id = ? AND year_month = ? AND is_auto_charge = 0",
                (user_id, plan_id, ym),
            ).fetchone()[0]
            if cnt >= limit:
                raise ValueError(f"プラン {plan['prompts']}prompt は月{limit}回までの購入制限に達しています。")
        if int(user["deposit_yen"]) < int(plan["price_yen"]):
            raise ValueError(f"デポジット残高不足です（残高 ¥{user['deposit_yen']} / 必要額 ¥{plan['price_yen']}）。")

        new_dep = int(user["deposit_yen"]) - int(plan["price_yen"])
        new_prm = int(user["prompt_balance"]) + int(plan["prompts"])
        ac_id = auto_charge_plan_id if (auto_charge_plan_id and auto_charge_plan_id in AUTO_CHARGE_MAP) else user["auto_charge_plan_id"]

        conn.execute(
            """
            INSERT INTO prompt_purchases (user_id, plan_id, prompts_added, cost_yen, year_month, is_auto_charge, created_at)
            VALUES (?, ?, ?, ?, ?, 0, ?)
            """,
            (user_id, plan_id, plan["prompts"], plan["price_yen"], ym, now),
        )
        conn.execute(
            "UPDATE users SET deposit_yen = ?, prompt_balance = ?, auto_charge_plan_id = ?, updated_at = ? WHERE user_id = ?",
            (new_dep, new_prm, ac_id, now, user_id),
        )
        conn.commit()
        return dict(conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone())


def consume_one_prompt(user_id: str, reason: str = "dialogue_turn") -> Dict[str, Any]:
    now = _now_iso()
    ym = _current_ym()
    with _DB_WRITE_LOCK, get_conn() as conn:
        user = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        if not user:
            raise ValueError("ユーザーが見つかりません。")

        dep = int(user["deposit_yen"])
        prm = int(user["prompt_balance"])
        ac_id = user["auto_charge_plan_id"]
        auto_charged = False

        if prm <= 0:
            ac = AUTO_CHARGE_MAP.get(ac_id)
            if ac and ac["prompts"] > 0 and dep >= ac["price_yen"]:
                dep -= int(ac["price_yen"])
                prm += int(ac["prompts"])
                auto_charged = True
                conn.execute(
                    """
                    INSERT INTO prompt_purchases (user_id, plan_id, prompts_added, cost_yen, year_month, is_auto_charge, created_at)
                    VALUES (?, ?, ?, ?, ?, 1, ?)
                    """,
                    (user_id, ac_id, ac["prompts"], ac["price_yen"], ym, now),
                )
            else:
                raise ValueError("プロンプト残数が不足しています。追加購入またはデポジットチャージを行ってください。")

        prm -= 1
        conn.execute(
            "UPDATE users SET deposit_yen = ?, prompt_balance = ?, updated_at = ? WHERE user_id = ?",
            (dep, prm, now, user_id),
        )
        conn.execute(
            """
            INSERT INTO usage_logs (user_id, action_type, delta_prompts, delta_deposit_yen, detail, created_at)
            VALUES (?, 'PROMPT_CONSUME', -1, ?, ?, ?)
            """,
            (user_id, dep - int(user["deposit_yen"]), f"{reason}{' (auto_charged)' if auto_charged else ''}", now),
        )
        conn.commit()
        updated = dict(conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone())
        updated["auto_charged"] = auto_charged
        return updated


def charge_background_generation(user_id: str, bg_name: str) -> Dict[str, Any]:
    now = _now_iso()
    with _DB_WRITE_LOCK, get_conn() as conn:
        user = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        if not user:
            raise ValueError("ユーザーが見つかりません。")
        dep = int(user["deposit_yen"])
        if dep < BG_GENERATION_COST_YEN:
            raise ValueError(f"背景新規生成にはデポジット残高 ¥{BG_GENERATION_COST_YEN} が必要です（現在 ¥{dep}）。")
        dep -= BG_GENERATION_COST_YEN
        conn.execute("UPDATE users SET deposit_yen = ?, updated_at = ? WHERE user_id = ?", (dep, now, user_id))
        conn.execute(
            """
            INSERT INTO usage_logs (user_id, action_type, delta_prompts, delta_deposit_yen, detail, created_at)
            VALUES (?, 'BG_GENERATION_100YEN', 0, ?, ?, ?)
            """,
            (user_id, -BG_GENERATION_COST_YEN, f"bg={bg_name}", now),
        )
        conn.commit()
        return dict(conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone())
