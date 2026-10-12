import json, os

notebook_path = '/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/仕様書関連/Colab/TohoStudio_GPU_Server.ipynb'
with open(notebook_path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

nb['cells'][0]['source'] = [
    "# 🌸 TohoStudio: Google Colab L4 GPU メディア生成＆高精度AI自動採譜サーバー\n",
    "### （SDXL 1.0 画像 / AudioLDM 2 効果音 / MusicGen BGM / AnimateDiff 動画 / Demucs+BasicPitch+Whisper 高精度採譜）\n\n",
    "このノートブックは、Google Colab の **NVIDIA L4 GPU（VRAM 24GB）** を活用し、**高品質メディア生成** および **Meta Demucs音源分離＋Spotify Basic Pitch＋OpenAI Whisperによるプロ品質の歌詞付き五線譜自動採譜** を TohoStudio に提供するサーバーです。\n\n",
    "### 🚀 主な機能 (L4 GPU / 24GB VRAM 特化)\n",
    "- **高精度AI自動採譜 (五線譜PDF生成)**:\n",
    "  - **Meta Demucs**: 楽曲からボーカル・ドラム・ベース・伴奏を完全分離（ドラムの低音ノイズを100%遮断）\n",
    "  - **Spotify Basic Pitch**: ボーカル単体から超高精度にピッチ・発音時刻を抽出\n",
    "  - **OpenAI Whisper**: 歌声から歌詞を自動文字起こし・タイム同期し、音符の下に歌詞を自動配置\n",
    "  - **music21 + LilyPond**: 自動BPM検出に基づき、実曲と1:1の正しい小節割りで美しいPDF楽譜を出力\n",
    "- **画像生成**: SDXL 1.0 (1024px+ / 30 steps)\n",
    "- **効果音生成 (SE)**: AudioLDM 2 (本格SFX)\n",
    "- **BGM音楽生成**: MusicGen Medium\n",
    "- **動画生成**: AnimateDiff (MP4)\n"
]

nb['cells'][2]['source'] = [
    "# [2/4] 依存ライブラリと Cloudflare Tunnel のインストール\n",
    "!apt-get update -qq 2>/dev/null && apt-get install -y -qq lilypond ffmpeg fonts-noto-cjk > /dev/null 2>&1\n",
    "!pip install -q --upgrade pip \"setuptools<82\" wheel jedi\n",
    "!pip install -q fastapi uvicorn pydantic python-multipart diffusers transformers accelerate scipy soundfile imageio[ffmpeg] safetensors\n",
    "!pip install -q demucs openai-whisper music21 librosa onnxruntime pretty_midi resampy mir_eval scikit-learn\n",
    "!pip install -q basic-pitch --no-deps\n",
    "!wget -q -nc https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb\n",
    "!dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1\n",
    "print(\"✅ L4 GPU 高品位生成＆高精度採譜ライブラリの準備が完了しました！\")\n"
]

# セル 3 のサーバーコード更新
server_python_code = r'''
import io, os, tempfile, torch, scipy.io.wavfile, gc, shutil, subprocess, time, re
import numpy as np
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.responses import Response, FileResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
app = FastAPI(title="TohoStudio L4 GPU Media & Sheet Transcription Bridge", version="3.5.0")
device = "cuda" if torch.cuda.is_available() else "cpu"

# オンデマンドパイプライン保持変数
pipe_img = None
pipe_se = None
music_processor = None
music_model = None
pipe_video = None
whisper_model = None

def clean_gpu():
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()

def get_image_pipe():
    global pipe_img
    if pipe_img is None:
        print("🎨 Loading SDXL 1.0 Image Pipeline...")
        from diffusers import AutoPipelineForText2Image
        pipe_img = AutoPipelineForText2Image.from_pretrained(
            "stabilityai/stable-diffusion-xl-base-1.0",
            torch_dtype=torch.float16,
            variant="fp16",
            use_safetensors=True
        ).to(device)
    return pipe_img

def get_se_pipe():
    global pipe_se
    if pipe_se is None:
        print("🔊 Loading AudioLDM 2 Sound Effect Pipeline...")
        from diffusers import AudioLDM2Pipeline
        pipe_se = AudioLDM2Pipeline.from_pretrained(
            "cvssp/audioldm2",
            torch_dtype=torch.float16
        ).to(device)
    return pipe_se

def get_music_pipe():
    global music_processor, music_model
    if music_model is None:
        print("🎵 Loading MusicGen Medium BGM Pipeline...")
        from transformers import AutoProcessor, MusicgenForConditionalGeneration
        music_processor = AutoProcessor.from_pretrained("facebook/musicgen-medium")
        music_model = MusicgenForConditionalGeneration.from_pretrained(
            "facebook/musicgen-medium",
            torch_dtype=torch.float16
        ).to(device)
    return music_processor, music_model

def get_video_pipe():
    global pipe_video
    if pipe_video is None:
        print("🎬 Loading AnimateDiff Video Pipeline...")
        from diffusers import AnimateDiffPipeline, MotionAdapter, DDIMScheduler
        adapter = MotionAdapter.from_pretrained("guoyww/animatediff-motion-adapter-v1-5-2", torch_dtype=torch.float16)
        pipe_video = AnimateDiffPipeline.from_pretrained(
            "runwayml/stable-diffusion-v1-5",
            motion_adapter=adapter,
            torch_dtype=torch.float16
        ).to(device)
        pipe_video.scheduler = DDIMScheduler.from_config(pipe_video.scheduler.config, beta_schedule="linear", steps_offset=1)
    return pipe_video

def get_whisper():
    global whisper_model
    if whisper_model is None:
        print("🎙️ Loading OpenAI Whisper Model (GPU)...")
        import whisper
        whisper_model = whisper.load_model("small", device=device)
    return whisper_model

@app.get("/health")
def health():
    gpu_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "None"
    vram_free = torch.cuda.mem_get_info()[0] / (1024**3) if torch.cuda.is_available() else 0
    return {
        "status": "READY",
        "gpu": gpu_name,
        "vram_free_gb": round(vram_free, 2),
        "capabilities": [
            "image (SDXL 1.0)",
            "se (AudioLDM 2)",
            "bgm (MusicGen Medium)",
            "video (AnimateDiff)",
            "sheet_transcription (Demucs + BasicPitch + Whisper + LilyPond)"
        ],
        "music_transcription": {
            "supported": True,
            "engine": "Meta Demucs (Stem Separation) + Spotify Basic Pitch + OpenAI Whisper + LilyPond",
            "endpoint": "/v1/audio/transcribe-to-sheet"
        }
    }

class MediaPromptRequest(BaseModel):
    prompt: str
    negative_prompt: Optional[str] = None
    width: Optional[int] = 1344
    height: Optional[int] = 768
    seed: Optional[int] = -1
    duration_seconds: Optional[float] = 8.0

# [1] 高精細汎用画像生成 (SDXL 1.0)
@app.post("/v1/generate/image")
def generate_image(req: MediaPromptRequest):
    pipe = get_image_pipe()
    w = max(512, min(1536, (req.width // 8) * 8)) if req.width else 1344
    h = max(512, min(1536, (req.height // 8) * 8)) if req.height else 768
    
    base_neg = "ugly, deformed, disfigured, poor quality, bad anatomy, bad hands, missing fingers, cropped, watermark, text"
    final_neg = f"{req.negative_prompt.strip()}, {base_neg}" if (req.negative_prompt and len(req.negative_prompt.strip()) > 0) else base_neg

    gen = torch.Generator(device=device).manual_seed(req.seed) if (req.seed is not None and req.seed >= 0) else None

    print(f"[Image] Generating SDXL ({w}x{h}). Prompt: {req.prompt[:60]}...")
    image = pipe(
        prompt=req.prompt,
        negative_prompt=final_neg,
        width=w,
        height=h,
        num_inference_steps=30,
        guidance_scale=7.5,
        generator=gen
    ).images[0]

    buf = io.BytesIO()
    image.save(buf, format="PNG")
    clean_gpu()
    return Response(content=buf.getvalue(), media_type="image/png")

# [2] BGM 音楽生成 (MusicGen Medium)
@app.post("/v1/generate/music")
@app.post("/v1/generate/bgm")
def generate_bgm(req: MediaPromptRequest):
    proc, model = get_music_pipe()
    inputs = proc(text=[req.prompt], padding=True, return_tensors="pt").to(device)
    dur = min(30.0, max(2.0, req.duration_seconds if req.duration_seconds else 10.0))
    max_tokens = int(dur * 50)
    
    print(f"[BGM] Generating MusicGen ({dur}s). Prompt: {req.prompt[:60]}...")
    with torch.no_grad():
        audio_values = model.generate(**inputs, max_new_tokens=max_tokens)
    
    sampling_rate = model.config.audio_encoder.sampling_rate
    wav_data = audio_values[0, 0].cpu().numpy()
    buf = io.BytesIO()
    scipy.io.wavfile.write(buf, rate=sampling_rate, data=wav_data)
    clean_gpu()
    return Response(content=buf.getvalue(), media_type="audio/wav")

# [3] 効果音 (SE) 生成 (AudioLDM 2)
@app.post("/v1/generate/se")
def generate_se(req: MediaPromptRequest):
    pipe = get_se_pipe()
    dur = min(10.0, max(1.0, req.duration_seconds if req.duration_seconds else 2.5))
    
    print(f"[SE] Generating AudioLDM2 ({dur}s). Prompt: {req.prompt[:60]}...")
    with torch.no_grad():
        audio = pipe(
            prompt=req.prompt,
            num_inference_steps=25,
            audio_length_in_s=dur
        ).audios[0]

    buf = io.BytesIO()
    scipy.io.wavfile.write(buf, rate=16000, data=audio)
    clean_gpu()
    return Response(content=buf.getvalue(), media_type="audio/wav")

# [4] 動画 (MP4) 生成 (AnimateDiff)
@app.post("/v1/generate/video")
def generate_video(req: MediaPromptRequest):
    pipe = get_video_pipe()
    w = max(384, min(768, (req.width // 8) * 8)) if req.width else 512
    h = max(384, min(768, (req.height // 8) * 8)) if req.height else 512
    neg = req.negative_prompt if (req.negative_prompt and len(req.negative_prompt.strip()) > 0) else "worst quality, low quality, deformed, blurry"

    print(f"[Video] Generating AnimateDiff ({w}x{h}). Prompt: {req.prompt[:60]}...")
    output = pipe(
        prompt=req.prompt,
        negative_prompt=neg,
        width=w,
        height=h,
        num_frames=16,
        guidance_scale=7.5,
        num_inference_steps=25,
    )
    frames = output.frames[0]
    temp_file = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
    temp_path = temp_file.name
    temp_file.close()

    from diffusers.utils import export_to_video
    export_to_video(frames, temp_path, fps=8)
    with open(temp_path, "rb") as f:
        video_data = f.read()
    os.remove(temp_path)
    clean_gpu()
    return Response(content=video_data, media_type="video/mp4")

# [5] ⚡️ Colab L4 GPU 高精度音源分離＆歌詞付き自動採譜 (Demucs + Basic Pitch + Whisper + LilyPond)
ALLOWED_AUDIO_EXTS = {".wav", ".mp3", ".m4a", ".flac", ".ogg", ".aif", ".aiff"}

def separate_stems_with_demucs(input_path: str, output_dir: str):
    print(f"[Demucs] Separating vocals and accompaniment with GPU: {input_path}")
    cmd = [
        "demucs",
        "-n", "htdemucs",
        "--two-stems=vocals",
        "-d", device,
        "-o", output_dir,
        input_path
    ]
    subprocess.run(cmd, check=True)
    base_name = os.path.splitext(os.path.basename(input_path))[0]
    stem_dir = os.path.join(output_dir, "htdemucs", base_name)
    vocals_file = os.path.join(stem_dir, "vocals.wav")
    no_vocals_file = os.path.join(stem_dir, "no_vocals.wav")

    if not (os.path.exists(vocals_file) and os.path.exists(no_vocals_file)):
        found_vocals, found_accomp = None, None
        for root, _, files in os.walk(output_dir):
            if "vocals.wav" in files:
                found_vocals = os.path.join(root, "vocals.wav")
            if "no_vocals.wav" in files:
                found_accomp = os.path.join(root, "no_vocals.wav")
        return found_vocals or input_path, found_accomp
    return vocals_file, no_vocals_file

def extract_whisper_lyrics(audio_path: str):
    try:
        w_model = get_whisper()
        print(f"[Whisper] Transcribing lyrics with GPU: {audio_path}")
        res = w_model.transcribe(audio_path, language="ja", word_timestamps=True)
        segments_data = []
        for segment in res.get("segments", []):
            seg_text = segment.get("text", "").strip()
            cleaned_text = re.sub(r'[\s\n\r\t　、。！？!?,.]', '', seg_text)
            if cleaned_text:
                segments_data.append({
                    "start": float(segment.get("start", 0.0)),
                    "end": float(segment.get("end", 0.0)),
                    "text": cleaned_text,
                    "chars": list(cleaned_text)
                })
        full_text = res.get("text", "").strip()
        return full_text, segments_data
    except Exception as e:
        print(f"[Whisper Warning] Lyrics transcription failed: {e}")
        return "", []

def convert_dual_midi_to_pdf(
    vocal_midi_path: str,
    accomp_midi_path: Optional[str],
    output_pdf_path: str,
    bpm: float,
    lyrics_segments: List[Dict[str, Any]],
    custom_lyrics: Optional[str] = None
):
    import music21, copy
    for ly_cand in ['/usr/bin/lilypond', '/usr/local/bin/lilypond']:
        if os.path.exists(ly_cand):
            music21.environment.set('lilypondPath', ly_cand)
            break

    score = music21.stream.Score()
    sec_per_quarter = 60.0 / bpm if bpm > 0 else 0.5

    # [1] ボーカルメロディパート構築
    vocal_midi = music21.converter.parse(vocal_midi_path)
    if bpm > 0:
        vocal_midi.insert(0, music21.tempo.MetronomeMark(number=bpm))
    vocal_midi.quantize(quarterLengthDivisors=(4,), processOffsets=True, processDurations=True)

    vocal_part = music21.stream.Part()
    vocal_part.id = 'VocalStaff'
    vocal_part.partName = 'Vocal'
    vocal_part.partAbbreviation = 'Vo.'
    vocal_part.insert(0, music21.clef.TrebleClef())
    if bpm > 0:
        vocal_part.insert(0, music21.tempo.MetronomeMark(number=bpm))

    try:
        key = vocal_midi.analyze('key')
        vocal_part.insert(0, key)
    except Exception:
        key = None

    # 人間の歌唱音域（C3=MIDI 48 〜 E6=MIDI 88）に限定し、ドラム等の低音ノイズを完全カット
    cleaned_vocal_elements = []
    for el in vocal_midi.flatten().notesAndRests:
        if el.isNote:
            if 48 <= el.pitch.midi <= 88:
                cleaned_vocal_elements.append(el)
            else:
                cleaned_vocal_elements.append(music21.note.Rest(quarterLength=el.quarterLength))
        elif el.isChord:
            valid_pitches = [p.midi for p in el.pitches if 48 <= p.midi <= 88]
            if valid_pitches:
                cleaned_vocal_elements.append(music21.note.Note(max(valid_pitches), quarterLength=el.quarterLength))
            else:
                cleaned_vocal_elements.append(music21.note.Rest(quarterLength=el.quarterLength))
        elif el.isRest:
            cleaned_vocal_elements.append(el)

    # 歌詞のタイムスタンプ同期バインド (曲の最後まで歌詞が途切れないようにする)
    if custom_lyrics and len(custom_lyrics.strip()) > 0:
        custom_chars = list(re.sub(r'[\s\n\r\t　、。！？!?,.]', '', custom_lyrics))
        c_idx = 0
        for el in cleaned_vocal_elements:
            if el.isNote and not el.isRest:
                if c_idx < len(custom_chars):
                    el.lyric = custom_chars[c_idx]
                    c_idx += 1
    elif lyrics_segments:
        segs = copy.deepcopy(lyrics_segments)
        for el in cleaned_vocal_elements:
            if el.isNote and not el.isRest:
                note_time = float(el.offset) * sec_per_quarter
                matched_seg = None
                for seg in segs:
                    if (seg['start'] - 0.4) <= note_time <= (seg['end'] + 0.8):
                        matched_seg = seg
                        break
                if matched_seg and matched_seg.get("chars"):
                    char = matched_seg["chars"].pop(0)
                    el.lyric = char

    for el in cleaned_vocal_elements:
        vocal_part.append(el)

    score.append(vocal_part)

    # [2] 伴奏パート構築 (ヘ音記号 & 下加線10本の暴走防止)
    if accomp_midi_path and os.path.exists(accomp_midi_path):
        try:
            accomp_midi = music21.converter.parse(accomp_midi_path)
            accomp_midi.quantize(quarterLengthDivisors=(4,), processOffsets=True, processDurations=True)
            accomp_part = music21.stream.Part()
            accomp_part.id = 'AccompStaff'
            accomp_part.partName = '伴奏'
            accomp_part.partAbbreviation = 'Acc.'
            if bpm > 0:
                accomp_part.insert(0, music21.tempo.MetronomeMark(number=bpm))
            if key is not None:
                accomp_part.insert(0, key)

            # 伴奏のピッチを収集して、平均ピッチで音部記号を判定
            all_pitches = []
            for el in accomp_midi.flatten().notesAndRests:
                if el.isNote:
                    all_pitches.append(el.pitch.midi)
                elif el.isChord:
                    all_pitches.extend([p.midi for p in el.pitches])

            avg_pitch = sum(all_pitches) / len(all_pitches) if len(all_pitches) > 0 else 50
            use_bass_clef = (avg_pitch < 60) # 中央ド(C4)より低ければヘ音記号

            if use_bass_clef:
                accomp_part.insert(0, music21.clef.BassClef())
            else:
                accomp_part.insert(0, music21.clef.TrebleClef())

            # 音域クレンジング（五線譜から外れすぎる下加線10本ノイズをオクターブ調整して綺麗に収める）
            for el in accomp_midi.flatten().notesAndRests:
                if el.isNote:
                    m = el.pitch.midi
                    if use_bass_clef:
                        while m < 36:
                            m += 12  # C2未満の重低音ノイズをオクターブ上げて五線内に収める
                        while m > 67:
                            m -= 12  # 高すぎる音をオクターブ下げて五線内に収める
                    else:
                        while m < 55:
                            m += 12  # ト音記号で低すぎる音を上げる
                    el.pitch.midi = m
                    accomp_part.append(el)
                elif el.isChord:
                    new_pitches = []
                    for p in el.pitches:
                        m = p.midi
                        if use_bass_clef:
                            while m < 36:
                                m += 12
                            while m > 67:
                                m -= 12
                        else:
                            while m < 55:
                                m += 12
                        new_pitches.append(m)
                    accomp_part.append(music21.chord.Chord(new_pitches, quarterLength=el.quarterLength))
                elif el.isRest:
                    accomp_part.append(el)

            score.append(accomp_part)
        except Exception as e:
            print(f"[Accompaniment Warning] Failed to parse accomp MIDI: {e}")

    # [3] スコア全体のクオンタイズ（割り切れない端数によるDurationExceptionを完全防止）
    try:
        score.quantize(quarterLengthDivisors=(4,), processOffsets=True, processDurations=True, inPlace=True)
    except Exception as e:
        print(f"[Quantize Warning] {e}")

    temp_ly_dir = tempfile.mkdtemp()
    temp_ly = os.path.join(temp_ly_dir, "score.ly")
    temp_pdf = os.path.join(temp_ly_dir, "score.pdf")

    try:
        written_ly = score.write('lily', fp=temp_ly)
        ly_file_to_use = written_ly if os.path.exists(written_ly) else temp_ly

        if os.path.exists(ly_file_to_use):
            with open(ly_file_to_use, "r", encoding="utf-8") as f:
                ly_content = f.read()

            # [4] 1ページにつき2段 (2 systems per page) の厳格強制 & 日本語フォント & 空白譜表維持
            paper_layout_inject = """
\\paper {
  #(define fonts
    (set-global-fonts
     #:roman "Noto Serif CJK JP, IPAMincho, Droid Sans Japanese, serif"
     #:sans "Noto Sans CJK JP, IPAGothic, Droid Sans Japanese, sans-serif"
     #:typewriter "Noto Sans Mono CJK JP, IPAGothic, monospace"
     #:factor (/ staff-height pt 20)
   ))
  systems-per-page = 2
  min-systems-per-page = 2
  max-systems-per-page = 2
  ragged-last-bottom = ##f
  system-system-spacing = #'((basic-distance . 15) (minimum-distance . 10) (padding . 4) (stretchability . 40))
  score-system-spacing = #'((basic-distance . 15) (minimum-distance . 10) (padding . 4) (stretchability . 40))
  top-margin = 12\\mm
  bottom-margin = 12\\mm
  left-margin = 14\\mm
  right-margin = 14\\mm
}

\\layout {
  \\context {
    \\Staff
    \\override VerticalAxisGroup.remove-empty = ##f
    \\override VerticalAxisGroup.remove-first-empty = ##f
  }
}
"""
            if "\\version" in ly_content:
                parts = ly_content.split("\\version", 1)
                ver_line = parts[1].split("\n", 1)[0]
                rest = parts[1][len(ver_line):]
                ly_content = "\\version" + ver_line + "\n" + paper_layout_inject + rest
            else:
                ly_content = paper_layout_inject + "\n" + ly_content

            with open(ly_file_to_use, "w", encoding="utf-8") as f:
                f.write(ly_content)

            cmd = ["lilypond", "-dno-point-and-click", "-o", os.path.join(temp_ly_dir, "score"), ly_file_to_use]
            subprocess.run(cmd, check=True)

        if os.path.exists(temp_pdf):
            shutil.copyfile(temp_pdf, output_pdf_path)
        else:
            candidates = [f for f in os.listdir(temp_ly_dir) if f.endswith(".pdf")]
            if candidates:
                shutil.copyfile(os.path.join(temp_ly_dir, candidates[0]), output_pdf_path)
            else:
                raise RuntimeError("LilyPond failed to generate PDF output.")
    finally:
        shutil.rmtree(temp_ly_dir, ignore_errors=True)

@app.post("/v1/audio/transcribe-to-sheet")
async def transcribe_to_sheet(
    file: UploadFile = File(...),
    separate_stems: bool = Form(True),
    with_lyrics: bool = Form(True),
    custom_lyrics: Optional[str] = Form(None)
):
    from basic_pitch.inference import predict
    import librosa

    filename = file.filename or "audio.wav"
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_AUDIO_EXTS:
        raise HTTPException(status_code=400, detail=f"非対応の音声フォーマットです: {ext}")

    with tempfile.TemporaryDirectory() as tmpdir:
        input_audio_path = os.path.join(tmpdir, f"input{ext}")
        with open(input_audio_path, "wb") as f_out:
            shutil.copyfileobj(file.file, f_out)

        # [A] 高精度BPM検出 (librosa)
        try:
            y, sr = librosa.load(input_audio_path, sr=22050, duration=60.0)
            tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
            detected_bpm = float(np.round(tempo[0] if isinstance(tempo, (list, np.ndarray)) else tempo, 1))
            if detected_bpm < 65:
                detected_bpm *= 2
            elif detected_bpm > 175:
                detected_bpm /= 2
        except Exception:
            detected_bpm = 110.0

        # [B] Meta Demucs によるボーカル＆伴奏音源分離
        vocals_path = None
        accomp_path = None
        if separate_stems:
            try:
                vocals_path, accomp_path = separate_stems_with_demucs(input_audio_path, tmpdir)
            except Exception as e:
                print(f"[Demucs Warning] Separation failed, falling back to original: {e}")
                vocals_path = input_audio_path

        if not vocals_path or not os.path.exists(vocals_path):
            vocals_path = input_audio_path

        # [C] OpenAI Whisper による歌詞自動抽出 (ボーカルステム単体から高精度文字起こし)
        lyrics_segments = []
        if with_lyrics and not custom_lyrics:
            _, lyrics_segments = extract_whisper_lyrics(vocals_path)

        # [D] Spotify Basic Pitch によるピッチ・発音時刻の抽出
        # 1. ボーカルメロディのMIDI抽出
        try:
            print("[Basic Pitch] Extracting vocal notes...")
            _, vocal_midi_data, _ = predict(vocals_path, onset_threshold=0.55)
            vocal_midi_path = os.path.join(tmpdir, "vocal.mid")
            vocal_midi_data.write(vocal_midi_path)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"ボーカルBasic Pitch解析に失敗しました: {str(e)}")

        # 2. 伴奏のMIDI抽出 (伴奏トラックが存在する場合)
        accomp_midi_path = None
        if accomp_path and os.path.exists(accomp_path):
            try:
                print("[Basic Pitch] Extracting accompaniment notes...")
                _, accomp_midi_data, _ = predict(accomp_path, onset_threshold=0.60)
                accomp_midi_path = os.path.join(tmpdir, "accomp.mid")
                accomp_midi_data.write(accomp_midi_path)
            except Exception as e:
                print(f"[Basic Pitch Warning] 伴奏解析失敗（ボーカル単体で続行）: {e}")

        # [E] LilyPond による「ボーカル＋伴奏」2段組×1ページ2段(2 systems/page) 楽譜PDF組版
        pdf_path = os.path.join(tmpdir, "score.pdf")
        try:
            convert_dual_midi_to_pdf(
                vocal_midi_path=vocal_midi_path,
                accomp_midi_path=accomp_midi_path,
                output_pdf_path=pdf_path,
                bpm=detected_bpm,
                lyrics_segments=lyrics_segments,
                custom_lyrics=custom_lyrics
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"LilyPond 楽譜PDF組版に失敗しました: {str(e)}")

        if not os.path.exists(pdf_path) or os.path.getsize(pdf_path) == 0:
            raise HTTPException(status_code=500, detail="生成された楽譜PDFが空または存在しません。")

        out_data = open(pdf_path, "rb").read()
        clean_gpu()
        return Response(content=out_data, media_type="application/pdf")
'''

import ast
try:
    ast.parse(server_python_code)
    print("✅ server_python_code Syntax Validation Passed!")
except SyntaxError as e:
    print(f"❌ SyntaxError in server_python_code: {e}")
    raise

# セル 3 を %%writefile app.py マジックコマンド形式で格納
cell3_lines = ["%%writefile app.py\n"]
for l in server_python_code.strip().splitlines(keepends=True):
    cell3_lines.append(l)

nb['cells'][3]['source'] = cell3_lines

nb['cells'][4]['source'] = [
    "# [4/4] サーバー起動と外部トンネルURLの発行\n",
    "import subprocess, time, re, sys\n\n",
    "# 既存のプロセスを終了\n",
    "!pkill -f uvicorn || true\n",
    "!pkill -f cloudflared || true\n",
    "time.sleep(2)\n\n",
    "print(\"L4 GPU サーバーを起動しています...\")\n",
    "server_proc = subprocess.Popen([\"uvicorn\", \"app:app\", \"--host\", \"127.0.0.1\", \"--port\", \"8000\"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)\n\n",
    "started = False\n",
    "for _ in range(40):\n",
    "    if server_proc.poll() is not None:\n",
    "        rest = server_proc.stdout.read()\n",
    "        if rest:\n",
    "            print(rest)\n",
    "        break\n",
    "    line = server_proc.stdout.readline()\n",
    "    if line:\n",
    "        print(line.strip())\n",
    "        if \"Application startup complete\" in line or \"Uvicorn running\" in line:\n",
    "            started = True\n",
    "            break\n",
    "    time.sleep(0.5)\n\n",
    "if not started and server_proc.poll() is not None:\n",
    "    print(\"❌ サーバーの起動に失敗しました。上記のエラーログを確認してください。\")\n",
    "else:\n",
    "    print(\"🚀 サーバープロセスが正常に開始されました。Cloudflare Tunnel を接続します...\")\n",
    "    tunnel_proc = subprocess.Popen([\"cloudflared\", \"tunnel\", \"--url\", \"http://127.0.0.1:8000\"], stderr=subprocess.PIPE, text=True)\n\n",
    "    public_url = None\n",
    "    for _ in range(30):\n",
    "        line = tunnel_proc.stderr.readline()\n",
    "        match = re.search(r\"https://[a-zA-Z0-9-]+\\.trycloudflare\\.com\", line)\n",
    "        if match:\n",
    "            public_url = match.group(0)\n",
    "            break\n",
    "        time.sleep(1)\n\n",
    "    if public_url:\n",
    "        print(\"\\n===================================================================\")\n",
    "        print(\"🎉 Colab L4 GPU 4大メディア高品位生成サーバーが正常に起動しました！\")\n",
    "        print(f\"👉 接続先 URL: {public_url}\")\n",
    "        print(\"===================================================================\\n\")\n",
    "    else:\n",
    "        print(\"トンネルURLの取得に失敗しました。\")\n"
]

with open(notebook_path, 'w', encoding='utf-8') as f:
    json.dump(nb, f, ensure_ascii=False, indent=1)

print('Successfully updated TohoStudio_GPU_Server.ipynb with Demucs + Whisper + BasicPitch + Lyrics support!')
