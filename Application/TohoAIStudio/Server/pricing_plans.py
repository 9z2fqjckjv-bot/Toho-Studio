#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TohoAIStudio V3.0 - 一般配布・外部公開向け 新定額プラン料金体系 & 東方Project コンテキストRAG定義
"""

from typing import Dict, Any, List, Optional

# ==============================================================================
# 1. 新・定額プラン料金体系 (利益完全排除・実費回収のみ・赤字防止最低金額モデル)
# ------------------------------------------------------------------------------
# 【原価算出根拠 (1プロンプト平均 1,500〜2,500 tokens / 為替 1USD=160JPY 安全レート想定)】
# - 標準推論層 (Gemini 2.5 Flash-Lite / DeepSeek-V3 / Qwen3-14B + Local Ollama併用):
#     API実費 約¥0.09〜¥0.13/回 + MacMini電力・通信按分 約¥0.02/回 = 最大実費 ¥0.15/回
# - 高位・思考推論層 (Gemini 2.5 Flash / DeepSeek-R1 <think>トークン込み):
#     API実費 約¥0.17〜¥0.18/回 + 電力・為替変動バッファ 約¥0.02/回 = 最大実費 ¥0.20/回
# - 追加パック (バースト制限免除・全量長文ピーク利用時の最大実費): ¥0.25/回 (10円単位切上げ)
# ※運営利益マージン 0%。月間最大枠（基本枠＋広告ボーナス枠）を100%使い切っても赤字にならない最低金額。
# ==============================================================================
FLAT_RATE_PLANS: Dict[str, Dict[str, Any]] = {
    "free": {
        "plan_id": "free",
        "name": "無料プラン (Starter)",
        "price_jpy": 0,
        "base_monthly_prompts": 30,
        "ad_bonus_monthly_cap": 270,
        "max_monthly_total": 300,
        "limit_5hour": 15,
        "limit_weekly": 80,
        "rollover_days": 180,  # 無料枠・広告枠は半年間(180日)繰越
        "model_tier": "economy",
        "requires_trial_ad": True,
        "trial_ad_seconds_per_prompt": 15,
        "description": "毎月基本30回＋お試し広告視聴で最大月300回まで無料（ローカル推論＆広告枠で実費カバー）",
    },
    "lite_150": {
        "plan_id": "lite_150",
        "name": "ライトプラン (実費枠)",
        "price_jpy": 150,
        "base_monthly_prompts": 800,
        "ad_bonus_monthly_cap": 200,
        "max_monthly_total": 1000,
        "limit_5hour": 60,
        "limit_weekly": 300,
        "rollover_days": 365,  # 有料プランは1年間(365日)繰越
        "model_tier": "standard",
        "requires_trial_ad": False,
        "trial_ad_seconds_per_prompt": 10,
        "description": "利益0円の実費回収プラン（基本800回＋広告200回＝最大1,000回 / 1回あたり実費¥0.15換算）",
    },
    "standard_380": {
        "plan_id": "standard_380",
        "name": "スタンダードプラン (実費枠)",
        "price_jpy": 380,
        "base_monthly_prompts": 2000,
        "ad_bonus_monthly_cap": 500,
        "max_monthly_total": 2500,
        "limit_5hour": 150,
        "limit_weekly": 750,
        "rollover_days": 365,
        "model_tier": "standard",
        "requires_trial_ad": False,
        "trial_ad_seconds_per_prompt": 10,
        "description": "【推奨】週1〜2本の動画・台本制作向け実費プラン（基本2,000回＋広告500回＝最大2,500回 / ¥0.15/回）",
    },
    "creator_900": {
        "plan_id": "creator_900",
        "name": "クリエイタープラン (実費枠)",
        "price_jpy": 900,
        "base_monthly_prompts": 3500,
        "ad_bonus_monthly_cap": 1000,
        "max_monthly_total": 4500,
        "limit_5hour": 250,
        "limit_weekly": 1300,
        "rollover_days": 365,
        "model_tier": "high",
        "requires_trial_ad": False,
        "trial_ad_seconds_per_prompt": 10,
        "description": "長編構成・思考モデル併用向け実費プラン（基本3,500回＋広告1,000回＝最大4,500回 / ¥0.20/回）",
    },
    "pro_1600": {
        "plan_id": "pro_1600",
        "name": "プロスタジオプラン (実費枠)",
        "price_jpy": 1600,
        "base_monthly_prompts": 6500,
        "ad_bonus_monthly_cap": 1500,
        "max_monthly_total": 8000,
        "limit_5hour": 450,
        "limit_weekly": 2400,
        "rollover_days": 365,
        "model_tier": "high",
        "requires_trial_ad": False,
        "trial_ad_seconds_per_prompt": 10,
        "description": "高頻度投稿・複数作品並行向け実費プラン（基本6,500回＋広告1,500回＝最大8,000回 / ¥0.20/回）",
    },
    "ultra_3600": {
        "plan_id": "ultra_3600",
        "name": "アルティメットプラン (実費枠)",
        "price_jpy": 3600,
        "base_monthly_prompts": 15000,
        "ad_bonus_monthly_cap": 3000,
        "max_monthly_total": 18000,
        "limit_5hour": 1000,
        "limit_weekly": 5500,
        "rollover_days": 365,
        "model_tier": "ultra",
        "requires_trial_ad": False,
        "trial_ad_seconds_per_prompt": 5,
        "description": "サークル共同・大規模制作向け最上位実費プラン（基本15,000回＋広告3,000回＝最大18,000回 / ¥0.20/回）",
    },
}

# 旧プラン名からの互換マッピング
LEGACY_PLAN_MAPPING: Dict[str, str] = {
    "0": "free",
    "free": "free",
    "1000": "lite_150",
    "lite_980": "lite_150",
    "2000": "standard_380",
    "standard_1980": "standard_380",
    "3000": "creator_900",
    "creator_2980": "creator_900",
    "5000": "pro_1600",
    "pro_4980": "pro_1600",
    "10000": "ultra_3600",
    "ultra_9800": "ultra_3600",
}

# 追加プロンプトパック (利益完全排除・バースト免除ピーク時最大原価 ¥0.25/回 の実費回収最低額)
ADDON_PROMPT_PACKS: Dict[str, Dict[str, Any]] = {
    "pack_10": {
        "pack_id": "pack_10",
        "name": "追加 10 プロンプト (実費)",
        "prompts": 10,
        "price_jpy": 10,
        "unit_price_jpy": 1.0,
    },
    "pack_100": {
        "pack_id": "pack_100",
        "name": "追加 100 プロンプト (実費)",
        "prompts": 100,
        "price_jpy": 30,
        "unit_price_jpy": 0.3,
    },
    "pack_500": {
        "pack_id": "pack_500",
        "name": "追加 500 プロンプト (実費)",
        "prompts": 500,
        "price_jpy": 130,
        "unit_price_jpy": 0.26,
    },
    "pack_1000": {
        "pack_id": "pack_1000",
        "name": "追加 1,000 プロンプト (実費)",
        "prompts": 1000,
        "price_jpy": 250,
        "unit_price_jpy": 0.25,
    },
}

AD_REWARD_PROMPTS_PER_VIEW = 5


# ==============================================================================
# 2. 東方Project キャラクター設定 & 二次創作ガイドライン RAG 辞書
# ==============================================================================
TOUHOU_GUIDELINE_CORE = (
    "あなたは『Toho-Studio / TohoAIStudio』に搭載された東方Project二次創作専門AIアシスタントです。"
    "上海アリス幻樂団の「東方Projectの二次創作ガイドライン」を遵守し、原作の世界観（幻想郷、博麗大結界、スペルカードルール）"
    "および各キャラクターの一人称・二人称・語尾・人間関係を厳密に保って自然な日本語で応答してください。"
)

TOUHOU_CHARACTER_PROFILES: Dict[str, str] = {
    "霊夢": "【博麗霊夢】博麗神社の巫女。一人称「私」、語尾「〜わ」「〜よ」「〜かしら」「〜なさい」。裏表がなくマイペースで現実的だが異変解決時は鋭い。魔理沙は親友。",
    "魔理沙": "【霧雨魔理沙】魔法の森に住む普通の魔法使い。一人称「私」、語尾「〜だぜ」「〜だな」「〜のか？」「〜だぞ」。努力家で明るく豪快。ミニ八卦炉とマスタースパークが代名詞。",
    "咲夜": "【十六夜咲夜】紅魔館のメイド長。一人称「私」、丁寧で瀟洒な敬語（「〜ですわ」「〜ますの」「〜かしら」）。レミリア（「お嬢様」）に絶対の忠誠を誓い、時間を操る程度の能力を持つ。",
    "妖夢": "【魂魄妖夢】白玉楼の半人半霊の庭師兼剣術指南役。一人称「私」、真面目で礼儀正しい口調（「〜です」「〜ます」「〜ですよ！」）。幽々子様には頭が上がらず少し天然。",
    "レミリア": "【レミリア・スカーレット】紅魔館の主で500歳超の吸血鬼。一人称「私」、カリスマと幼さが同居した尊大な口調（「〜よ」「〜わ」「〜かしら」「咲夜」と呼び捨て）。運命を操る程度の能力。",
    "フラン": "【フランドール・スカーレット】レミリアの妹。一人称「あたい」または「私」、無邪気さと危うさのある少女口調（「〜だよ」「〜なの？」「きゅっとしてドカーン」）。ありとあらゆるものを破壊する程度の能力。",
    "チルノ": "【チルノ】霧の湖の氷の妖精。一人称「あたい」、元気で自信過剰な子供っぽい口調（「あたいったら最強ね！」「〜だもん！」「〜わよ！」）。冷気を操る程度の能力。",
    "早苗": "【東風谷早苗】守矢神社の風祝（外の世界出身の現人神）。一人称「私」、明るく丁寧な口調（「〜です！」「〜ますね」「常識に囚われてはいけないのですね！」）。奇跡を起こす程度の能力。",
    "文": "【射命丸文】鴉天狗の『文々。新聞』記者。一人称「私」、慇懃で取材熱心な敬語（「あやややや」「〜ですね」「〜ですよ」）。風を操る程度の能力。",
    "鈴仙": "【鈴仙・優曇華院・イナバ】永遠亭の月の兎。一人称「私」、真面目で苦労人気質の丁寧語（「〜です」「〜ます」）。狂気を操る程度の能力。",
    "アリス": "【アリス・マーガトロイド】魔法の森の人形遣い。一人称「私」、知的で少しツンとした都会的な女性口調（「〜わ」「〜かしら」「〜じゃない」）。魔理沙とは腐れ縁。",
    "パチュリー": "【パチュリー・ノーレッジ】紅魔館大図書館の魔法使い。一人称「私」、物静かで淡々とした口調（「〜わ」「〜ね」「むきゅー」）。レミリアの親友で喘息持ち。",
    "幽々子": "【西行寺幽々子】冥界・白玉楼の亡霊の姫。一人称「私」、おっとりマイペースで掴み所のない優雅な口調（「〜わ〜」「〜かしら」「妖夢、お茶〜」）。死を操る程度の能力。",
    "紫": "【八雲紫】境界を操る大妖怪・幻想郷の賢者。一人称「私（わたくし）」、妖艶で底知れない丁寧混じりの女言葉（「〜わ」「〜かしら」「〜ですわ」）。",
    "さとり": "【古明地さとり】地霊殿の主。一人称「私」、落ち着いて丁寧だが少し皮肉も混じる口調（「〜わ」「〜ですよ」）。心を読む程度の能力。",
    "こいし": "【古明地こいし】さとりの妹。一人称「私」、無意識で自由奔放・天真爛漫な口調（「〜だよ！」「〜ね！」）。無意識を操る程度の能力。",
}


def build_rag_system_prompt(base_system_prompt: Optional[str], user_text: str, persona: Optional[str] = None) -> str:
    """入力文やペルソナに含まれる東方キャラクター設定だけを動的に注入してコンテキスト精度を高める"""
    parts: List[str] = [TOUHOU_GUIDELINE_CORE]
    if base_system_prompt and base_system_prompt.strip():
        parts.append(base_system_prompt.strip())
    if persona and persona != "東方Project総合アシスタント":
        parts.append(f"現在の対話ペルソナ指定: {persona} として振る舞い、その口調・視点で応答してください。")

    combined_search = f"{user_text} {persona or ''} {base_system_prompt or ''}"
    matched_profiles = [
        profile for keyword, profile in TOUHOU_CHARACTER_PROFILES.items()
        if keyword in combined_search
    ]
    if matched_profiles:
        parts.append("【参照キャラクター公式口調・設定シート】\n" + "\n".join(matched_profiles))
    return "\n\n".join(parts)


def build_ai_edit_prompts(edit_mode: str, input_text: str, tone_description: str) -> Dict[str, str]:
    """TohoAIStudio の AIEditorProgram 5モード用の高精度プロンプトを構築"""
    if edit_mode == "proofreadPolish":
        sys_p = (
            f"{TOUHOU_GUIDELINE_CORE}\n"
            "あなたは東方ゆっくり動画・ノベル制作のプロ編集者です。"
            "入力された台本を、テンポ・誤字脱字・AquesTalk（ゆっくりボイス）での自然な読み上げ区切り（読点）の観点で推敲・ブラッシュアップしてください。"
            f"基準となるキャラクター口調設定: {tone_description}\n"
            "余計な前置きは省き、推敲後の台本本文のみを出力してください。"
        )
    elif edit_mode == "scenarioRewrite":
        sys_p = (
            f"{TOUHOU_GUIDELINE_CORE}\n"
            f"入力された文章やセリフを、指定キャラクター『{tone_description}』の生き生きとした口調・一人称・語尾・世界観表現へ完全に書き換えてください。"
            "各行は「キャラ名「セリフ」」の形式で出力し、余計な解説は含めないでください。"
        )
    elif edit_mode == "sceneStoryboard":
        sys_p = (
            f"{TOUHOU_GUIDELINE_CORE}\n"
            "入力されたプロットから、Toho-Studioのムービーメーカーにそのままタイムライン配置できる絵コンテ（3〜6シーン構成）をJSON形式で生成してください。\n"
            "必ず以下のJSON形式のみを出力してください（Markdownコードブロック不要）:\n"
            '{"scenes":[{"title":"シーン1: タイトル","duration":8.0,"slideTitle":"第1スライド",'
            '"backgroundName":"博麗神社境内","characterName":"博麗霊夢","telop":"霊夢「セリフ」","audioTrack":"bgm_maiden_capriccio.mp3"}]}'
        )
    elif edit_mode == "characterPrompt":
        sys_p = (
            f"{TOUHOU_GUIDELINE_CORE}\n"
            f"対象キャラクター『{tone_description}』について、ユーザーの要望に応じたPSDTool / キャラクターメーカー用の立ち絵レイヤー構成（眉・目・口・腕・小物・色調）"
            "およびAI画像生成用英語タグプロンプトの両方を分かりやすく整理して出力してください。"
        )
    elif edit_mode == "gameBlocklyScript":
        sys_p = (
            f"{TOUHOU_GUIDELINE_CORE}\n"
            "ユーザーの要望に基づき、Toho-Studio ゲームメーカー（横長ワイド東方RPG / ノベルエンジン）で利用可能なイベントスクリプト（JavaScript互換DSLおよびシナリオ分岐コマンド）を出力してください。"
        )
    else:
        sys_p = TOUHOU_GUIDELINE_CORE

    return {
        "system_prompt": sys_p,
        "user_prompt": input_text,
    }
