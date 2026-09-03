"""
東方Projectムービーメーカー - Final Cut Pro (FCPXML 1.9) エクスポートモジュール
- テロップ（字幕）の出力を完全消去（スライド画像 + 音声 + 独立効果音SEトラック + 独立BGMトラック）
- 複数シーンにまたがる連続効果音（SE）とBGMを隔離された別レーンで完全同期出力
"""

import os
import wave
import pathlib
import xml.etree.ElementTree as ET
from xml.dom import minidom
from typing import List, Dict, Any, Optional
from .keynote_parser import has_animation_instruction


class FCPXMLExporter:
    @classmethod
    def _get_audio_duration_precise(cls, audio_path: str) -> float:
        """WAVファイルから精密な秒数を取得 (フレーム数 / サンプリングレート)"""
        if not audio_path or not os.path.exists(audio_path):
            return 0.0
        try:
            with wave.open(audio_path, 'rb') as wf:
                framerate = wf.getframerate()
                nframes = wf.getnframes()
                if framerate > 0:
                    return float(nframes) / float(framerate)
        except Exception:
            pass
        return 0.0

    @classmethod
    def generate_fcpxml(
        cls,
        project_name: str,
        scenes: List[Dict[str, Any]],
        output_xml_path: str,
        fps: int = 30,
        sound_effects: Optional[List[Dict[str, Any]]] = None,
        bgm: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Final Cut Pro 向け FCPXML を生成
        - テロップ出力は完全消去（スライド画像 + 音声 + 独立SEトラック + 独立BGMトラック）
        - 複数シーンにまたがる連続効果音（SE）とBGMを隔離された別レーンで完全同期出力
        """
        try:
            valid_scenes = [s for s in scenes if s]
            if not valid_scenes:
                return {"success": False, "error": "エクスポート対象のシーンがありません。"}

            # ルート要素 <fcpxml version="1.9">
            fcpxml = ET.Element("fcpxml", version="1.9")
            resources = ET.SubElement(fcpxml, "resources")

            # フォーマット定義 (1920x1080, 30fps)
            format_id = "r1"
            ET.SubElement(
                resources, "format",
                id=format_id,
                name="FFVideoFormat1080p30",
                frameDuration=f"100/{fps * 100}s",
                width="1920",
                height="1080"
            )

            # 2. アセット定義の作成 (重複排除)
            asset_map = {}
            audio_durations = {}

            # 音声 & スライド画像のアセット登録
            for s in valid_scenes:
                audio_p = s.get("audio_path")
                if audio_p and os.path.exists(audio_p) and audio_p not in asset_map:
                    aid = f"r_audio_{len(asset_map) + 10}"
                    asset_map[audio_p] = aid
                    audio_file_uri = pathlib.Path(os.path.abspath(audio_p)).as_uri()

                    real_dur_sec = cls._get_audio_duration_precise(audio_p)
                    audio_durations[audio_p] = real_dur_sec

                    total_frames = int(round(real_dur_sec * fps))
                    dur_str = f"{total_frames * 100}/{fps * 100}s"

                    audio_asset_elem = ET.SubElement(
                        resources, "asset",
                        id=aid,
                        name=os.path.basename(audio_p),
                        start="0s",
                        duration=dur_str,
                        hasAudio="1",
                        audioSources="1",
                        audioChannels="2",
                        audioRate="44100"
                    )
                    ET.SubElement(audio_asset_elem, "media-rep", kind="original-media", src=audio_file_uri)

                img_p = s.get("image_path")
                if img_p and os.path.exists(img_p) and img_p not in asset_map:
                    aid = f"r_img_{len(asset_map) + 10}"
                    asset_map[img_p] = aid
                    img_file_uri = pathlib.Path(os.path.abspath(img_p)).as_uri()

                    img_asset_elem = ET.SubElement(
                        resources, "asset",
                        id=aid,
                        name=os.path.basename(img_p),
                        start="0s",
                        duration="10000/100s",
                        format=format_id,
                        hasVideo="1"
                    )
                    ET.SubElement(img_asset_elem, "media-rep", kind="original-media", src=img_file_uri)

            # 独立効果音 (SE) アセットの登録
            if sound_effects:
                for se in sound_effects:
                    se_p = se.get("audio_path")
                    if se_p and os.path.exists(se_p) and se_p not in asset_map:
                        aid = f"r_se_{len(asset_map) + 10}"
                        asset_map[se_p] = aid
                        se_file_uri = pathlib.Path(os.path.abspath(se_p)).as_uri()
                        real_dur_sec = cls._get_audio_duration_precise(se_p)
                        audio_durations[se_p] = real_dur_sec
                        total_frames = int(round(real_dur_sec * fps))
                        dur_str = f"{total_frames * 100}/{fps * 100}s"
                        se_asset_elem = ET.SubElement(
                            resources, "asset",
                            id=aid,
                            name=os.path.basename(se_p),
                            start="0s",
                            duration=dur_str,
                            hasAudio="1",
                            audioSources="1",
                            audioChannels="2",
                            audioRate="44100"
                        )
                        ET.SubElement(se_asset_elem, "media-rep", kind="original-media", src=se_file_uri)

            # BGM アセットの登録
            if bgm and bgm.get("audio_path"):
                bgm_p = bgm.get("audio_path")
                if bgm_p and os.path.exists(bgm_p) and bgm_p not in asset_map:
                    aid = f"r_bgm_{len(asset_map) + 10}"
                    asset_map[bgm_p] = aid
                    bgm_file_uri = pathlib.Path(os.path.abspath(bgm_p)).as_uri()
                    real_dur_sec = cls._get_audio_duration_precise(bgm_p)
                    audio_durations[bgm_p] = real_dur_sec
                    total_frames = int(round(real_dur_sec * fps))
                    dur_str = f"{total_frames * 100}/{fps * 100}s"
                    bgm_asset_elem = ET.SubElement(
                        resources, "asset",
                        id=aid,
                        name=os.path.basename(bgm_p),
                        start="0s",
                        duration=dur_str,
                        hasAudio="1",
                        audioSources="1",
                        audioChannels="2",
                        audioRate="44100"
                    )
                    ET.SubElement(bgm_asset_elem, "media-rep", kind="original-media", src=bgm_file_uri)

            # 3. イベント & プロジェクト
            event = ET.SubElement(fcpxml, "event", name="東方Projectムービーメーカー")
            project = ET.SubElement(event, "project", name=project_name)

            total_frames = 0
            scene_frame_durations = []
            scene_start_frames = []
            for s in valid_scenes:
                scene_start_frames.append(total_frames)
                is_no_voice = (s.get("no_voice", False) or s.get("is_skipped", False) or s.get("is_enabled") is False)
                notes_str = str(s.get("notes") or "")
                text_str = str(s.get("text") or "")
                has_anim = bool(s.get("has_animation") and has_animation_instruction(notes_str, text_str))

                if is_no_voice:
                    scene_sec = max(1.0, float(s.get("extra_delay", 2.0) or 2.0))
                else:
                    audio_p = s.get("audio_path")
                    dur_sec = audio_durations.get(audio_p, float(s.get("audio_duration", 0.0)))
                    extra_pad = float(s.get("extra_delay", 0.0) or 0.0) if has_anim else 0.0
                    scene_sec = max(0.3, dur_sec + extra_pad)
                f_count = int(round(scene_sec * fps))
                scene_frame_durations.append(f_count)
                total_frames += f_count

            total_dur_str = f"{total_frames * 100}/{fps * 100}s"

            sequence = ET.SubElement(
                project, "sequence",
                format=format_id,
                duration=total_dur_str,
                tcStart="0s",
                tcFormat="NDF"
            )
            spine = ET.SubElement(sequence, "spine")

            # 4. 各シーンのクリップ配置
            first_clip = None
            for idx, s in enumerate(valid_scenes):
                f_dur = scene_frame_durations[idx]
                dur_str = f"{f_dur * 100}/{fps * 100}s"
                scene_name = f"スライド {s.get('slide_index', idx + 1)} ({s.get('character', '操夢')})"

                img_p = s.get("image_path")
                if img_p and img_p in asset_map:
                    primary_clip = ET.SubElement(
                        spine, "video",
                        ref=asset_map[img_p],
                        name=scene_name,
                        duration=dur_str,
                        start="0s"
                    )
                else:
                    primary_clip = ET.SubElement(
                        spine, "gap",
                        name=scene_name,
                        duration=dur_str,
                        start="0s"
                    )

                if first_clip is None:
                    first_clip = primary_clip

                # ボイス音声 (lane="-1", role="dialogue")
                audio_p = s.get("audio_path")
                if audio_p and audio_p in asset_map:
                    aid = asset_map[audio_p]
                    real_dur = audio_durations.get(audio_p, float(s.get("audio_duration", 1.0)))
                    a_dur_frames = int(round(real_dur * fps))
                    a_dur_str = f"{a_dur_frames * 100}/{fps * 100}s"

                    ET.SubElement(
                        primary_clip, "audio",
                        ref=aid,
                        name=os.path.basename(audio_p),
                        offset="0s",
                        duration=a_dur_str,
                        start="0s",
                        lane="-1",
                        role="dialogue"
                    )

                # シーン単体の SE (従来の sound_effect)
                single_se = s.get("sound_effect")
                if single_se and single_se in asset_map:
                    se_aid = asset_map[single_se]
                    se_dur = audio_durations.get(single_se, 1.0)
                    se_dur_frames = int(round(se_dur * fps))
                    se_dur_str = f"{se_dur_frames * 100}/{fps * 100}s"
                    se_offset_sec = float(s.get("se_offset", 0.0))
                    se_off_frames = int(round(se_offset_sec * fps))
                    se_off_str = f"{se_off_frames * 100}/{fps * 100}s"

                    ET.SubElement(
                        primary_clip, "audio",
                        ref=se_aid,
                        name=os.path.basename(single_se),
                        offset=se_off_str,
                        duration=se_dur_str,
                        start="0s",
                        lane="-2",
                        role="effects"
                    )

            # 5. 複数シーン連続効果音 (SE) の配置 (lane="-2", role="effects")
            if sound_effects and first_clip is not None:
                for se in sound_effects:
                    se_p = se.get("audio_path")
                    if not se_p or se_p not in asset_map:
                        continue
                    se_aid = asset_map[se_p]
                    st_sc_idx = int(se.get("start_scene_index", 1)) - 1
                    end_sc_idx = int(se.get("end_scene_index", st_sc_idx + 1)) - 1

                    st_sc_idx = max(0, min(len(scene_start_frames) - 1, st_sc_idx))
                    end_sc_idx = max(st_sc_idx, min(len(scene_start_frames) - 1, end_sc_idx))

                    se_start_f = scene_start_frames[st_sc_idx]
                    se_end_f = scene_start_frames[end_sc_idx] + scene_frame_durations[end_sc_idx]
                    se_span_f = max(fps, se_end_f - se_start_f)

                    se_off_str = f"{se_start_f * 100}/{fps * 100}s"
                    se_dur_str = f"{se_span_f * 100}/{fps * 100}s"

                    ET.SubElement(
                        first_clip, "audio",
                        ref=se_aid,
                        name=se.get("name", os.path.basename(se_p)),
                        offset=se_off_str,
                        duration=se_dur_str,
                        start="0s",
                        lane="-2",
                        role="effects"
                    )

            # 6. BGM の配置 (lane="-3", role="music")
            if bgm and bgm.get("audio_path") and first_clip is not None:
                bgm_p = bgm.get("audio_path")
                if bgm_p in asset_map:
                    bgm_aid = asset_map[bgm_p]
                    ET.SubElement(
                        first_clip, "audio",
                        ref=bgm_aid,
                        name=os.path.basename(bgm_p),
                        offset="0s",
                        duration=total_dur_str,
                        start="0s",
                        lane="-3",
                        role="music"
                    )

            # 7. DTD付きで整形して保存
            raw_xml = ET.tostring(fcpxml, encoding="utf-8")
            parsed = minidom.parseString(raw_xml)
            pretty_xml = parsed.toprettyxml(indent="  ", encoding="utf-8")

            lines = pretty_xml.decode("utf-8").splitlines()
            if len(lines) > 1 and "<?xml" in lines[0]:
                lines.insert(1, "<!DOCTYPE fcpxml>")
            final_xml_str = "\n".join(lines).encode("utf-8")

            os.makedirs(os.path.dirname(os.path.abspath(output_xml_path)), exist_ok=True)
            with open(output_xml_path, "wb") as f:
                f.write(final_xml_str)

            return {
                "success": True,
                "output_path": output_xml_path,
                "total_scenes": len(valid_scenes),
                "total_duration_sec": total_frames / float(fps)
            }
        except Exception as e:
            return {"success": False, "error": f"FCPXML export failed: {e}"}
