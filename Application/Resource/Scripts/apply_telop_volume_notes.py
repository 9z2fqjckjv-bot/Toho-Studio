#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Keynote スライド上の縮小テロップ（小さな文字）を検出し、
発表者ノートにパターンA（話者名＋音量指定）で出力・設定するスクリプト

出力フォーマット例 (パターンA):
（レミリア）「そんなの、決まってるじゃない。」
（レミリア:音量50%）「私はあなたの母親がわりなんだから…」
"""

import sys
import os
import re
import argparse
import subprocess
from collections import Counter

APP_NAME = "Keynote Creator Studio"

def run_applescript(script):
    res = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(res.stderr.strip())
    return res.stdout.strip()

def get_current_slide_index():
    script = f'''
    tell application "{APP_NAME}"
        tell front document
            set curSlide to current slide
            return slide number of curSlide
        end tell
    end tell
    '''
    try:
        out = run_applescript(script)
        return int(out)
    except Exception:
        # フォールバック: 54
        return 54

def get_total_slides():
    script = f'''
    tell application "{APP_NAME}"
        tell front document
            return count of slides
        end tell
    end tell
    '''
    return int(run_applescript(script))

def get_slide_data(slide_idx):
    script = f'''
    tell application "{APP_NAME}"
        tell front document
            set s to slide {slide_idx}
            set pNote to (presenter notes of s as text)
            set shapeData to {{}}
            repeat with shp in shapes of s
                try
                    set t to (object text of shp as text)
                    if t is not "" then
                        set szs to size of characters of object text of shp
                        set AppleScript's text item delimiters to ","
                        set szsStr to szs as text
                        set end of shapeData to t & "<|DATA_SEP|>" & szsStr
                    end if
                end try
            end repeat
            repeat with ti in text items of s
                try
                    set t to (object text of ti as text)
                    if t is not "" then
                        set szs to size of characters of object text of ti
                        set AppleScript's text item delimiters to ","
                        set szsStr to szs as text
                        set end of shapeData to t & "<|DATA_SEP|>" & szsStr
                    end if
                end try
            end repeat
            set AppleScript's text item delimiters to "<|SHP_SEP|>"
            return pNote & "<|COL_SEP|>" & (shapeData as text)
        end tell
    end tell
    '''
    out = run_applescript(script)
    parts = out.split("<|COL_SEP|>")
    pnote = parts[0] if len(parts) > 0 else ""
    shapes_raw = parts[1] if len(parts) > 1 else ""
    
    shapes = []
    if shapes_raw.strip():
        for shp_str in shapes_raw.split("<|SHP_SEP|>"):
            if "<|DATA_SEP|>" in shp_str:
                t, szs_str = shp_str.split("<|DATA_SEP|>", 1)
                szs = []
                for s in szs_str.split(","):
                    try:
                        szs.append(float(s.strip()))
                    except ValueError:
                        pass
                shapes.append((t, szs))
    return pnote, shapes

def extract_speaker(pnote, default="レミリア"):
    bracket_re = re.compile(r'[（\(\[［]([^）\)\]］:：]+?)(?:[:：]音量\d+%?)?[）\)\]］]')
    m = bracket_re.search(pnote)
    if m:
        spk = m.group(1).strip()
        # 演出・アニメーション等のキーワード除外
        if not any(k in spk for k in ["アニメ", "秒", "時間", "フェード", "音量"]):
            return spk
    return default

def process_shape_text(text, sizes, speaker):
    if not text or not sizes or len(text) != len(sizes):
        return None

    # 有効なサイズ判定
    unique_sizes = sorted(list(set(sizes)), reverse=True)
    if len(unique_sizes) <= 1:
        return None

    base_size = max(sizes)
    # 外側のカギ括弧があるか判定
    has_outer = text.startswith("「") and text.endswith("」")
    inner_text = text[1:-1] if has_outer else text
    inner_sizes = sizes[1:-1] if has_outer else sizes

    segments = []
    current_chars = []
    current_size = inner_sizes[0] if inner_sizes else base_size

    for c, sz in zip(inner_text, inner_sizes):
        if abs(sz - current_size) <= 1.0:
            current_chars.append(c)
        else:
            if current_chars:
                ratio = current_size / base_size
                segments.append(("".join(current_chars), ratio))
            current_chars = [c]
            current_size = sz

    if current_chars:
        ratio = current_size / base_size
        segments.append(("".join(current_chars), ratio))

    if len(segments) <= 1:
        return None

    lines = []
    for seg_text, ratio in segments:
        seg_text = seg_text.strip()
        if not seg_text:
            continue
        if not (seg_text.startswith("「") and seg_text.endswith("」")):
            seg_text = f"「{seg_text}」"
        vol_pct = int(round(ratio * 100))
        if vol_pct >= 90:
            lines.append(f"（{speaker}）{seg_text}")
        else:
            lines.append(f"（{speaker}:音量{vol_pct}%）{seg_text}")

    return "\n".join(lines)

def set_presenter_notes(slide_idx, notes):
    # AppleScriptで通常フォントサイズのプレーンテキストとして設定
    escaped_notes = notes.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '" & linefeed & "')
    script = f'''
    tell application "{APP_NAME}"
        tell front document
            set s to slide {slide_idx}
            set presenter notes of s to "{escaped_notes}"
        end tell
    end tell
    '''
    run_applescript(script)

def process_slide(slide_idx):
    pnote, shapes = get_slide_data(slide_idx)
    speaker = extract_speaker(pnote)
    
    updated = False
    for text, sizes in shapes:
        new_note = process_shape_text(text, sizes, speaker)
        if new_note:
            set_presenter_notes(slide_idx, new_note)
            print(f"[スライド {slide_idx}] ノートを更新しました:")
            print(new_note)
            updated = True
            break
    if not updated:
        print(f"[スライド {slide_idx}] 縮小テロップは検出されませんでした（更新なし）")

def main():
    parser = argparse.ArgumentParser(description="Keynote縮小テロップ音量指定ノート生成ツール")
    parser.add_argument("--slide", type=int, help="対象スライド番号 (省略時は現在選択中のスライド)")
    parser.add_argument("--all", action="store_true", help="全スライドを対象に実行")
    args = parser.parse_args()

    if args.all:
        total = get_total_slides()
        print(f"全 {total} スライドをスキャン中...")
        for i in range(1, total + 1):
            process_slide(i)
    else:
        slide_idx = args.slide if args.slide else get_current_slide_index()
        print(f"対象スライド: #{slide_idx}")
        process_slide(slide_idx)

if __name__ == "__main__":
    main()
