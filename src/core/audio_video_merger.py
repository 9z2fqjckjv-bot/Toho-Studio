"""
音声・動画結合およびタイムライン管理モジュール (ffmpeg & タイムライン合成)
- スライド音声の連続結合 (各スライドのディレイに合わせたタイムライン配置)
- 効果音 (SE) / BGM のタイムスタンプ配置とミックス
- Keynote 書き出し動画 (MOV/MP4) への音声当て入れ
- SE・BGM 素材フォルダの自動検出
"""

import os
import wave
import json
import struct
import subprocess
from typing import List, Dict, Any, Optional
from .path_utils import get_media_dir
from .keynote_parser import has_animation_instruction

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS_DIR = os.path.join(PROJECT_ROOT, "動画用")


class AudioVideoMerger:
    @staticmethod
    def list_sound_effects(assets_dir: str = ASSETS_DIR) -> List[Dict[str, Any]]:
        """「動画用 > 音楽」フォルダ配下の中から効果音・BGM 素材のみを探索して一覧を返す"""
        sound_files = []
        music_dir = os.path.join(assets_dir, "音楽")
        if not os.path.exists(music_dir):
            return sound_files

        valid_exts = {".wav", ".mp3", ".m4a", ".aac", ".ogg", ".flac", ".aiff"}

        for root, _, files in os.walk(music_dir):
            for f in sorted(files):
                if f.startswith("._") or f.startswith("."):
                    continue
                ext = os.path.splitext(f)[1].lower()
                if ext in valid_exts:
                    full_p = os.path.join(root, f)
                    rel_p = os.path.relpath(full_p, assets_dir)
                    category = os.path.basename(root) # "効果音" or "BGM" or "音楽"
                    # 表示用名称（拡張子なしや分かりやすい名前）
                    display_name = os.path.splitext(f)[0]
                    sound_files.append({
                        "name": display_name,
                        "filename": f,
                        "path": full_p,
                        "relative_path": rel_p,
                        "category": category,
                        "is_bgm": "bgm" in category.lower() or "bgm" in f.lower(),
                        "size_bytes": os.path.getsize(full_p)
                    })

        return sound_files

    @classmethod
    def build_timeline_audio(
        cls,
        slides_audio_info: List[Dict[str, Any]],
        padding_delay: float = 0.5,
        effects: Optional[List[Dict[str, Any]]] = None,
        bgm_info: Optional[Dict[str, Any]] = None,
        out_wav_path: str = "/tmp/merged_timeline_audio.wav"
    ) -> Dict[str, Any]:
        """
        スライドごとの音声ファイルと効果音・BGMをタイムラインに沿って一本の完全な音声ファイルに結合・ミックスする。
        @param slides_audio_info: [{'slide_index': 1, 'audio_path': '...', 'duration': 2.3, 'is_enabled': True}, ...]
        @param padding_delay: 各スライド間の余白時間（秒）
        @param effects: [{'time_offset': 5.2, 'audio_path': '...', 'volume': 1.0, 'name': 'SE'}, ...]
        @param bgm_info: {'audio_path': '...', 'volume': 0.3, 'loop': True}
        @param out_wav_path: 出力先WAVパス
        @return: 結果情報 (total_duration, timeline_markers, output_path)
        """
        os.makedirs(os.path.dirname(os.path.abspath(out_wav_path)), exist_ok=True)
        tmp_dir = os.path.dirname(os.path.abspath(out_wav_path))

        # 1. タイムラインマーカー（各スライドの開始時間）を計算
        timeline_markers = []
        current_time = 0.0

        for i, item in enumerate(slides_audio_info):
            s_idx = item.get("slide_index", i + 1)
            audio_p = item.get("audio_path")
            dur = item.get("duration", 0.0)
            is_en = item.get("is_enabled", True)
            # スライド個別の余白・アニメーション待機時間 (未指定時は 0.0)
            slide_pad = float(item.get("extra_delay", 0.0) or 0.0)

            marker = {
                "slide_index": s_idx,
                "start_time": round(current_time, 3),
                "duration": round(dur, 3),
                "extra_delay": round(slide_pad, 3),
                "is_enabled": is_en
            }
            timeline_markers.append(marker)

            if is_en and audio_p and os.path.exists(audio_p) and dur > 0:
                current_time += (dur + slide_pad)
            else:
                current_time += max(1.0, slide_pad)

        num_slides = len(slides_audio_info)
        if num_slides == 0:
            return {"success": False, "error": "No slides provided."}

        total_speech_duration = current_time

        # 無音WAVの生成用（無音スライド用）
        silence_wav = os.path.join(tmp_dir, "silence_1s.wav")
        subprocess.run([
            "ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo",
            "-t", "1.0", "-c:a", "pcm_s16le", silence_wav
        ], capture_output=True)

        # チャンク分割結合 (Too many open files 対策: 40スライドずつ結合)
        CHUNK_SIZE = 40
        chunk_files = []
        speech_wav_path = os.path.join(tmp_dir, "speech_track_merged.wav")

        for c_idx in range(0, num_slides, CHUNK_SIZE):
            chunk_items = slides_audio_info[c_idx:c_idx + CHUNK_SIZE]
            valid_slide_inputs = []
            filter_parts = []

            for item in chunk_items:
                audio_p = item.get("audio_path")
                dur = item.get("duration", 0.0)
                is_en = item.get("is_enabled", True)
                slide_pad = float(item.get("extra_delay", 0.0) or 0.0)

                if is_en and audio_p and os.path.exists(audio_p) and dur > 0:
                    valid_slide_inputs.extend(["-i", audio_p])
                    s_idx_input = len(valid_slide_inputs) // 2 - 1
                    filter_parts.append(
                        f"[{s_idx_input}:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo,apad=pad_dur={slide_pad}[s{s_idx_input}];"
                    )
                else:
                    valid_slide_inputs.extend(["-i", silence_wav])
                    s_idx_input = len(valid_slide_inputs) // 2 - 1
                    filter_parts.append(
                        f"[{s_idx_input}:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[s{s_idx_input}];"
                    )

            num_chunk_slides = len(chunk_items)
            concat_in_str = "".join([f"[s{i}]" for i in range(num_chunk_slides)])
            filter_parts.append(f"{concat_in_str}concat=n={num_chunk_slides}:v=0:a=1[chunk_out]")

            if num_slides <= CHUNK_SIZE:
                target_chunk_wav = speech_wav_path
            else:
                target_chunk_wav = os.path.join(tmp_dir, f"speech_chunk_{c_idx // CHUNK_SIZE:04d}.wav")

            cmd_chunk = [
                "ffmpeg", "-y",
                *valid_slide_inputs,
                "-filter_complex", "".join(filter_parts),
                "-map", "[chunk_out]",
                "-c:a", "pcm_s16le",
                target_chunk_wav
            ]

            res_chunk = subprocess.run(cmd_chunk, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
            if res_chunk.returncode != 0:
                print(f"[ERROR] Speech chunk concat failed: {res_chunk.stderr}")
                return {"success": False, "error": f"Speech track concat failed: {res_chunk.stderr}"}

            chunk_files.append(target_chunk_wav)

        if num_slides > CHUNK_SIZE:
            # 複数チャンクを concat demuxer で結合
            chunk_list_file = os.path.join(tmp_dir, "speech_chunks_concat.txt")
            with open(chunk_list_file, "w", encoding="utf-8") as f:
                for cf in chunk_files:
                    f.write(f"file '{cf}'\n")

            cmd_concat = [
                "ffmpeg", "-y",
                "-f", "concat", "-safe", "0",
                "-i", chunk_list_file,
                "-c:a", "pcm_s16le",
                speech_wav_path
            ]
            res_concat = subprocess.run(cmd_concat, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
            if res_concat.returncode != 0:
                print(f"[ERROR] Speech chunks merge failed: {res_concat.stderr}")
                return {"success": False, "error": f"Speech chunks merge failed: {res_concat.stderr}"}

            # 中間チャンクファイルをクリーンアップ
            for cf in chunk_files:
                if os.path.exists(cf) and cf != speech_wav_path:
                    try:
                        os.remove(cf)
                    except Exception:
                        pass
            if os.path.exists(chunk_list_file):
                try:
                    os.remove(chunk_list_file)
                except Exception:
                    pass

        # 2. ボイストラックに効果音 (SE) および BGM をオーバーレイ・ミックス
        # ベースは speech_wav_path (Input 0)
        mix_inputs = ["-i", speech_wav_path]
        mix_filters = ["[0:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[m0];"]
        mix_count = 1

        # 効果音 (SE)
        if effects:
            for eff in effects:
                eff_path = eff.get("audio_path")
                t_offset = float(eff.get("time_offset", 0.0))
                vol = float(eff.get("volume", 1.0))
                spd = float(eff.get("speed", 1.0))
                is_rev = bool(eff.get("reverse", False))
                if eff_path and os.path.exists(eff_path):
                    mix_inputs.extend(["-i", eff_path])
                    delay_ms = int(t_offset * 1000)
                    filters = []
                    if is_rev:
                        filters.append("areverse")
                    if spd != 1.0 and 0.5 <= spd <= 2.0:
                        filters.append(f"atempo={spd}")
                    filters.append(f"volume={vol}")
                    filters.append(f"adelay={delay_ms}|{delay_ms}")
                    filters.append("aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo")
                    filter_chain = ",".join(filters)
                    mix_filters.append(f"[{mix_count}:a]{filter_chain}[m{mix_count}];")
                    mix_count += 1

        # BGM
        if bgm_info and bgm_info.get("audio_path") and os.path.exists(bgm_info["audio_path"]):
            bgm_path = bgm_info["audio_path"]
            bgm_vol = float(bgm_info.get("volume", 0.25))
            bgm_spd = float(bgm_info.get("speed", 1.0))
            mix_inputs.extend(["-stream_loop", "-1", "-i", bgm_path])
            bgm_filters = []
            if bgm_spd != 1.0 and 0.5 <= bgm_spd <= 2.0:
                bgm_filters.append(f"atempo={bgm_spd}")
            bgm_filters.append(f"volume={bgm_vol}")
            bgm_filters.append("aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo")
            bgm_chain = ",".join(bgm_filters)
            mix_filters.append(f"[{mix_count}:a]{bgm_chain}[m{mix_count}];")
            mix_count += 1

        if mix_count == 1:
            # SEやBGMがない場合はボイストラックをそのまま最終出力とする
            import shutil
            shutil.copy(speech_wav_path, out_wav_path)
        else:
            # amix でミックス（duration=first によりボイストラックの全期間で完了）
            mix_tags = "".join([f"[m{i}]" for i in range(mix_count)])
            mix_filters.append(f"{mix_tags}amix=inputs={mix_count}:duration=first:dropout_transition=0[final_out]")
            cmd_mix = [
                "ffmpeg", "-y",
                *mix_inputs,
                "-filter_complex", "".join(mix_filters),
                "-map", "[final_out]",
                "-c:a", "pcm_s16le",
                out_wav_path
            ]
            res_mix = subprocess.run(cmd_mix, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
            if res_mix.returncode != 0:
                print(f"[ERROR] Final audio mix failed: {res_mix.stderr}")
                return {"success": False, "error": res_mix.stderr}

        return {
            "success": True,
            "output_path": out_wav_path,
            "total_duration": total_speech_duration,
            "timeline_markers": timeline_markers
        }

    @classmethod
    def merge_audio_with_video(
        cls,
        video_input_path: str,
        audio_input_path: str,
        video_output_path: str,
        sync_offset: float = 0.0
    ) -> Dict[str, Any]:
        """
        Keynoteから書き出された動画ファイルに、生成したオーディオトラックを当て入れて完全な動画を保存する。
        @param video_input_path: Keynote書き出し動画 (MOV/MP4等)
        @param audio_input_path: タイムライン結合済みオーディオ (WAV/AAC)
        @param video_output_path: 出力先MP4パス
        @param sync_offset: 音声の開始オフセット（秒）
        """
        if not os.path.exists(video_input_path):
            return {"success": False, "error": f"Video not found: {video_input_path}"}
        if not os.path.exists(audio_input_path):
            return {"success": False, "error": f"Audio not found: {audio_input_path}"}

        os.makedirs(os.path.dirname(os.path.abspath(video_output_path)), exist_ok=True)

        # 動画の長さ・音声の長さを ffprobe で取得
        dur_cmd = [
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1", video_input_path
        ]
        video_duration = 0.0
        try:
            p = subprocess.run(dur_cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if p.returncode == 0:
                video_duration = float(p.stdout.strip())
        except Exception:
            pass

        # ffmpeg 結合コマンド (全編を出力)
        cmd = [
            "ffmpeg", "-y",
            "-i", video_input_path,
            "-i", audio_input_path,
            "-c:v", "copy",
            "-c:a", "aac",
            "-b:a", "192k",
            "-map", "0:v:0",
            "-map", "1:a:0",
            video_output_path
        ]

        try:
            res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
            if res.returncode != 0:
                print(f"[ERROR] ffmpeg video merge failed: {res.stderr}")
                # フォールバック: Apple VideoToolbox 高速エンコーダ
                fallback_cmd = [
                    "ffmpeg", "-y",
                    "-i", video_input_path,
                    "-i", audio_input_path,
                    "-c:v", "h264_videotoolbox",
                    "-b:v", "6000k",
                    "-c:a", "aac",
                    "-b:a", "192k",
                    "-map", "0:v:0",
                    "-map", "1:a:0",
                    video_output_path
                ]
                fb_res = subprocess.run(fallback_cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
                if fb_res.returncode != 0:
                    return {"success": False, "error": fb_res.stderr}

            return {
                "success": True,
                "output_video_path": video_output_path,
                "video_duration": video_duration
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    @classmethod
    def render_slides_to_video(
        cls,
        scenes: List[Dict[str, Any]],
        output_video_path: str,
        effects: Optional[List[Dict[str, Any]]] = None,
        bgm_info: Optional[Dict[str, Any]] = None,
        video_source: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        各シーンのアニメーション動画/スライド画像と音声を繋ぎ合わせて1本の完全な動画 (MP4/MOV) をレンダリングする。
        - 「スライド動画」が「音声」より長い場合: スライド動画の尺に合わせて動画（アニメーション）をレンダリング
        - 「音声」が「スライド動画」より長い場合: 音声の尺に合わせてスライド画像（静止画）をレンダリング
        """
        if not scenes:
            return {"success": False, "error": "シーンがありません。"}

        os.makedirs(os.path.dirname(os.path.abspath(output_video_path)), exist_ok=True)
        tmp_dir = os.path.join(PROJECT_ROOT, ".toho_temp", "render")
        os.makedirs(tmp_dir, exist_ok=True)

        # 1. タイムライン音声の統合
        valid_scenes = [s for s in scenes if s.get("is_enabled", True) and not s.get("is_skipped", False)]
        if not valid_scenes:
            return {"success": False, "error": "有効な（スキップされていない）シーンがありません。"}

        slides_audio_info = []
        for s in valid_scenes:
            is_no_voice = (s.get("no_voice", False) or s.get("is_skipped", False) or s.get("is_enabled") is False)
            dur = 0.0 if is_no_voice else float(s.get("audio_duration", 0.0) or 0.0)

            # ノート/テキストのアニメーション指示タグの有無を判定
            notes_str = str(s.get("notes") or "")
            text_str = str(s.get("text") or "")
            has_anim = bool(s.get("has_animation") and has_animation_instruction(notes_str, text_str))

            # 個別スライド動画 / アニメーションの探索 & 実測尺
            slide_video = (s.get("video_clip_path") or s.get("animation_path")) if has_anim else None
            vid_dur = float(s.get("video_duration") or s.get("animation_duration") or 0.0) if has_anim else 0.0
            if slide_video and os.path.exists(slide_video) and vid_dur <= 0:
                try:
                    cmd_p = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", slide_video]
                    r_p = subprocess.run(cmd_p, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=5)
                    if r_p.returncode == 0 and r_p.stdout.strip():
                        vid_dur = float(r_p.stdout.strip())
                except Exception:
                    pass

            is_video_mode = bool(has_anim and slide_video and os.path.exists(slide_video) and vid_dur > 0 and vid_dur > dur)

            if is_video_mode:
                total_slide_dur = vid_dur
                extra_d = max(0.0, total_slide_dur - dur)
            elif has_anim or is_no_voice:
                extra_d = float(s.get("extra_delay", 2.0 if is_no_voice else 0.0) or 0.0)
            else:
                extra_d = 0.0

            slides_audio_info.append({
                "slide_index": s.get("slide_index", 1),
                "audio_path": None if is_no_voice else s.get("audio_path"),
                "duration": dur,
                "extra_delay": extra_d,
                "is_enabled": True
            })

        audio_res = cls.build_timeline_audio(slides_audio_info, effects=effects, bgm_info=bgm_info)
        if not audio_res.get("success"):
            return audio_res

        merged_audio_path = audio_res["output_path"]
        timeline_markers = audio_res.get("timeline_markers", [])

        # 2. Keynote アニメーション動画 (video_source) の探索
        if not video_source:
            movie_dir = get_media_dir("", "スライドムービー")
            if os.path.exists(movie_dir):
                for f in os.listdir(movie_dir):
                    if f.lower().endswith((".mov", ".mp4")) and not f.startswith("."):
                        cand = os.path.join(movie_dir, f)
                        if os.path.exists(cand) and os.path.getsize(cand) > 10000:
                            video_source = cand
                            break

        # 3. 各スライドの動画クリップ (アニメーション動画 / 静止画) を所要時間に合わせてレンダリング
        segment_files = []
        total_time = 0.0
        has_movie_source = bool(video_source and os.path.exists(video_source))

        for i, s in enumerate(valid_scenes):
            s_idx = s.get("slide_index", i + 1)
            is_no_voice = (s.get("no_voice", False) or s.get("is_skipped", False) or s.get("is_enabled") is False)
            audio_dur = 0.0 if is_no_voice else float(s.get("audio_duration", 0.0) or 0.0)

            # ノート/テキストのアニメーション指示タグの有無を判定
            notes_str = str(s.get("notes") or "")
            text_str = str(s.get("text") or "")
            has_anim = bool(s.get("has_animation") and has_animation_instruction(notes_str, text_str))

            # 個別スライド動画 / アニメーションの探索 & 実測尺
            slide_video = (s.get("video_clip_path") or s.get("animation_path")) if has_anim else None
            img_p = s.get("image_path", "")

            vid_dur = float(s.get("video_duration") or s.get("animation_duration") or 0.0) if has_anim else 0.0
            if slide_video and os.path.exists(slide_video) and vid_dur <= 0:
                try:
                    cmd_p = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", slide_video]
                    r_p = subprocess.run(cmd_p, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=5)
                    if r_p.returncode == 0 and r_p.stdout.strip():
                        vid_dur = float(r_p.stdout.strip())
                except Exception:
                    pass

            # 照合判定: 「スライド動画」が「音声」より長い場合のみ動画を採用し動画尺に合わせる。
            # 「音声」が「スライド動画」より長い場合、またはアニメーション指示がない場合はスライド画像（静止画）を音声尺に合わせて表示。
            is_video_mode = bool(has_anim and slide_video and os.path.exists(slide_video) and vid_dur > 0 and vid_dur > audio_dur)

            if is_video_mode:
                target_dur = vid_dur
            elif has_anim or is_no_voice:
                extra_d = float(s.get("extra_delay", 2.0 if is_no_voice else 0.0) or 0.0)
                target_dur = max(0.3, audio_dur + extra_d)
            else:
                target_dur = max(0.3, audio_dur)

            total_time += target_dur
            seg_out = os.path.join(tmp_dir, f"seg_{i:04d}_slide_{s_idx}.mp4")

            if is_video_mode:
                # スライド個別のアニメーション動画が存在し、動画が音声より長い場合
                cmd_seg = [
                    "ffmpeg", "-y",
                    "-i", slide_video,
                    "-vf", f"scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p,tpad=stop_mode=clone:stop_duration={target_dur + 5:.2f},fps=60",
                    "-t", f"{target_dur:.3f}",
                    "-c:v", "h264_videotoolbox", "-b:v", "8000k",
                    "-an",
                    seg_out
                ]
                subprocess.run(cmd_seg, capture_output=True)
            elif has_movie_source and not img_p:
                # Keynote のアニメーション動画 (MOV) から該当スライド区間を抽出・時間調整
                cmd_seg = [
                    "ffmpeg", "-y",
                    "-ss", f"{max(0, i * 2.0):.2f}",
                    "-i", video_source,
                    "-vf", f"scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p,tpad=stop_mode=clone:stop_duration={target_dur + 5:.2f},fps=60",
                    "-t", f"{target_dur:.3f}",
                    "-c:v", "h264_videotoolbox", "-b:v", "8000k",
                    "-an",
                    seg_out
                ]
                res_seg = subprocess.run(cmd_seg, capture_output=True)
                if res_seg.returncode != 0 or not os.path.exists(seg_out):
                    if not img_p or not os.path.exists(img_p):
                        img_p = os.path.join(tmp_dir, f"black_slide_{i}.png")
                        if not os.path.exists(img_p):
                            subprocess.run(["ffmpeg", "-y", "-f", "lavfi", "-i", "color=c=black:s=1920x1080:d=1", "-vframes", "1", img_p], capture_output=True)
                    cmd_img = [
                        "ffmpeg", "-y",
                        "-loop", "1", "-i", img_p,
                        "-vf", f"scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p,fps=60",
                        "-t", f"{target_dur:.3f}",
                        "-c:v", "h264_videotoolbox", "-b:v", "8000k",
                        "-an",
                        seg_out
                    ]
                    subprocess.run(cmd_img, capture_output=True)
            else:
                # 静止画像（スライド画像）を音声尺に合わせてレンダリング
                if not img_p or not os.path.exists(img_p):
                    img_p = os.path.join(tmp_dir, f"black_slide_{i}.png")
                    if not os.path.exists(img_p):
                        subprocess.run(["ffmpeg", "-y", "-f", "lavfi", "-i", "color=c=black:s=1920x1080:d=1", "-vframes", "1", img_p], capture_output=True)
                cmd_img = [
                    "ffmpeg", "-y",
                    "-loop", "1", "-i", img_p,
                    "-vf", f"scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p,fps=60",
                    "-t", f"{target_dur:.3f}",
                    "-c:v", "h264_videotoolbox", "-b:v", "8000k",
                    "-an",
                    seg_out
                ]
                subprocess.run(cmd_img, capture_output=True)

            if os.path.exists(seg_out):
                segment_files.append(seg_out)

        # 4. 全セグメント動画の concat 結合
        concat_list_file = os.path.join(tmp_dir, "segments_concat.txt")
        with open(concat_list_file, "w", encoding="utf-8") as f:
            for seg in segment_files:
                f.write(f"file '{seg}'\n")

        # 5. 動画と音声を統合して最終書き出し
        cmd_final = [
            "ffmpeg", "-y",
            "-f", "concat", "-safe", "0", "-i", concat_list_file,
            "-i", merged_audio_path,
            "-c:v", "copy",
            "-c:a", "aac", "-b:a", "192k",
            "-shortest",
            output_video_path
        ]

        try:
            res_fin = subprocess.run(cmd_final, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
            if res_fin.returncode != 0:
                # 再エンコードフォールバック
                cmd_reencode = [
                    "ffmpeg", "-y",
                    "-f", "concat", "-safe", "0", "-i", concat_list_file,
                    "-i", merged_audio_path,
                    "-c:v", "h264_videotoolbox", "-b:v", "8000k",
                    "-c:a", "aac", "-b:a", "192k",
                    "-shortest",
                    output_video_path
                ]
                res_re = subprocess.run(cmd_reencode, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
                if res_re.returncode != 0:
                    return {"success": False, "error": res_re.stderr}

            return {
                "success": True,
                "output_video_path": output_video_path,
                "duration": total_time
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    # 後方互換性用エイリアス
    merge_timeline_audio = build_timeline_audio
