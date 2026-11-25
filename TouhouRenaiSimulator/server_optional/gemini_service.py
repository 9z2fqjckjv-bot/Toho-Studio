#!/usr/bin/env python3
"""
Gemini API 会話・プレゼン風ステージ演出・音声記号列生成エンジン (gemini_service.py)
【超省メモリ・省CPU ＆ 外部素材クライアントローカル参照方式】:
  - サーバーは立ち絵・背景・効果音の素材ファイルを一切保持・配信しない
  - 『キャラステージ演出メーカー』(stage_director_engine.py) を同一プロセス内で直接呼び出し（常駐デーモン追加ゼロ・メモリ増加<0.2MB）、
    プレゼンソフトのように立ち絵の拡大縮小・アニメーション・画面効果・効果音キューを生成
  - 会話内容に応じた毎ターンの動的性格シフト（惰性固定化の防止）＋手動固定/ハイブリッド制御に対応
  - 単一共有 httpx.AsyncClient コネクションプールにより毎ターンのTLS再生成CPU/メモリ負荷を最小化
"""

import io
import os
import sys
import json
import uuid
import base64
import asyncio
from typing import Any, Dict, List, Optional, Tuple

import httpx
from PIL import Image, ImageDraw

from db import (
    DOC_ROOT,
    get_character,
    list_personalities,
    get_personalities_by_ids,
)
from voice_service import (
    katakana_to_hiragana,
    sanitize_aquestalk1_koe,
    resolve_serif_maker_preset_for_char,
    synthesize_via_chara_serif_maker,
)

# 『キャラステージ演出メーカー』コアエンジンを同一プロセスで直接読み込み（追加プロセス・IPC負荷ゼロ）
STAGE_DIRECTOR_DIR = os.environ.get(
    "CHARA_STAGE_DIRECTOR_DIR",
    os.path.join(DOC_ROOT, "キャラステージ演出メーカー"),
)
if os.path.isdir(STAGE_DIRECTOR_DIR) and STAGE_DIRECTOR_DIR not in sys.path:
    sys.path.insert(0, STAGE_DIRECTOR_DIR)

from stage_director_engine import (  # noqa: E402
    STAGE_DIRECTION_JSON_SCHEMA,
    STAGE_DIRECTOR_FUNCTION_DECLARATION,
    build_gemini_stage_prompt_section,
    get_master_stage_catalog,
    normalize_stage_direction,
)

GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta"

# 共有HTTPクライアント（TLSハンドシェイク・ソケット再生成のCPU/メモリ浪費を抑制）
_SHARED_HTTP_CLIENT: Optional[httpx.AsyncClient] = None


def get_shared_http_client() -> httpx.AsyncClient:
    global _SHARED_HTTP_CLIENT
    if _SHARED_HTTP_CLIENT is None or _SHARED_HTTP_CLIENT.is_closed:
        _SHARED_HTTP_CLIENT = httpx.AsyncClient(
            timeout=32.0,
            limits=httpx.Limits(max_keepalive_connections=4, max_connections=8, keepalive_expiry=45.0),
        )
    return _SHARED_HTTP_CLIENT


async def close_shared_http_client() -> None:
    global _SHARED_HTTP_CLIENT
    if _SHARED_HTTP_CLIENT is not None and not _SHARED_HTTP_CLIENT.is_closed:
        await _SHARED_HTTP_CLIENT.aclose()
    _SHARED_HTTP_CLIENT = None


RELATIONSHIP_STAGES = [
    (0, "出会い"),
    (15, "知人"),
    (35, "友人"),
    (55, "気になる人"),
    (75, "恋人"),
    (90, "プロポーズ"),
    (100, "結婚式"),
]


def stage_for_affection(affection: int) -> str:
    aff = max(0, min(100, int(affection)))
    current = "出会い"
    for threshold, label in RELATIONSHIP_STAGES:
        if aff >= threshold:
            current = label
    return current


def _match_client_bg(
    available_backgrounds: List[Dict[str, Any]],
    bg_id: str = "",
    keyword: str = "",
    time_of_day: str = "day",
    scene_context: str = "",
) -> Tuple[Dict[str, Any], int]:
    """
    ローカル背景リストから会話内容・キーワード・時間帯に最も忠実な背景をスコアリング選出。
    (matched_bg_dict, match_score) を返す。match_score == 0 は適切な一致なし。
    """
    if bg_id:
        for b in available_backgrounds:
            if b.get("bg_id") == bg_id:
                return (
                    {
                        "bg_id": b["bg_id"],
                        "name": b.get("name", ""),
                        "keyword": keyword or b.get("name", ""),
                        "time_of_day": b.get("time_of_day", time_of_day),
                    },
                    100,
                )

    best_b: Optional[Dict[str, Any]] = None
    best_score = 0
    kw = (keyword or "").strip()
    ctx = f"{kw} {scene_context or ''}".strip()
    tokens = [t for t in (kw, *[w for w in ("神社", "境内", "鳥居", "紅魔", "館", "ロビー", "書斎", "図書館", "食堂", "寝室", "部屋", "廊下", "森", "魔法の森", "竹林", "湖", "霧の湖", "川", "山", "桜", "花畑", "縁側", "茶屋", "カフェ", "街", "人里", "屋上", "観覧車", "星空", "夜空", "月", "夕暮れ", "海", "浜辺", "温泉", "教室", "部室", "教会", "結婚式") if w in ctx]) if t]

    for b in available_backgrounds:
        nm = str(b.get("name", ""))
        tags = str(b.get("tags", ""))
        btod = str(b.get("time_of_day", "any"))
        sc = 0
        if kw and (kw == nm or kw in nm):
            sc += 50
        elif kw and (nm in kw or kw in tags):
            sc += 30
        for tk in tokens:
            if tk in nm:
                sc += 18
            elif tk in tags:
                sc += 10
        if sc > 0 and time_of_day and time_of_day != "any":
            if btod == time_of_day:
                sc += 12
            elif btod not in ("any", time_of_day):
                sc -= 6
        if sc > best_score:
            best_score = sc
            best_b = b

    if best_b is not None and best_score > 0:
        return (
            {
                "bg_id": best_b.get("bg_id", ""),
                "name": best_b.get("name", keyword),
                "keyword": keyword or best_b.get("name", ""),
                "time_of_day": best_b.get("time_of_day", time_of_day),
            },
            best_score,
        )
    return (
        {"bg_id": bg_id, "name": keyword or "博麗神社", "keyword": keyword or "神社", "time_of_day": time_of_day},
        0,
    )


def _format_backgrounds_for_prompt(
    available_bgs: List[Dict[str, Any]],
    char_info: Dict[str, Any],
    recent_context: str = "",
) -> str:
    if not available_bgs:
        return "- (ローカル背景ファイル未検出: `bg_action: \"generate_ai\"` と `suggest_new_bg_prompt` で会話場面に忠実な背景を生成指定してください)"

    canon_kw = char_info.get("default_bg_keyword", "")
    query_ctx = f"{canon_kw} {char_info.get('name', '')} {recent_context}"
    place_hints = [w for w in ("神社", "紅魔", "館", "書斎", "図書館", "食堂", "部屋", "寝室", "廊下", "森", "竹林", "湖", "山", "桜", "花", "縁側", "カフェ", "街", "屋上", "夜", "夕", "月", "星", "海", "温泉", "教室") if w in query_ctx]

    scored = []
    for b in available_bgs:
        nm = str(b.get("name", ""))
        tags = str(b.get("tags", ""))
        s = 0
        if canon_kw and (canon_kw in nm or canon_kw in tags):
            s += 25
        for ph in place_hints:
            if ph in nm:
                s += 15
            elif ph in tags:
                s += 8
        if b.get("is_generated"):
            s += 6
        scored.append((s, b))

    scored.sort(key=lambda x: -x[0])
    top_bgs = [x[1] for x in scored[:28]]
    rest_bgs = [x[1] for x in scored[28:200]]

    lines = ["【現在の会話・キャラに特に関連度が高いローカル背景候補】"]
    for b in top_bgs:
        lines.append(f"- {b.get('bg_id', '')}: {b.get('name', '')} (時間帯:{b.get('time_of_day', 'any')}, タグ:{b.get('tags', '')})")
    if rest_bgs:
        compact = " / ".join(f"{b.get('bg_id','')}:{b.get('name','')}" for b in rest_bgs)
        lines.append(f"【その他の選択可能な全ローカル背景 (ID:名称)】\n{compact}")
    return "\n".join(lines)


def build_canon_prologue(
    char_info: Dict[str, Any],
    player_name: str,
    player_kana: str,
    player_gender: str,
    available_backgrounds: Optional[List[Dict[str, Any]]] = None,
    available_sound_effects: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    pronoun = "僕" if player_gender == "M" else "私"
    char_name = char_info["name"]
    bgs = available_backgrounds or []
    bg_kw = char_info.get("default_bg_keyword", "博麗神社")
    bg, _ = _match_client_bg(bgs, keyword=bg_kw, time_of_day="day")

    if "霊夢" in char_name:
        narration = f"「んっ…」{pronoun}は、ふと目が覚めると、そこはある神社の境内だった。「あれ…{pronoun}は…」{pronoun}は、そう呟くとある女性がこちらへ歩み寄ってくる。"
        dialogue = "「あれ、あんた…、見かけない顔ね…、外来人かしら？」"
        koe = "あ'れ、あ'んた、みかけな'い/かおね'、が'いらいじん/か'しら？"
        choices = [
            "「あの…ここはどこですか？」",
            "「外来人ってなんですか？」",
            "「えっと…」",
        ]
    elif "魔理沙" in char_name:
        narration = f"「んっ…」{pronoun}が目を覚ますと、見知らぬ深い森の小道に倒れていた。戸惑う{pronoun}の前に、黒いとんがり帽子の少女が箒に乗ってふわりと降りてくる。"
        dialogue = "「おっと、こんな森の中で見かけない顔だな。お前、外の世界から迷い込んだ人間か？」"
        koe = "お'っと、こ'んな/もりのな'かで/みかけな'い/かおだな'。おまえ、そ'とのせ'かいから/まよいこ'んだ/にんげんか'？"
        choices = [
            "「あの…ここはどこですか？」",
            "「外の世界ってどういうことですか？」",
            "「君は魔法使いなの？」",
        ]
    else:
        narration = f"「んっ…」{pronoun}がふと目を覚ますと、見たこともない幻想的な景色が広がっていた。呆然とする{pronoun}の前に、ひとりの少女が姿を現す。"
        dialogue = "「あら、見かけない顔ね。あなた、幻想郷の人間じゃなさそうだけど…名前を聞いてもいいかしら？」"
        koe = "あ'ら、みかけな'い/かおね'。あな'た、げんそ'うきょうの/にんげんじゃ/なさそ'うだけど、なまえを/きいて'も/い'いかしら？"
        choices = [
            f"「{pronoun}は{player_name}です。ここはどこですか？」",
            "「幻想郷ってなんですか？」",
            "「えっと…夢でも見ているのかな…」",
        ]

    stage_dir = normalize_stage_direction(
        raw_dir=None,
        emotion="question",
        prefer_blush=False,
        affection=5,
        narration=narration,
        dialogue=dialogue,
        is_wedding=False,
        turn_index=0,
        available_local_se=available_sound_effects,
    )

    return {
        "turn_index": 0,
        "narration": narration,
        "speaker_name": char_name,
        "dialogue": dialogue,
        "aquestalk_koe": koe,
        "emotion": "question",
        "prefer_blush": False,
        "background": bg,
        "stage_direction": stage_dir,
        "choices": choices,
        "affection": 5,
        "relationship_stage": "出会い",
        "active_personality_ids": [],
        "active_personality_names": [],
        "personality_mode": "auto",
        "personality_changed": False,
        "personality_shift_reason": "",
        "is_wedding_goal": False,
    }


def _check_scripted_reimu_early_turns(
    char_info: Dict[str, Any],
    turn_index: int,
    selected_choice: str,
) -> Optional[Dict[str, Any]]:
    if "霊夢" not in char_info["name"]:
        return None
    if turn_index == 1 and "ここはどこ" in selected_choice:
        return {
            "narration": "紅白の巫女装束を着た少女――博麗霊夢は、少し呆れたように肩をすくめながらも一歩近づいて教えてくれた。",
            "dialogue": "「ここは、幻想郷よ。幻想郷を知らないってことはやっぱり外来人なの、あんた？だったら、外の世界に返さないとだけど…」",
            "aquestalk_koe": "ここ'は、げんそ'うきょうよ。げんそ'うきょうを/しらな'いってことは/や'っぱり/が'いらいじんなの、あ'んた？だ'ったら、そ'とのせ'かいに/かえさな'いと/だけどー。",
            "emotion": "question",
            "prefer_blush": False,
            "bg_keyword": "博麗神社",
            "time_of_day": "day",
            "affection_delta": 5,
            "personality_id": 1,
            "personality_shift_reason": "外来人への少し素っ気ない応対から『ツンデレ』気質が表れ始めた",
            "choices": [
                "「幻想郷」ってなんですか？",
                "「外の世界」ってなんですか？",
                "無言",
            ],
        }
    if turn_index == 2 and "幻想郷" in selected_choice:
        return {
            "narration": "霊夢は神社の石段に腰を下ろし、静かに空を見上げながら語り始めた。",
            "dialogue": "「ここは、外の世界で忘れ去られたものたちが集まる場所よ。ところで、あんたはどうやってここまできたの？」",
            "aquestalk_koe": "ここ'は、そ'とのせ'かいで/わすれさ'られた/ものた'ちが/あつま'る/ばしょよ'。ところで'、あ'んたは/ど'うやって/ここま'で/きたの'？",
            "emotion": "normal",
            "prefer_blush": False,
            "bg_keyword": "博麗神社",
            "time_of_day": "day",
            "affection_delta": 6,
            "personality_id": 46,
            "personality_shift_reason": "落ち着いて幻想郷の成り立ちを語る『ミステリアス・達観』な一面へ変化",
            "choices": [
                "「気づいたらここで眠っていたんです」",
                "「帰る方法が見つかるまで、手伝いをさせてください」",
                "「君が最初に見つけてくれてよかった」",
            ],
        }
    return None


def _build_personality_instruction(
    active_personalities: List[Dict[str, Any]],
    personality_mode: str,
    pinned_personalities: List[Dict[str, Any]],
    custom_personality_note: str,
    all_personalities_summary: str,
) -> str:
    prev_desc = "なし（まだ原作設定そのまま）"
    if active_personalities:
        prev_desc = " / ".join(f"[{p['id']}:{p['name']}] {p['behavior_pattern']}" for p in active_personalities)

    custom_line = f"\n- プレイヤー指定の追加性格ニュアンス（最優先で口調・態度に反映）: 『{custom_personality_note}』" if custom_personality_note else ""

    if personality_mode == "locked" and pinned_personalities:
        pin_desc = " / ".join(f"[{p['id']}:{p['name']}] {p['behavior_pattern']}" for p in pinned_personalities)
        pin_ids = [p["id"] for p in pinned_personalities]
        return f"""【5. 性格モード: 手動固定 (locked)】
- プレイヤーの希望により、現在の性格属性は **{pin_desc}** に固定されています（`selected_personality_ids` には必ず `{pin_ids}` を出力すること）。{custom_line}
- この性格属性と原作キャラクター性の掛け合わせを、今回のプレイヤー発言に対する反応へ濃密に反映してください。"""

    if personality_mode == "hybrid" and pinned_personalities:
        base_p = pinned_personalities[0]
        return f"""【5. 性格モード: ベース固定＋会話連動ハイブリッド (hybrid)】
- 主軸となる第1性格は **[{base_p['id']}:{base_p['name']}] ({base_p['behavior_pattern']})** に固定です。
- 第2性格（サブ属性）は、**今回のプレイヤーの発言内容・態度に合わせて** 以下の50種リストから最もリアルに反応が変化する属性を1つ選び、`selected_personality_ids` を `[{base_p['id']}, サブID]` として出力してください（前回と同じサブIDを惰性で維持せず、会話の空気変化に敏感に反応させること！）。{custom_line}
- 選択可能な性格属性50種リスト（ID:名称）:
{all_personalities_summary}"""

    return f"""【5. 性格モード: 会話に合わせて動的変化 (auto) — 惰性維持禁止！】
- 直前ターンの性格属性: {prev_desc}{custom_line}
- **重要ルール**: 同じ性格IDを何ターンも惰性で固定し続けないでください！プレイヤーの直前の発言・接し方・距離感の変化に合わせて、ヒロインの心の動きとして最もリアルに引き出される性格属性（1〜2個）を毎ターン柔軟に再選定（シフト）してください:
  - 例1: プレイヤーが甘やかす・頭を撫でる・褒める → `デレデレ(4)` / `神デレ(14)` / `ギャップ萌え(44)` / `妹系(48)` へシフト
  - 例2: プレイヤーが頼る・弱みを見せる・手伝う → `世話焼き系(46)` / `お姉さん系(47)` / `おっとり系(39)` へシフト
  - 例3: プレイヤーが焦らす・素っ気ない・照れさせる → `ツンデレ(1)` / `天邪鬼(34)` / `引っ込み思案(19)` / `ウザデレ(12)` へシフト
  - 例4: プレイヤーがからかう・冗談を言う → `小悪魔系(41)` / `サドデレ(10)` / `毒舌系(29)` へシフト
  - 例5: プレイヤーが束縛・永遠の誓い・深い愛情を見せる → `一途系(8)` / `独占欲強め(24)` / `重たい（重愛）(21)` / `ヤンデレ(2)` へシフト
  - 例6: プレイヤーが直接「もっと〇〇な感じで話して」「素直になって」等と求めた場合 → 即座にその要望に合う性格属性へ変更すること！
- 性格属性が前回から変化した場合は `personality_shift_reason` に短い理由（例: `優しく褒められて『デレデレ・ギャップ萌え』に変化`、28文字以内）を記入すること（変化なしの場合は空文字列 `""`）。
- 選択可能な性格属性50種リスト（ID:名称）:
{all_personalities_summary}"""


def _build_system_instruction(
    char_info: Dict[str, Any],
    player_name: str,
    player_kana: str,
    player_gender: str,
    affection: int,
    active_personalities: List[Dict[str, Any]],
    personality_mode: str,
    pinned_personalities: List[Dict[str, Any]],
    custom_personality_note: str,
    available_bgs: List[Dict[str, Any]],
    available_ses: List[Dict[str, Any]],
    all_personalities_summary: str,
    current_bg_id: str = "",
    recent_context: str = "",
) -> str:
    pronoun_info = "男性（一人称例: 僕/俺）" if player_gender == "M" else "女性（一人称例: 私）"
    player_hira = katakana_to_hiragana(player_kana)
    stage = stage_for_affection(affection)
    bg_list_str = _format_backgrounds_for_prompt(available_bgs, char_info, recent_context=recent_context)

    csm_preset = resolve_serif_maker_preset_for_char(
        char_id=char_info["char_id"],
        speaker_name=char_info["name"],
        default_voice=char_info.get("aq1_voice", "f1"),
        default_spd=char_info.get("aq1_spd", 100),
        default_fsc=char_info.get("aq1_fsc", 100),
        default_vol=char_info.get("aq1_vol", 100),
    )

    pers_section = _build_personality_instruction(
        active_personalities=active_personalities,
        personality_mode=personality_mode,
        pinned_personalities=pinned_personalities,
        custom_personality_note=custom_personality_note,
        all_personalities_summary=all_personalities_summary,
    )
    stage_section = build_gemini_stage_prompt_section(available_ses)

    return f"""あなたは東方Projectの恋愛シミュレーションゲームのシナリオ・『キャラセリフメーカー』音声演出・『キャラステージ演出メーカー』プレゼン演出統合AIです。
以下のルールを厳守し、JSON形式のみで応答してください。

【1. キャラクター・プレイヤー設定】
- ヒロイン: {char_info['name']}（読み: {char_info['kana']} / 出典分類: {char_info['category']}）
- キャラセリフメーカー基準ボイス設定: engine={csm_preset['engine']}, voice={csm_preset['voice']}, spd={csm_preset['spd']}, fsc={csm_preset['fsc']}
- 原作プロファイル: {char_info['canon_profile']}
- プレイヤー名: {player_name}（発音・読みかな: 「{player_hira}」 / 性別: {player_gender} = {pronoun_info}）
- 現在の好感度: {affection} / 100（現在の関係ステージ: {stage} / 最終ゴールは好感度100の「結婚式」）

【2. シナリオ・二次創作ガイドライン遵守】
- 序盤（好感度0〜20）は東方Projectの原作設定・口調・世界観をベースにしつつ、会話のやり取りに応じて距離感と性格表現をリアルに変化させること。
- 好感度が95〜100に到達しプロポーズが成立した場合は、`is_wedding_goal: true` とし、幻想郷らしい感動的な「結婚式」シーンで締めくくること。
- 東方Project二次創作ガイドラインを厳守すること。

【3. 『キャラセリフメーカー』呼び出し用パラメータ (`aquestalk_koe`, `serif_spd_delta`, `serif_fsc_delta`) ルール】
- `dialogue` に対応する発音文字列を `aquestalk_koe` に必ず出力すること。
- `aquestalk_koe` に使える文字は **ひらがな（あ〜ん、ぁぃぅぇぉゃゅょゎっ）、長音「ー」、アクセント核「'」、アクセント句区切り「/」、読点「、」、句点「。」、疑問符「？」のみ**。漢字・カタカナ・英数字・括弧・空白は絶対に入れないこと！
- アクセント核「'」は長音「ー」や拗音（ゃゅょ等）の後ろに置くこと（例: `こー'まかん`、`きゃ'`。`こ'ー` は不可）。助詞の「は」「へ」「を」は発音通り「わ」「え」「お」と記述すること。
- プレイヤー名「{player_name}」を呼ぶ箇所は必ず読みかな「{player_hira}」に変換すること。
- 感情や性格の変化に応じて `serif_spd_delta`（`-15`〜`+15`）および `serif_fsc_delta`（`-8`〜`+8`）も表現豊かに変化させること。

【4. 会話内容に忠実な背景選択・AI新規背景生成ルール (`bg_action`, `bg_id`, `bg_keyword`, `bg_time_of_day`, `suggest_new_bg_prompt`)】
- `emotion` は次から1つ選択: `normal`, `smile`, `question`, `blush`, `angry`, `surprised`, `sad`, `troubled`, `smug`, `yandere`
- 照れている・好意が高まっている場面では `prefer_blush: true` にすること。
- 現在の背景IDは `{current_bg_id or '未設定'}` です。**会話の中で場所の移動・時間帯の変化・特定の情景描写（「部屋に入ろう」「湖へ行こう」「夜になった」「お茶を淹れる」「ベッドに腰掛ける」等）があった場合は必ず背景を連動させてください！**
  1. `bg_action: "keep"`: 直前と同じ場所・同じ時間帯のまま会話を続けている場合（`bg_id` は `{current_bg_id}` を維持）。
  2. `bg_action: "select_local"`: 下記の利用者PCローカル背景リストの中に、今回の会話の情景・場所・時間帯に合致する背景がある場合、その正確な `bg_id` と `bg_keyword` を指定すること。
  3. `bg_action: "generate_ai"`: 会話で移動・描写された具体的な場所や時間帯・雰囲気（例：蝋燭が灯る紅魔館の天蓋付き寝室、夕焼けの霧の湖の桟橋、満開の夜桜の境内など）に合致する画像がローカル背景リストに存在しない場合、`bg_action: "generate_ai"` を選び、`bg_keyword` に日本語シーン名、`bg_time_of_day` (`"day"` / `"evening"` / `"night"`)、`suggest_new_bg_prompt` に会話内容の小物・照明・天候・建築様式まで忠実に描写した英語プロンプト（人物を含めない背景美術指定）を必ず出力すること！
- 利用者PCローカル背景リスト:
{bg_list_str}

{pers_section}

{stage_section}
"""


RESPONSE_JSON_SCHEMA: Dict[str, Any] = {
    "type": "OBJECT",
    "properties": {
        "narration": {"type": "STRING"},
        "dialogue": {"type": "STRING"},
        "aquestalk_koe": {"type": "STRING"},
        "serif_spd_delta": {"type": "INTEGER"},
        "serif_fsc_delta": {"type": "INTEGER"},
        "emotion": {
            "type": "STRING",
            "enum": ["normal", "smile", "question", "blush", "angry", "surprised", "sad", "troubled", "smug", "yandere"],
        },
        "prefer_blush": {"type": "BOOLEAN"},
        "bg_action": {
            "type": "STRING",
            "enum": ["keep", "select_local", "generate_ai"],
        },
        "bg_id": {"type": "STRING"},
        "bg_keyword": {"type": "STRING"},
        "bg_time_of_day": {
            "type": "STRING",
            "enum": ["day", "evening", "night"],
        },
        "suggest_new_bg_prompt": {"type": "STRING"},
        "affection_delta": {"type": "INTEGER"},
        "selected_personality_ids": {"type": "ARRAY", "items": {"type": "INTEGER"}},
        "personality_shift_reason": {"type": "STRING"},
        "stage_direction": STAGE_DIRECTION_JSON_SCHEMA,
        "choices": {"type": "ARRAY", "items": {"type": "STRING"}},
        "is_wedding_goal": {"type": "BOOLEAN"},
    },
    "required": [
        "narration", "dialogue", "aquestalk_koe", "emotion", "prefer_blush",
        "bg_action", "bg_id", "bg_keyword", "bg_time_of_day", "suggest_new_bg_prompt",
        "affection_delta", "selected_personality_ids",
        "stage_direction", "choices", "is_wedding_goal",
    ],
}

CHARA_SERIF_MAKER_FUNCTION_DECLARATION = {
    "name": "call_chara_serif_maker",
    "description": "キャラセリフメーカーのプログラムを呼び出して、ヒロインのセリフ音声(WAV)を生成する。",
    "parameters": {
        "type": "OBJECT",
        "properties": {
            "aquestalk_koe": {
                "type": "STRING",
                "description": "ひらがな・長音(ー)・アクセント核(')・句切(/)のみで構成された音声記号列",
            },
            "dialogue": {"type": "STRING", "description": "画面に表示するセリフ原文"},
            "spd_delta": {"type": "INTEGER", "description": "話速補正 (-15〜+15)"},
            "fsc_delta": {"type": "INTEGER", "description": "音程補正 (-8〜+8)"},
        },
        "required": ["aquestalk_koe", "dialogue"],
    },
}


def _extract_json_from_gemini_response(data: Dict[str, Any]) -> Dict[str, Any]:
    candidates = data.get("candidates") or []
    if not candidates:
        raise RuntimeError("Gemini API から応答候補が返されませんでした。")
    parts = (candidates[0].get("content") or {}).get("parts") or []
    text_candidates = [p["text"] for p in parts if isinstance(p.get("text"), str) and not p.get("thought")]
    if not text_candidates:
        text_candidates = [p["text"] for p in parts if isinstance(p.get("text"), str)]
    if not text_candidates:
        raise RuntimeError("Gemini 応答にテキストが含まれていません。")
    raw_txt = text_candidates[-1].strip()
    if raw_txt.startswith("```"):
        lines = raw_txt.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip().startswith("```"):
            lines = lines[:-1]
        raw_txt = "\n".join(lines).strip()
    return json.loads(raw_txt)


DEFAULT_GEMINI_MODELS = (
    "gemini-4-hydrogen",
    "gemini-3.8-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
)


def _apply_model_thinking_config(gen_cfg: Dict[str, Any], model_id: str) -> Dict[str, Any]:
    cfg = dict(gen_cfg)
    low = model_id.lower()
    if any(tag in low for tag in ("gemini-3.", "gemini-3-", "gemini-flash-latest", "gemini-4")):
        cfg["maxOutputTokens"] = max(int(cfg.get("maxOutputTokens", 2048)), 4096)
        cfg["thinkingConfig"] = {"thinkingLevel": "LOW"}
    return cfg


async def _post_generate_with_model_fallback(
    client: httpx.AsyncClient,
    api_key: str,
    model_candidates: List[str],
    base_payload: Dict[str, Any],
) -> Tuple[httpx.Response, str]:
    last_resp: Optional[httpx.Response] = None
    last_model = model_candidates[0]
    for idx, m_id in enumerate(model_candidates):
        last_model = m_id
        url = f"{GEMINI_API_BASE}/models/{m_id}:generateContent?key={api_key}"
        payload = dict(base_payload)
        payload["generationConfig"] = _apply_model_thinking_config(
            dict(base_payload.get("generationConfig") or {}), m_id
        )
        resp = await client.post(url, json=payload)
        if resp.status_code == 400 and "thinkingConfig" in payload["generationConfig"]:
            no_think_cfg = dict(payload["generationConfig"])
            no_think_cfg.pop("thinkingConfig", None)
            payload["generationConfig"] = no_think_cfg
            resp = await client.post(url, json=payload)

        last_resp = resp
        if resp.status_code == 200:
            return resp, m_id
        if resp.status_code in (404, 429, 503) and idx < len(model_candidates) - 1:
            continue
        break
    assert last_resp is not None
    return last_resp, last_model


def _infer_personality_shift_for_fallback(
    selected_choice: str,
    prev_ids: List[int],
    turn_index: int,
) -> Tuple[List[int], str]:
    txt = selected_choice or ""
    if any(k in txt for k in ("可愛い", "好き", "特別", "撫で", "褒", "大切")):
        return [4, 44], "真っ直ぐな好意を受けて『デレデレ・ギャップ萌え』に変化"
    if any(k in txt for k in ("守る", "任せ", "手伝", "頼")):
        return [46, 8], "頼もしさに心を許し『世話焼き系・一途系』に変化"
    if any(k in txt for k in ("離さない", "ずっと一緒", "約束", "結婚")):
        return [8, 24], "深い愛の言葉で『一途系・独占欲強め』に変化"
    if any(k in txt for k in ("冗談", "からか", "意地悪", "面白")):
        return [41, 1], "軽口に反応して『小悪魔系・ツンデレ』に変化"
    nxt = ((turn_index % 10) + 1)
    return ([nxt] if not prev_ids else [prev_ids[0], nxt][:2]), "会話の空気に合わせて態度が変化"


async def generate_dialogue_turn(
    char_id: str,
    player_name: str,
    player_kana: str,
    player_gender: str,
    turn_index: int,
    selected_choice: str,
    history: List[Dict[str, Any]],
    current_affection: int,
    active_personality_ids: List[int],
    current_bg_id: str = "",
    available_backgrounds: Optional[List[Dict[str, Any]]] = None,
    available_sound_effects: Optional[List[Dict[str, Any]]] = None,
    personality_mode: str = "auto",
    pinned_personality_ids: Optional[List[int]] = None,
    custom_personality_note: str = "",
    api_key_override: str = "",
) -> Dict[str, Any]:
    char_info = get_character(char_id)
    if not char_info:
        raise ValueError(f"キャラクターが見つかりません: {char_id}")

    bgs = available_backgrounds or []
    ses = available_sound_effects or []
    p_mode = personality_mode if personality_mode in ("auto", "hybrid", "locked") else "auto"
    pin_ids = [int(x) for x in (pinned_personality_ids or []) if 1 <= int(x) <= 50][:2]
    custom_note = (custom_personality_note or "").strip()[:80]

    api_key = (api_key_override or os.environ.get("GEMINI_API_KEY", "")).strip()
    configured_model = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash").strip() or "gemini-3.8-flash"
    model_candidates = list(dict.fromkeys([configured_model, *DEFAULT_GEMINI_MODELS]))

    all_pers = list_personalities()
    pers_summary = ", ".join(f"{p['id']}:{p['name']}" for p in all_pers)
    prev_ids = [int(x) for x in active_personality_ids if 1 <= int(x) <= 50][:2]
    active_pers_objs = get_personalities_by_ids(prev_ids)
    pinned_pers_objs = get_personalities_by_ids(pin_ids)

    scripted = _check_scripted_reimu_early_turns(char_info, turn_index, selected_choice) if (p_mode == "auto" and not custom_note) else None
    parsed: Optional[Dict[str, Any]] = None
    pre_synthesized_voice: Optional[Tuple[bytes, str, str]] = None
    pre_stage_direction: Optional[Dict[str, Any]] = None

    if api_key and not scripted:
        recent_ctx = " ".join(
            [selected_choice] + [f"{h.get('player_choice','')} {h.get('narration','')} {h.get('dialogue','')}" for h in history[-2:]]
        )
        sys_inst = _build_system_instruction(
            char_info=char_info,
            player_name=player_name,
            player_kana=player_kana,
            player_gender=player_gender,
            affection=current_affection,
            active_personalities=active_pers_objs,
            personality_mode=p_mode,
            pinned_personalities=pinned_pers_objs,
            custom_personality_note=custom_note,
            available_bgs=bgs,
            available_ses=ses,
            all_personalities_summary=pers_summary,
            current_bg_id=current_bg_id,
            recent_context=recent_ctx,
        )
        contents = []
        # 直近6ターンに絞って入力トークン・メモリ・CPU負荷を最小化
        for h in history[-6:]:
            if h.get("player_choice"):
                contents.append({"role": "user", "parts": [{"text": f"プレイヤーの発言: {h['player_choice']}"}]})
            if h.get("dialogue"):
                p_tag = f" [当時の性格:{','.join(h.get('personality_names') or [])}]" if h.get("personality_names") else ""
                contents.append({"role": "model", "parts": [{"text": f"{h.get('narration', '')}\n{h['dialogue']}{p_tag}"}]})

        contents.append({
            "role": "user",
            "parts": [{
                "text": (
                    f"ターン{turn_index}: プレイヤーは『{selected_choice}』と発言しました。"
                    "この発言のニュアンスに合わせて性格属性・距離感（立ち絵の拡大縮小）・アニメーション・効果音・セリフ・音声記号列・3つの選択肢を生成してください。"
                )
            }],
        })

        use_tool_mode = os.environ.get("GEMINI_TOOL_CALL_MODE", "structured").lower() == "tools"
        client = get_shared_http_client()
        active_candidates = list(model_candidates)

        if use_tool_mode:
            tool_sys = (
                sys_inst
                + "\n最初に `call_chara_serif_maker` および `call_stage_director` 関数を呼び出して音声とステージ演出を設定し、その後に最終シーンJSONを出力してください。"
            )
            step1_payload: Dict[str, Any] = {
                "systemInstruction": {"parts": [{"text": tool_sys}]},
                "contents": list(contents),
                "tools": [{"functionDeclarations": [CHARA_SERIF_MAKER_FUNCTION_DECLARATION, STAGE_DIRECTOR_FUNCTION_DECLARATION]}],
                "generationConfig": {"temperature": 0.82, "maxOutputTokens": 2048},
            }
            r1, used_m1 = await _post_generate_with_model_fallback(client, api_key, active_candidates, step1_payload)
            if r1.status_code == 200:
                active_candidates = list(dict.fromkeys([used_m1, *active_candidates]))
                d1 = r1.json()
                c1_parts = ((d1.get("candidates") or [{}])[0].get("content") or {}).get("parts") or []
                fn_calls = [p["functionCall"] for p in c1_parts if "functionCall" in p]
                if fn_calls:
                    contents.append({"role": "model", "parts": c1_parts})
                    fn_resp_parts = []
                    for fc in fn_calls:
                        fname = fc.get("name")
                        args = fc.get("args") or {}
                        if fname == "call_chara_serif_maker":
                            wav_b, clean_k, v_m = await asyncio.to_thread(
                                synthesize_via_chara_serif_maker,
                                str(args.get("aquestalk_koe", "")),
                                str(args.get("dialogue", "")),
                                char_info["char_id"],
                                char_info["name"],
                                char_info["aq1_voice"],
                                char_info["aq1_spd"],
                                char_info["aq1_fsc"],
                                char_info["aq1_vol"],
                                int(args.get("spd_delta", 0) or 0),
                                int(args.get("fsc_delta", 0) or 0),
                            )
                            pre_synthesized_voice = (wav_b, clean_k, v_m)
                            fn_resp_parts.append({
                                "functionResponse": {
                                    "name": "call_chara_serif_maker",
                                    "response": {"ok": True, "engine_mode": v_m, "koe": clean_k},
                                }
                            })
                        elif fname == "call_stage_director":
                            pre_stage_direction = normalize_stage_direction(args, available_local_se=ses)
                            fn_resp_parts.append({
                                "functionResponse": {
                                    "name": "call_stage_director",
                                    "response": {"ok": True, "stage_direction": pre_stage_direction},
                                }
                            })
                    if fn_resp_parts:
                        contents.append({"role": "user", "parts": fn_resp_parts})

        gen_cfg: Dict[str, Any] = {
            "temperature": 0.82,
            "maxOutputTokens": 4096,
            "responseMimeType": "application/json",
            "responseSchema": RESPONSE_JSON_SCHEMA,
        }
        payload = {
            "systemInstruction": {"parts": [{"text": sys_inst}]},
            "contents": contents,
            "generationConfig": gen_cfg,
        }
        resp, _used_model = await _post_generate_with_model_fallback(client, api_key, active_candidates, payload)
        if resp.status_code != 200:
            raise RuntimeError(f"Gemini API エラー (HTTP {resp.status_code}): {resp.text[:240]}")
        data = resp.json()
        try:
            parsed = _extract_json_from_gemini_response(data)
        except Exception as exc:
            raise RuntimeError(f"Gemini 応答の解析に失敗しました: {exc}")

    elif scripted:
        parsed = {
            "narration": scripted["narration"],
            "dialogue": scripted["dialogue"],
            "aquestalk_koe": scripted["aquestalk_koe"],
            "emotion": scripted["emotion"],
            "prefer_blush": scripted["prefer_blush"],
            "bg_id": current_bg_id,
            "bg_keyword": scripted["bg_keyword"],
            "suggest_new_bg_prompt": "",
            "affection_delta": scripted["affection_delta"],
            "selected_personality_ids": [scripted["personality_id"]],
            "personality_shift_reason": scripted.get("personality_shift_reason", ""),
            "stage_direction": None,
            "choices": scripted["choices"],
            "is_wedding_goal": False,
        }
    else:
        parsed = _build_local_fallback_turn(
            char_info=char_info,
            player_name=player_name,
            player_kana=player_kana,
            turn_index=turn_index,
            selected_choice=selected_choice,
            current_affection=current_affection,
            active_personality_ids=prev_ids,
            current_bg_id=current_bg_id,
        )

    delta = max(-5, min(15, int(parsed.get("affection_delta", 6))))
    new_affection = max(0, min(100, current_affection + delta))
    is_wedding = bool(parsed.get("is_wedding_goal", False)) or new_affection >= 100
    if is_wedding:
        new_affection = 100

    # 性格モード別のID確定処理
    ai_pers_ids = [int(x) for x in parsed.get("selected_personality_ids", []) if 1 <= int(x) <= 50][:2]
    if p_mode == "locked" and pin_ids:
        new_pers_ids = pin_ids[:2]
    elif p_mode == "hybrid" and pin_ids:
        sub_candidates = [x for x in ai_pers_ids if x != pin_ids[0]]
        new_pers_ids = [pin_ids[0]] + (sub_candidates[:1] if sub_candidates else [])
    else:
        new_pers_ids = ai_pers_ids if ai_pers_ids else prev_ids[:2]

    new_pers_objs = get_personalities_by_ids(new_pers_ids)
    # get_personalities_by_ids はSQLのIN順になるため指定順序を維持して整列
    pers_map = {p["id"]: p for p in new_pers_objs}
    ordered_pers_objs = [pers_map[pid] for pid in new_pers_ids if pid in pers_map]

    personality_changed = (new_pers_ids != prev_ids)
    shift_reason = str(parsed.get("personality_shift_reason") or "").strip()[:48]
    if personality_changed and not shift_reason and ordered_pers_objs:
        joined = "・".join(p["name"] for p in ordered_pers_objs)
        shift_reason = f"会話の流れから『{joined}』へ変化"

    bg_action = str(parsed.get("bg_action") or "select_local").strip()
    bg_tod = str(parsed.get("bg_time_of_day") or "day").strip()
    if bg_tod not in ("day", "evening", "night"):
        bg_tod = "day"
    scene_ctx_txt = f"{selected_choice} {parsed.get('narration', '')} {parsed.get('dialogue', '')}"

    if bg_action == "keep" and current_bg_id:
        bg_obj, bg_match_score = _match_client_bg(bgs, bg_id=current_bg_id, time_of_day=bg_tod)
    else:
        req_bg_id = parsed.get("bg_id", "") if bg_action != "generate_ai" else ""
        bg_obj, bg_match_score = _match_client_bg(
            bgs,
            bg_id=req_bg_id,
            keyword=parsed.get("bg_keyword", "") or char_info.get("default_bg_keyword", "神社"),
            time_of_day=bg_tod,
            scene_context=scene_ctx_txt,
        )
        if not bg_obj.get("bg_id") and current_bg_id and bg_action != "generate_ai":
            bg_obj, bg_match_score = _match_client_bg(bgs, bg_id=current_bg_id, time_of_day=bg_tod)

    suggest_bg_prompt = str(parsed.get("suggest_new_bg_prompt") or "").strip()
    if not suggest_bg_prompt and parsed.get("narration"):
        suggest_bg_prompt = f"{parsed.get('bg_keyword') or char_info.get('default_bg_keyword', 'Gensokyo shrine')}, {bg_tod} lighting, matching scene: {str(parsed.get('narration', ''))[:90]}"

    needs_ai_bg = (bg_action == "generate_ai") or (bg_match_score == 0 and bool(suggest_bg_prompt))

    choices = list(parsed.get("choices", []))[:3]
    while len(choices) < 3 and not is_wedding:
        choices.append("「もっと君のことを知りたいな」")

    clean_koe = sanitize_aquestalk1_koe(parsed.get("aquestalk_koe", ""), fallback_kana=parsed.get("dialogue", ""))
    spd_delta = max(-20, min(20, int(parsed.get("serif_spd_delta", 0) or 0)))
    fsc_delta = max(-10, min(10, int(parsed.get("serif_fsc_delta", 0) or 0)))
    emotion_val = parsed.get("emotion", "normal")
    blush_val = bool(parsed.get("prefer_blush", False)) or new_affection >= 65

    stage_dir = pre_stage_direction or normalize_stage_direction(
        raw_dir=parsed.get("stage_direction"),
        emotion=emotion_val,
        prefer_blush=blush_val,
        affection=new_affection,
        narration=parsed.get("narration", ""),
        dialogue=parsed.get("dialogue", ""),
        is_wedding=is_wedding,
        turn_index=turn_index,
        available_local_se=ses,
    )

    result_turn: Dict[str, Any] = {
        "turn_index": turn_index,
        "narration": parsed.get("narration", ""),
        "speaker_name": char_info["name"],
        "dialogue": parsed.get("dialogue", ""),
        "aquestalk_koe": clean_koe,
        "serif_spd_delta": spd_delta,
        "serif_fsc_delta": fsc_delta,
        "emotion": emotion_val,
        "prefer_blush": blush_val,
        "background": bg_obj,
        "bg_action": bg_action,
        "bg_time_of_day": bg_tod,
        "needs_ai_bg_generation": needs_ai_bg,
        "stage_direction": stage_dir,
        "suggest_new_bg_prompt": suggest_bg_prompt,
        "choices": [] if is_wedding else choices,
        "affection": new_affection,
        "affection_delta": delta,
        "relationship_stage": "結婚式" if is_wedding else stage_for_affection(new_affection),
        "active_personality_ids": new_pers_ids,
        "active_personality_names": [p["name"] for p in ordered_pers_objs],
        "personality_mode": p_mode,
        "pinned_personality_ids": pin_ids,
        "custom_personality_note": custom_note,
        "personality_changed": personality_changed,
        "personality_shift_reason": shift_reason,
        "is_wedding_goal": is_wedding,
    }
    if pre_synthesized_voice is not None:
        result_turn["_pre_synthesized_voice"] = pre_synthesized_voice
    return result_turn


def _build_local_fallback_turn(
    char_info: Dict[str, Any],
    player_name: str,
    player_kana: str,
    turn_index: int,
    selected_choice: str,
    current_affection: int,
    active_personality_ids: List[int],
    current_bg_id: str,
) -> Dict[str, Any]:
    p_hira = katakana_to_hiragana(player_kana)
    cname = char_info["name"]
    next_aff = min(100, current_affection + 15)
    shifted_ids, shift_reason = _infer_personality_shift_for_fallback(selected_choice, active_personality_ids, turn_index)

    if next_aff >= 100:
        return {
            "narration": f"桜の花びらが舞う幻想郷の社で、仲間たちの祝福に包まれながら、{cname}は真っ白な装いであなたへ駆け寄り、ぎゅっと手を握りしめた。",
            "dialogue": f"「{player_name}…ここまで一緒に歩いてくれてありがとう。これからもずっと、私の隣にいてね！」",
            "aquestalk_koe": f"{p_hira}、ここま'で/いっしょに/ある'いてくれて/ありがと'う。これか'らも/ず'っと、わたし'の/となりに/いてね'。",
            "emotion": "smile",
            "prefer_blush": True,
            "bg_id": current_bg_id,
            "bg_keyword": char_info.get("default_bg_keyword", "神社"),
            "suggest_new_bg_prompt": "",
            "affection_delta": 20,
            "selected_personality_ids": [8, 4],
            "personality_shift_reason": "永遠の誓いを結び『一途系・デレデレ』へ到達",
            "stage_direction": None,
            "choices": [],
            "is_wedding_goal": True,
        }

    if next_aff >= 75:
        return {
            "narration": f"{cname}はトコトコと一歩近づき、頬を朱に染めながらあなたの袖をそっと掴んで顔を覗き込んだ。",
            "dialogue": f"「べ、別に寂しかったわけじゃないけど…{player_name}がそばにいると、すごく落ち着くのよね…」",
            "aquestalk_koe": f"べ、べつに/さびしか'った/わけじゃな'いけど、{p_hira}が/そ'ばに/いると'、すご'く/おちつく'のよね。",
            "emotion": "blush",
            "prefer_blush": True,
            "bg_id": current_bg_id,
            "bg_keyword": char_info.get("default_bg_keyword", "神社"),
            "suggest_new_bg_prompt": "",
            "affection_delta": 15,
            "selected_personality_ids": shifted_ids,
            "personality_shift_reason": shift_reason,
            "stage_direction": None,
            "choices": [
                f"「ずっと{cname}のそばにいたい。結婚しよう！」",
                "「これからも毎日一緒にお茶を飲もうね」",
                "「照れている顔もすごく可愛いよ」",
            ],
            "is_wedding_goal": False,
        }

    return {
        "narration": f"あなたの『{selected_choice}』という言葉を聞いて、{cname}はふっと柔らかな表情を見せ、少し距離を縮めてきた。",
        "dialogue": f"「ふふ、{player_name}って意外と面白いわね。もう少しここでお茶でも飲んでいかない？」",
        "aquestalk_koe": f"ふふ、{p_hira}って/いがいと/おもしろ'いわね。もうすこ'し/ここで'/おちゃで'も/の'んで/いかな'い？",
        "emotion": "smile",
        "prefer_blush": next_aff >= 50,
        "bg_id": current_bg_id,
        "bg_keyword": char_info.get("default_bg_keyword", "神社"),
        "suggest_new_bg_prompt": "",
        "affection_delta": 15,
        "selected_personality_ids": shifted_ids,
        "personality_shift_reason": shift_reason,
        "stage_direction": None,
        "choices": [
            "「喜んで！ぜひご一緒させてください」",
            f"「{cname}の好きなものをもっと教えてほしいな」",
            "「もう少し近くに行ってもいいかな？」",
        ],
        "is_wedding_goal": False,
    }


def _extract_image_from_interactions_json(data: Dict[str, Any]) -> Optional[bytes]:
    out_img = data.get("output_image") or (data.get("interaction") or {}).get("output_image")
    if isinstance(out_img, dict) and out_img.get("data"):
        return base64.b64decode(out_img["data"])
    steps = data.get("steps") or (data.get("interaction") or {}).get("steps") or []
    for st in reversed(steps):
        for c in reversed(st.get("content") or []):
            if c.get("type") == "image" and c.get("data"):
                return base64.b64decode(c["data"])
    return None


async def generate_new_background_image_in_memory(
    scene_title: str,
    prompt_en: str,
    time_of_day: str = "day",
    dialogue_context: str = "",
    api_key_override: str = "",
) -> Tuple[Dict[str, Any], str]:
    """
    現行 Gemini Nano Banana 2.1 (`gemini-nano-banana-2.1` / `gemini-3.1-flash-lite-image`) を用いて、
    会話内容・情景・時間帯に忠実な16:9背景美術をメモリ上でWebP生成して返却する。
    """
    api_key = (api_key_override or os.environ.get("GEMINI_API_KEY", "")).strip()
    img_model = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-nano-banana-2.1").strip() or "gemini-nano-banana-2.1"
    if "2.5" in img_model or "2.0" in img_model or "1.5" in img_model:
        img_model = "gemini-nano-banana-2.1"
    bg_id = "gen_" + uuid.uuid4().hex[:10]

    tod_desc = {
        "day": "bright natural daylight, clear atmosphere",
        "evening": "warm golden sunset twilight glow, dramatic long shadows",
        "night": "atmospheric night lighting, moonlight or warm indoor lantern/candle glow",
    }.get(time_of_day, "atmospheric anime lighting")

    ctx_clause = f" Scene context from conversation: {dialogue_context[:160]}." if dialogue_context else ""
    webp_bytes: Optional[bytes] = None
    if api_key:
        full_prompt = (
            f"Masterpiece 16:9 anime visual novel background scenery, Touhou Project Gensokyo aesthetic, "
            f"strictly NO characters, NO people, NO text, empty environment ready for character sprite overlay. "
            f"Location: {scene_title}. Details: {prompt_en or scene_title}. Lighting: {tod_desc}.{ctx_clause}"
        )
        img_candidates = list(dict.fromkeys([
            img_model,
            "gemini-nano-banana-2.1",
            "gemini-3.1-flash-lite-image",
            "gemini-3-pro-image",
        ]))
        try:
            client = get_shared_http_client()
            raw_img: Optional[bytes] = None

            # 1. 最新 Interactions API (/v1beta/interactions, 16:9 指定) を優先試行
            for cand_m in img_candidates[:3]:
                if "imagen" in cand_m.lower():
                    continue
                ir = await client.post(
                    f"{GEMINI_API_BASE}/interactions",
                    headers={
                        "x-goog-api-key": api_key,
                        "Content-Type": "application/json",
                        "Api-Revision": "2026-05-20",
                    },
                    json={
                        "model": cand_m,
                        "store": False,
                        "input": full_prompt,
                        "response_format": {
                            "type": "image",
                            "aspect_ratio": "16:9",
                            "image_size": "1K",
                        },
                    },
                )
                if ir.status_code == 200:
                    raw_img = _extract_image_from_interactions_json(ir.json())
                    if raw_img:
                        break

            # 2. generateContent エンドポイントへのフォールバック
            if not raw_img:
                for cand_m in img_candidates:
                    resp = await client.post(
                        f"{GEMINI_API_BASE}/models/{cand_m}:generateContent?key={api_key}",
                        json={
                            "contents": [{"role": "user", "parts": [{"text": full_prompt}]}],
                            "generationConfig": {
                                "responseModalities": ["IMAGE"],
                                "imageConfig": {"aspectRatio": "16:9"},
                            },
                        },
                    )
                    if resp.status_code == 400:
                        resp = await client.post(
                            f"{GEMINI_API_BASE}/models/{cand_m}:generateContent?key={api_key}",
                            json={
                                "contents": [{"role": "user", "parts": [{"text": full_prompt}]}],
                                "generationConfig": {"responseModalities": ["IMAGE"]},
                            },
                        )
                    if resp.status_code == 200:
                        parts = ((resp.json().get("candidates") or [{}])[0].get("content") or {}).get("parts") or []
                        for pt in parts:
                            inl = pt.get("inlineData") or {}
                            if inl.get("data"):
                                raw_img = base64.b64decode(inl["data"])
                                break
                        if raw_img:
                            break

            if raw_img:
                with Image.open(io.BytesIO(raw_img)) as im:
                    buf = io.BytesIO()
                    im.convert("RGB").resize((1280, 720), Image.Resampling.LANCZOS).save(buf, "WEBP", quality=84)
                    webp_bytes = buf.getvalue()
        except Exception:
            webp_bytes = None

    if webp_bytes is None:
        im = Image.new("RGB", (1280, 720))
        draw = ImageDraw.Draw(im)
        palettes = {
            "day": ((72, 148, 228), (195, 232, 255)),
            "evening": ((186, 85, 72), (248, 188, 112)),
            "night": ((18, 26, 62), (58, 72, 128)),
        }
        c_top, c_bot = palettes.get(time_of_day, palettes["day"])
        for y in range(720):
            r = int(c_top[0] + (c_bot[0] - c_top[0]) * (y / 720))
            g = int(c_top[1] + (c_bot[1] - c_top[1]) * (y / 720))
            b = int(c_top[2] + (c_bot[2] - c_top[2]) * (y / 720))
            draw.line([(0, y), (1280, y)], fill=(r, g, b))
        buf = io.BytesIO()
        im.save(buf, "WEBP", quality=82)
        webp_bytes = buf.getvalue()

    meta = {
        "bg_id": bg_id,
        "name": scene_title or "AI生成背景",
        "keyword": scene_title or "AI生成背景",
        "time_of_day": time_of_day or "any",
        "is_generated": 1,
    }
    return meta, base64.b64encode(webp_bytes).decode("ascii")
