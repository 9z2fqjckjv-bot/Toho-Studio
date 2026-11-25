#!/usr/bin/env python3
"""
キャラセリフメーカー連携 オンメモリ音声合成サービス (voice_service.py)
設計方針:
  1. 『キャラセリフメーカー』(~/Documents/キャラセリフメーカー) のプログラム
     (aquestalk_engine.py / serif_maker_server API) を直接呼び出し、登録済みライセンスキー
     （使用ライセンス・開発ライセンス）およびキャラクター別プリセットを用いて音声合成を実行
  2. HDDへの音声ファイル書き出しゼロ（save_to_export=False による完全オンメモリ合成）
  3. 44.1kHz PCM16 WAV へ整形し、すべてのブラウザの <audio> 要素で確実に再生可能なデータを返却
"""

import io
import os
import re
import sys
import json
import math
import wave
import array
import base64
import shutil
import tempfile
import subprocess
import unicodedata
import urllib.request
from typing import Any, Dict, List, Optional, Tuple

from db import DOC_ROOT

SERIF_MAKER_DIR = os.environ.get(
    "CHARA_SERIF_MAKER_DIR",
    os.path.join(DOC_ROOT, "キャラセリフメーカー"),
)
SERIF_MAKER_URL = os.environ.get("CHARA_SERIF_MAKER_URL", "http://127.0.0.1:8090")
DEFAULT_LINUX_LIBS = os.path.join(SERIF_MAKER_DIR, "libs", "linux")
LINUX_LIBS_DIR = os.environ.get("AQUESTALK_LINUX_LIBS_DIR", DEFAULT_LINUX_LIBS)

if os.path.isdir(SERIF_MAKER_DIR) and SERIF_MAKER_DIR not in sys.path:
    sys.path.insert(0, SERIF_MAKER_DIR)

# AquesTalk 音声記号列で許容されるひらがな・記号セット
_VALID_KOE_CHARS = set(
    "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん"
    "がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽゔ"
    "ぁぃぅぇぉゃゅょゎっー"
    "'/+;、。？,._ "
)


def _import_serif_maker_engine():
    """キャラセリフメーカーの aquestalk_engine モジュールをロード"""
    if os.path.isdir(SERIF_MAKER_DIR) and SERIF_MAKER_DIR not in sys.path:
        sys.path.insert(0, SERIF_MAKER_DIR)
    import aquestalk_engine as csm_engine  # type: ignore
    return csm_engine


def katakana_to_hiragana(text: str) -> str:
    """カタカナをひらがなへ変換（AquesTalk音声記号列仕様準拠）"""
    s = unicodedata.normalize("NFKC", text or "")
    out = []
    for ch in s:
        code = ord(ch)
        if 0x30A1 <= code <= 0x30F6:
            out.append(chr(code - 0x60))
        else:
            out.append(ch)
    return "".join(out)


def sanitize_aquestalk1_koe(koe_raw: str, fallback_kana: str = "") -> str:
    """
    Geminiが生成した音声記号列をAquesTalk1が確実に受理できる形式へ正規化する。
    キャラセリフメーカー側の実機検証済みサニタイザ (漢字かな変換・長音位置補正・外来音補正込み) を優先利用する。
    """
    src = (koe_raw or "").strip()
    if src.startswith("#>"):
        src = src[2:].strip()

    try:
        csm = _import_serif_maker_engine()
        if hasattr(csm, "sanitize_aquestalk1_koe"):
            cand = csm.sanitize_aquestalk1_koe(src, boyomi=False) if src else "あー"
            if cand and cand != "あー":
                return cand
            if fallback_kana:
                fb = csm._fallback_kana_koe_without_k2k(fallback_kana, boyomi=False)
                if fb:
                    return fb
            return cand or "あー"
    except Exception:
        pass

    hira = katakana_to_hiragana(src)
    for old, new in (
        ("ゔぁ", "ば"), ("ゔぃ", "び"), ("ゔゅ", "びゅ"), ("ゔぇ", "べ"), ("ゔぉ", "ぼ"), ("ゔ", "ぶ"),
        ("ぢゃ", "じゃ"), ("ぢゅ", "じゅ"), ("ぢょ", "じょ"), ("ぢ", "じ"),
        ("づ", "ず"), ("を", "お"), ("〜", "ー"), ("～", "ー"),
        ("!", "。"), ("！", "。"), ("?", "？"), ("…", "、"), ("・", "、"), (" ", "、"), ("　", "、"),
    ):
        hira = hira.replace(old, new)
    allowed = set(
        "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん"
        "がぎぐげござじずぜぞだでどばびぶべぼぱぴぷぺぽ"
        "ぁぃぅぇぉゃゅょゎっー'/+;、。？"
    )
    cleaned = "".join(ch for ch in hira if ch in allowed)
    cleaned = re.sub(r"'([ーゃゅょぁぃぅぇぉゎ])", r"\1'", cleaned)
    cleaned = re.sub(r"ー+", "ー", cleaned)
    cleaned = re.sub(r"'+", "'", cleaned)
    cleaned = re.sub(r"/+", "/", cleaned)
    cleaned = re.sub(r"[、。]+", "、", cleaned)
    cleaned = cleaned.strip("/'")
    if not any("あ" <= c <= "ん" for c in cleaned):
        fb = katakana_to_hiragana(fallback_kana)
        fb = fb.replace("ぢ", "じ").replace("づ", "ず").replace("を", "お")
        cleaned = "".join(ch for ch in fb if "あ" <= ch <= "ん" or ch in "ー、。？")
    return cleaned or "あー"


def resolve_serif_maker_preset_for_char(
    char_id: str = "",
    speaker_name: str = "",
    default_voice: str = "f1",
    default_spd: int = 100,
    default_fsc: int = 100,
    default_vol: int = 100,
) -> Dict[str, Any]:
    """
    キャラセリフメーカー側のマイカスタム設定 (data/custom_presets.json) および
    標準プリセットカタログ (presets_catalog.py) から対象キャラクターのボイス設定を取得する。
    """
    preset: Dict[str, Any] = {
        "engine": "AquesTalk1",
        "voice": default_voice or "f1",
        "spd": int(default_spd or 100),
        "fsc": int(default_fsc or 100),
        "vol": int(default_vol or 100),
        "pit": 100,
        "acc": 100,
        "lmd": 100,
        "boyomi": False,
    }
    try:
        custom_file = os.path.join(SERIF_MAKER_DIR, "data", "custom_presets.json")
        if os.path.isfile(custom_file):
            with open(custom_file, "r", encoding="utf-8") as cf:
                custom_list: List[Dict[str, Any]] = json.load(cf)
            if isinstance(custom_list, list):
                for cp in custom_list:
                    if (char_id and cp.get("char_id") == char_id) or (speaker_name and cp.get("char_name") == speaker_name):
                        # Linux版で該当エンジンのライブラリが利用可能な場合のみ非AquesTalk1エンジンも採用
                        eng = str(cp.get("engine", "AquesTalk1"))
                        if eng == "AquesTalk1" or _is_engine_available_in_serif_maker(eng):
                            preset.update({
                                "engine": eng,
                                "voice": str(cp.get("voice", preset["voice"])),
                                "spd": int(cp.get("spd", preset["spd"])),
                                "fsc": int(cp.get("fsc", preset["fsc"])),
                                "vol": int(cp.get("vol", preset["vol"])),
                                "pit": int(cp.get("pit", 100)),
                                "acc": int(cp.get("acc", 100)),
                                "lmd": int(cp.get("lmd", 100)),
                                "boyomi": bool(cp.get("boyomi", False)),
                            })
                            return preset

        from presets_catalog import CHARACTER_PRESETS  # type: ignore
        for ch in CHARACTER_PRESETS:
            if (char_id and ch.get("char_id") == char_id) or (speaker_name and ch.get("name") == speaker_name):
                variants = ch.get("variants", [])
                aq1_vars = [v for v in variants if v.get("engine") == "AquesTalk1"]
                chosen = aq1_vars[0] if aq1_vars else (variants[0] if variants else None)
                if chosen:
                    eng = str(chosen.get("engine", "AquesTalk1"))
                    if eng != "AquesTalk1" and not _is_engine_available_in_serif_maker(eng):
                        eng = "AquesTalk1"
                    preset.update({
                        "engine": eng,
                        "voice": str(chosen.get("voice", preset["voice"])) if eng == chosen.get("engine") else preset["voice"],
                        "spd": int(chosen.get("spd", preset["spd"])),
                        "fsc": int(chosen.get("fsc", preset["fsc"])),
                        "vol": int(chosen.get("vol", preset["vol"])),
                        "pit": int(chosen.get("pit", 100)),
                        "acc": int(chosen.get("acc", 100)),
                        "lmd": int(chosen.get("lmd", 100)),
                        "boyomi": bool(chosen.get("boyomi", False)),
                    })
                break
    except Exception:
        pass
    return preset


def _is_engine_available_in_serif_maker(engine_name: str) -> bool:
    try:
        csm = _import_serif_maker_engine()
        disc = csm.discover_linux_so_files()
        if engine_name == "AquesTalk1":
            return bool(disc.get("aqtk1_any"))
        if engine_name == "AquesTalk2":
            return bool(disc.get("aqtk2"))
        if engine_name == "AquesTalk10":
            return bool(disc.get("aqtk10"))
    except Exception:
        pass
    return False


def is_serif_maker_licensed() -> bool:
    """キャラセリフメーカーに使用ライセンスまたは開発ライセンスが登録済みか確認"""
    try:
        csm = _import_serif_maker_engine()
        lic = csm.get_public_license_status(verify_libs=False)
        return bool(lic.get("usage_configured") or lic.get("dev_configured"))
    except Exception:
        return bool(os.environ.get("AQUESTALK_DEV_KEY", "").strip() or os.environ.get("AQUESTALK_USR_KEY", "").strip())


def get_voice_engine_status() -> Dict[str, Any]:
    """キャラセリフメーカー側のエンジン状態・ライセンス登録状態を含めて返却"""
    try:
        csm = _import_serif_maker_engine()
        st = csm.get_engine_status()
        lic = csm.get_public_license_status(verify_libs=False)
        if st.get("ready"):
            return {
                "ready": True,
                "mode": f"chara_serif_maker:{st.get('mode')}",
                "label": f"キャラセリフメーカー連携 ({st.get('label')})",
                "serif_maker_dir": SERIF_MAKER_DIR,
                "libs_dir": LINUX_LIBS_DIR,
                "so_files": st.get("so_files", []),
                "licenses": {
                    "usage_configured": lic.get("usage_configured", False),
                    "dev_configured": lic.get("dev_configured", False),
                },
            }
    except Exception:
        pass

    if shutil.which("open_jtalk"):
        return {
            "ready": True,
            "mode": "open_jtalk_ram_fallback",
            "label": "フォールバック音声 (Open JTalk /dev/shm)",
        }

    return {
        "ready": True,
        "mode": "synth_placeholder",
        "label": "プレースホルダ波形 (キャラセリフメーカー libs/linux に .so 未配置)",
        "serif_maker_dir": SERIF_MAKER_DIR,
        "libs_dir": LINUX_LIBS_DIR,
    }


def _call_serif_maker_http_api(req_params: Dict[str, Any]) -> Optional[Tuple[bytes, str]]:
    """キャラセリフメーカー HTTP API (localhost:8090/api/synthesize) 経由でのオンメモリ合成フォールバック"""
    try:
        payload_dict = dict(req_params)
        payload_dict["save_to_export"] = False
        payload_dict["format"] = "wav"
        payload = json.dumps(payload_dict, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(
            f"{SERIF_MAKER_URL.rstrip('/')}/api/synthesize",
            data=payload,
            headers={"Content-Type": "application/json; charset=utf-8"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10.0) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode("utf-8"))
                if data.get("ok") and data.get("audio_base64"):
                    wav_bytes = base64.b64decode(data["audio_base64"])
                    if len(wav_bytes) > 44:
                        return wav_bytes, f"chara_serif_maker_http:{data.get('used_mode', 'api')}"
    except Exception:
        pass
    return None


def _synthesize_open_jtalk_ram(plain_text: str, spd: int = 100, fsc: int = 100) -> Optional[bytes]:
    ojt = shutil.which("open_jtalk")
    if not ojt:
        return None
    dic = next((d for d in ("/var/lib/mecab/dic/open-jtalk/naist-jdic", "/usr/share/open-jtalk/dic") if os.path.exists(d)), None)
    htsv = next((v for v in (
        "/usr/share/hts-voice/mei/mei_normal.htsvoice",
        "/usr/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice",
    ) if os.path.exists(v)), None)
    if not dic or not htsv:
        return None

    ram_base = "/dev/shm" if os.path.isdir("/dev/shm") else tempfile.gettempdir()
    with tempfile.TemporaryDirectory(prefix="renai_tts_", dir=ram_base) as tmpd:
        in_p = os.path.join(tmpd, "in.txt")
        out_p = os.path.join(tmpd, "out.wav")
        with open(in_p, "w", encoding="utf-8") as f:
            f.write(plain_text)
        spd_r = max(0.6, min(2.2, spd / 100.0))
        fm = 12.0 * math.log2(max(0.6, min(1.8, fsc / 100.0)))
        subprocess.run(
            [ojt, "-x", dic, "-m", htsv, "-r", f"{spd_r:.2f}", "-fm", f"{fm:.2f}", "-ow", out_p, in_p],
            check=True, capture_output=True, timeout=10,
        )
        with open(out_p, "rb") as wf:
            return wf.read()


def _generate_soft_voice_blip_in_memory(koe_str: str, fsc: int = 100) -> bytes:
    """libAquesTalk*.so 未配置時でも再生確認ができる 44.1kHz 純メモリ生成トーン"""
    sr = 44100
    dur_per_mora = 0.065
    samples = array.array("h")
    base_freq = 440.0 * (fsc / 100.0)
    for ch in koe_str[:45]:
        if ch in "、。？/":
            samples.extend([0] * int(sr * 0.08))
            continue
        if not ("あ" <= ch <= "ん"):
            continue
        freq = base_freq * (1.0 + ((ord(ch) % 7) - 3) * 0.04)
        n = int(sr * dur_per_mora)
        for i in range(n):
            env = math.sin(math.pi * i / n)
            val = int(4200 * env * math.sin(2.0 * math.pi * freq * (i / sr)))
            samples.append(val)
    if len(samples) == 0:
        samples.extend([0] * int(sr * 0.25))
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(samples.tobytes())
    return buf.getvalue()


def synthesize_via_chara_serif_maker(
    koe_text: str,
    plain_text: str = "",
    char_id: str = "",
    speaker_name: str = "",
    voice: str = "f1",
    spd: int = 100,
    fsc: int = 100,
    vol: int = 100,
    spd_delta: int = 0,
    fsc_delta: int = 0,
    effect: str = "none",
) -> Tuple[bytes, str, str]:
    """
    『キャラセリフメーカー』の音声合成エンジン (aquestalk_engine.synthesize_speech / REST API) を呼び出し、
    登録済みの使用ライセンス＆開発ライセンスを適用してオンメモリで WAV バイナリを生成する。
    戻り値: (wav_bytes, sanitized_koe, engine_mode)
    """
    sanitized_koe = sanitize_aquestalk1_koe(koe_text, fallback_kana=plain_text)

    preset = resolve_serif_maker_preset_for_char(
        char_id=char_id,
        speaker_name=speaker_name,
        default_voice=voice,
        default_spd=spd,
        default_fsc=fsc,
        default_vol=vol,
    )

    final_spd = max(50, min(260, int(preset["spd"]) + max(-25, min(25, int(spd_delta or 0)))))
    final_fsc = max(55, min(195, int(preset["fsc"]) + max(-15, min(15, int(fsc_delta or 0)))))
    final_vol = max(20, min(250, int(preset["vol"])))
    safe_effect = effect if effect in ("none", "echo_light", "echo_deep", "cave", "radio") else "none"

    serif_params: Dict[str, Any] = {
        "text": sanitized_koe,
        "is_koe": True,
        "speaker_name": speaker_name or "ゆっくり",
        "engine": preset["engine"],
        "voice": preset["voice"],
        "spd": final_spd,
        "fsc": final_fsc,
        "vol": final_vol,
        "pit": preset["pit"],
        "acc": preset["acc"],
        "lmd": preset["lmd"],
        "boyomi": preset["boyomi"],
        "resample_mode": "cubic",
        "target_sr": 44100,
        "pause_top_ms": 20,
        "pause_end_ms": 120,
        "effect": safe_effect,
        "save_to_export": False,
    }

    call_mode = os.environ.get("CHARA_SERIF_MAKER_CALL_MODE", "direct").lower()

    # 1. キャラセリフメーカー aquestalk_engine.py の直接オンメモリ呼び出し（最速・ライセンス自動反映）
    if call_mode != "http":
        try:
            csm = _import_serif_maker_engine()
            wav_bytes, used_mode = csm.synthesize_speech(serif_params)
            if wav_bytes and len(wav_bytes) > 44:
                return wav_bytes, sanitized_koe, f"chara_serif_maker:{used_mode}"
        except Exception as exc:
            print(f"[voice_service] direct CharaSerifMaker call warning: {exc}", file=sys.stderr)

    # 2. キャラセリフメーカー ローカルサーバー HTTP API (http://127.0.0.1:8090/api/synthesize) 呼び出し
    http_res = _call_serif_maker_http_api(serif_params)
    if http_res is not None:
        return http_res[0], sanitized_koe, http_res[1]

    # 3. Open JTalk (/dev/shm RAM上のみ)
    try:
        ojt_wav = _synthesize_open_jtalk_ram(plain_text or sanitized_koe, spd=final_spd, fsc=final_fsc)
        if ojt_wav and len(ojt_wav) > 44:
            return ojt_wav, sanitized_koe, "open_jtalk_ram_fallback"
    except Exception:
        pass

    # 4. .so 未配置時の 44.1kHz プレースホルダトーン
    return _generate_soft_voice_blip_in_memory(sanitized_koe, fsc=final_fsc), sanitized_koe, "synth_placeholder"


def synthesize_aquestalk1_in_memory(
    koe_text: str,
    plain_text: str = "",
    voice: str = "f1",
    spd: int = 100,
    fsc: int = 100,
    vol: int = 100,
    char_id: str = "",
    speaker_name: str = "",
    spd_delta: int = 0,
    fsc_delta: int = 0,
    effect: str = "none",
) -> Tuple[bytes, str, str]:
    """既存呼び出し互換ラッパー: すべてキャラセリフメーカー連携エンジンへ委譲する"""
    return synthesize_via_chara_serif_maker(
        koe_text=koe_text,
        plain_text=plain_text,
        char_id=char_id,
        speaker_name=speaker_name,
        voice=voice,
        spd=spd,
        fsc=fsc,
        vol=vol,
        spd_delta=spd_delta,
        fsc_delta=fsc_delta,
        effect=effect,
    )
