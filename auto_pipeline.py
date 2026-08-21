import csv
import os
from pathlib import Path

import requests
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from moviepy.editor import AudioFileClip, ImageClip, concatenate_videoclips


BASE_DIR = Path(__file__).resolve().parent
SLIDES_DIR = BASE_DIR / "slides"
AUDIO_DIR = BASE_DIR / "audios"
KEYNOTE_EXPORT_DIR = SLIDES_DIR / "交換夫婦（22話目）"
KEYNOTE_EXPORT_PREFIX = "交換夫婦（22話目）"
REFERENCE_CSV = BASE_DIR / "交換夫婦22話-台本.csv"

def _percent_to_scale(value, default=100):
    if value in (None, ""):
        value = default
    return float(value) / 100


def load_script_rows(csv_path):
    with open(csv_path, "r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    if rows and not rows[0].get("slide_num") and REFERENCE_CSV.exists():
        with open(REFERENCE_CSV, "r", encoding="utf-8") as f:
            reference_rows = list(csv.DictReader(f))
        if len(reference_rows) == len(rows):
            for row, reference_row in zip(rows, reference_rows):
                row["slide_num"] = reference_row["slide_num"]

    return rows


def _slide_image_path(slide_num):
    candidates = [
        SLIDES_DIR / f"slide_{slide_num}.png",
        SLIDES_DIR / f"slide_{slide_num}.jpg",
        SLIDES_DIR / f"slide_{slide_num}.jpeg",
        KEYNOTE_EXPORT_DIR / f"{KEYNOTE_EXPORT_PREFIX}.{int(slide_num):03}.png",
        KEYNOTE_EXPORT_DIR / f"{KEYNOTE_EXPORT_PREFIX}.{int(slide_num):03}.jpg",
        KEYNOTE_EXPORT_DIR / f"{KEYNOTE_EXPORT_PREFIX}.{int(slide_num):03}.jpeg",
    ]
    return next((path for path in candidates if path.exists()), None)


def generate_audios_from_rows(rows):
    print("--- [Step 1] 音声の自動生成を開始 ---")
    AUDIO_DIR.mkdir(exist_ok=True)

    for index, row in enumerate(rows, start=1):
        slide_num = row.get("slide_num") or index
        char_name = row["character"]
        text = row["text"]
        voice_type = row.get("voice_type", "f1")
        speed_scale = _percent_to_scale(row.get("speed"))
        pitch_scale = _percent_to_scale(row.get("pitch"))

        speaker = voice_type or "f1"

        base_url = "http://localhost:50021"

        res_query = requests.post(
            f"{base_url}/audio_query",
            params={"text": text, "speaker": speaker},
            timeout=60,
        )
        res_query.raise_for_status()
        query_data = res_query.json()
        query_data["speedScale"] = speed_scale
        query_data["pitchScale"] = pitch_scale

        res_synth = requests.post(
            f"{base_url}/synthesis",
            params={"speaker": speaker},
            json=query_data,
            timeout=60,
        )
        res_synth.raise_for_status()

        audio_path = AUDIO_DIR / f"slide_{slide_num}.wav"
        with open(audio_path, "wb") as audio_file:
            audio_file.write(res_synth.content)

        print(f"スライド {slide_num} ({char_name}/{voice_type}): 音声作成完了")


def render_video_from_rows(rows, output_mp4="output.mp4"):
    print("\n--- [Step 2] 動画の自動結合・レンダリングを開始 ---")
    clips = []

    for index, row in enumerate(rows, start=1):
        slide_num = row.get("slide_num") or index
        img_path = _slide_image_path(slide_num)
        audio_path = AUDIO_DIR / f"slide_{slide_num}.wav"

        if img_path is None or not audio_path.exists():
            print(f"エラー: スライド {slide_num} の画像または音声が見つかりません。")
            continue

        audio_clip = AudioFileClip(str(audio_path))
        img_clip = ImageClip(str(img_path)).set_duration(audio_clip.duration).set_audio(audio_clip)
        clips.append(img_clip)

    if not clips:
        raise RuntimeError("動画化できるスライドがありません。slides/ と audios/ を確認してください。")

    final_clip = concatenate_videoclips(clips, method="compose")
    temp_audiofile = str(Path(output_mp4).with_name("temp_audio.m4a"))
    final_clip.write_videofile(
        output_mp4,
        fps=24,
        codec="libx264",
        audio_codec="aac",
        temp_audiofile=temp_audiofile,
        remove_temp=True,
    )
    print(f"動画の生成が完了しました: {output_mp4}")
    return output_mp4


def upload_to_youtube(video_path, title="【自動生成】スライド解説動画"):
    print("\n--- [Step 3] YouTubeへ投稿を開始 ---")
    scopes = ["https://www.googleapis.com/auth/youtube.upload"]

    flow = InstalledAppFlow.from_client_secrets_file("client_secret.json", scopes)
    credentials = flow.run_local_server(port=0)
    youtube = build("youtube", "v3", credentials=credentials)

    body = {
        "snippet": {
            "title": title,
            "description": "自動処理パイプラインにより投稿された動画です。",
            "categoryId": "27",
        },
        "status": {
            "privacyStatus": "unlisted",
        },
    }

    media = MediaFileUpload(video_path, chunksize=-1, resumable=True)
    request = youtube.videos().insert(part="snippet,status", body=body, media_body=media)

    response = request.execute()
    print(f"アップロード完了！ 動画ID: https://youtu.be/{response.get('id')}")


if __name__ == "__main__":
    csv_file = "script.csv"
    rows = load_script_rows(csv_file)

    generate_audios_from_rows(rows)

    mp4_file = render_video_from_rows(rows)

    if os.environ.get("UPLOAD_TO_YOUTUBE") == "1":
        upload_to_youtube(mp4_file)
    else:
        print("\nYouTube投稿はスキップしました。投稿する場合は UPLOAD_TO_YOUTUBE=1 を付けて実行してください。")
