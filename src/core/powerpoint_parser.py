"""
東方Projectムービーメーカー - PowerPoint (.pptx) 解析・変換モジュール
- PowerPoint (.pptx) ファイルからスライド画像・テキスト・ノートを抽出
- macOS Keynote 連携による .key 自動変換サポート
- 純粋 Python (zipfile / xml.etree) によるフォールバック抽出
- 話者自動判定およびシーン構造への変換
"""

import os
import sys
import zipfile
import xml.etree.ElementTree as ET
import subprocess
import shutil
import tempfile
from typing import List, Dict, Any, Optional

from .keynote_parser import guess_character, extract_speaker_prefix, check_all_objects_animation, get_video_assets_library, get_keynote_app_name
from .tts_engine import get_tts_engine


def convert_pptx_to_keynote_via_applescript(pptx_path: str, output_key_path: str) -> bool:
    """macOS Keynote を使用して .pptx を .key に変換"""
    if not os.path.exists(pptx_path):
        return False

    keynote_app = get_keynote_app_name()
    escaped_pptx = pptx_path.replace('\\', '\\\\').replace('"', '\\"')
    escaped_key = output_key_path.replace('\\', '\\\\').replace('"', '\\"')

    applescript = f'''
    tell application "{keynote_app}"
        set pPath to POSIX file "{escaped_pptx}"
        set doc to open file pPath
        set kPath to POSIX file "{escaped_key}"
        save doc in file kPath
        close doc saving no
        return "SUCCESS"
    end tell
    '''
    try:
        subprocess.run(["open", "-a", keynote_app], capture_output=True)
        import time
        time.sleep(1.5)
        proc = subprocess.run(["osascript", "-e", applescript], capture_output=True, text=True, timeout=60)
        return proc.returncode == 0 and os.path.exists(output_key_path)
    except Exception:
        return False


def extract_slides_from_pptx(pptx_path: str) -> List[Dict[str, Any]]:
    """
    PowerPoint (.pptx) からスライド情報を抽出
    1. Keynote が利用可能な場合は Keynote 経由で変換して extract_slides_from_keynote を呼出
    2. フォールバック: zipfile / XML 解析
    """
    if not os.path.exists(pptx_path) or os.path.getsize(pptx_path) == 0:
        return []

    # 1. Keynote 変換の試行
    temp_dir = tempfile.mkdtemp(prefix="toho_pptx_")
    key_path = os.path.join(temp_dir, os.path.splitext(os.path.basename(pptx_path))[0] + ".key")

    try:
        if convert_pptx_to_keynote_via_applescript(pptx_path, key_path):
            from .keynote_parser import extract_slides_from_keynote
            slides = extract_slides_from_keynote(key_path)
            if slides:
                return slides
    except Exception as e:
        print(f"[INFO] Keynote conversion skipped, falling back to direct XML parse: {e}")
    finally:
        if os.path.exists(temp_dir):
            try: shutil.rmtree(temp_dir)
            except Exception: pass

    # 2. 直接 XML 解析 (ZIP)
    return parse_pptx_directly(pptx_path)


def parse_pptx_directly(pptx_path: str) -> List[Dict[str, Any]]:
    """PowerPoint の ZIP 構造からスライドテキスト・ノート・オブジェクトを抽出"""
    slides = []
    tts = get_tts_engine()
    assets_lib = get_video_assets_library()
    assets_lib.scan_library()

    prev_slide_info = None

    try:
        with zipfile.ZipFile(pptx_path, 'r') as z:
            slide_files = [f for f in z.namelist() if f.startswith("ppt/slides/slide") and f.endswith(".xml")]
            # 番号順にソート
            def get_slide_num(name):
                base = os.path.splitext(os.path.basename(name))[0]
                num_str = "".join([c for c in base if c.isdigit()])
                return int(num_str) if num_str else 999

            slide_files.sort(key=get_slide_num)

            ns = {
                'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
                'p': 'http://schemas.openxmlformats.org/presentationml/2006/main',
                'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
            }

            for idx, sfile in enumerate(slide_files, start=1):
                xml_data = z.read(sfile)
                root = ET.fromstring(xml_data)

                # テキスト抽出
                text_list = []
                for p in root.findall('.//a:p', ns):
                    para_texts = []
                    for t in p.findall('.//a:t', ns):
                        if t.text:
                            para_texts.append(t.text)
                    line = "".join(para_texts).strip()
                    if line:
                        text_list.append(line)

                combined_text = "\n".join(text_list)

                # 発表者ノートの探索
                notes_text = ""
                note_file = f"ppt/notesSlides/notesSlide{idx}.xml"
                if note_file in z.namelist():
                    try:
                        n_root = ET.fromstring(z.read(note_file))
                        n_texts = []
                        for p in n_root.findall('.//a:p', ns):
                            for t in p.findall('.//a:t', ns):
                                if t.text:
                                    n_texts.append(t.text)
                        notes_text = "\n".join(n_texts).strip()
                    except Exception:
                        pass

                raw_script_text = notes_text if notes_text.strip() else combined_text

                # レイアウト・テンプレートの簡易判定
                layout_name = "標準"
                is_sec = False
                try:
                    rel_file = f"ppt/slides/_rels/slide{idx}.xml.rels"
                    if rel_file in z.namelist():
                        r_root = ET.fromstring(z.read(rel_file))
                        for r_elem in r_root.findall('.//{http://schemas.openxmlformats.org/package/2006/relationships}Relationship'):
                            target = r_elem.get("Target", "")
                            if "slideLayout" in target:
                                layout_name = os.path.splitext(os.path.basename(target))[0]
                                break
                except Exception:
                    pass

                is_sec = any(k in layout_name.lower() or k in combined_text for k in ["section", "header", "title", "見出し", "タイトル", "セクション"])
                tmpl_info = {
                    "layout_name": layout_name,
                    "is_section_header": is_sec,
                    "section_title": (combined_text.split("\n")[0] if combined_text else "") if is_sec else ""
                }

                # 全オブジェクト（背景、キャラクター、テロップ枠、テキスト、発表者ノート）の包括的アニメーションチェック & 時間優先適用
                anim_check = check_all_objects_animation(
                    slide_index=idx,
                    raw_script_text=raw_script_text,
                    notes=notes_text,
                    text_content=combined_text,
                    images_str="",
                    trans_effect="",
                    trans_delay=0.0,
                    trans_duration=0.0,
                    found_telop=False,
                    prev_slide_info=prev_slide_info,
                    assets_lib=assets_lib,
                    template_name=layout_name,
                    template_info=tmpl_info
                )

                # 話者プレフィックスと本文クレンジング
                prefix_char, clean_text = extract_speaker_prefix(combined_text)
                final_text = clean_text if clean_text else combined_text

                # キャラクター推定
                char_name, voice_type, speed, pitch = guess_character(
                    text=combined_text,
                    notes=notes_text,
                    slide_idx=idx
                )

                # 音声記号列生成
                koe = tts.kanji2koe(final_text) if final_text else ""

                slides.append({
                    "slide_index": idx,
                    "text": final_text,
                    "notes": notes_text,
                    "character": char_name,
                    "voice": voice_type,
                    "speed": speed,
                    "pitch": pitch,
                    "phonemes": koe,
                    "extra_delay": anim_check["final_extra_delay"],
                    "transition_delay": 0.0,
                    "transition_duration": 0.0,
                    "transition_effect": "no transition effect",
                    "template_name": anim_check["template_name"],
                    "template_info": anim_check["template_info"],
                    "slide_objects": anim_check["slide_objects"],
                    "duration_priority_info": anim_check["duration_priority_info"],
                    "target_duration": anim_check["final_target_duration"],
                    "is_animation_sync": anim_check["is_animation_sync"],
                    "has_animation": anim_check["has_animation"],
                    "animated_objects": anim_check["animated_objects"],
                    "animation_details": anim_check["animation_details"],
                    "character_images": "",
                    "bg_images": [],
                    "telop_frame_detected": anim_check["telop_frame_detected"],
                    "audio_duration": 0.0,
                    "audio_file": f"slide_{idx:03d}.wav",
                    "is_enabled": bool(final_text)
                })

                prev_slide_info = {
                    "bg_images": [],
                    "char_images": [],
                    "telop_frame_detected": anim_check["telop_frame_detected"],
                    "text_content": combined_text
                }

    except Exception as e:
        print(f"[ERROR] parse_pptx_directly failed: {e}")

    return slides

