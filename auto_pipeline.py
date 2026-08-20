import csv
import os

import requests
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from moviepy.editor import AudioFileClip, ImageClip, concatenate_videoclips


# VOICEVOX等の話者ID（Speaker ID）マッピング
# 女性1(f1相当)=2, 女性2(f2相当)=3, 中性(d_1相当)=8 など
VOICE_PROFILES = {
    "霊夢": {"speaker_id": 2, "speed": 1.0},
    "魔理沙": {"speaker_id": 3, "speed": 1.05},
    "案内役（中性）": {"speaker_id": 8, "speed": 1.0},
    "ナレーション（ロボ）": {"speaker_id": 13, "speed": 1.1},
}


def generate_audios_from_csv(csv_path):
    print("--- [Step 1] 音声の自動生成を開始 ---")
    os.makedirs("audios", exist_ok=True)

    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            slide_num = row["slide_num"]
            char_name = row["character"]
            text = row["text"]

            profile = VOICE_PROFILES.get(char_name, {"speaker_id": 2, "speed": 1.0})
            speaker_id = profile["speaker_id"]

            base_url = "http://localhost:50021"

            res_query = requests.post(
                f"{base_url}/audio_query",
                params={"text": text, "speaker": speaker_id},
                timeout=60,
            )
            res_query.raise_for_status()
            query_data = res_query.json()
            query_data["speedScale"] = profile["speed"]

            res_synth = requests.post(
                f"{base_url}/synthesis",
                params={"speaker": speaker_id},
                json=query_data,
                timeout=60,
            )
            res_synth.raise_for_status()

            audio_path = f"audios/slide_{slide_num}.wav"
            with open(audio_path, "wb") as audio_file:
                audio_file.write(res_synth.content)

            print(f"スライド {slide_num} ({char_name}): 音声作成完了")


def render_video_from_slides(slide_count, output_mp4="output.mp4"):
    print("\n--- [Step 2] 動画の自動結合・レンダリングを開始 ---")
    clips = []

    for i in range(1, slide_count + 1):
        img_path = f"slides/slide_{i}.png"
        audio_path = f"audios/slide_{i}.wav"

        if not os.path.exists(img_path) or not os.path.exists(audio_path):
            print(f"エラー: スライド {i} の画像または音声が見つかりません。")
            continue

        audio_clip = AudioFileClip(audio_path)
        img_clip = ImageClip(img_path).set_duration(audio_clip.duration).set_audio(audio_clip)
        clips.append(img_clip)

    if not clips:
        raise RuntimeError("動画化できるスライドがありません。slides/ と audios/ を確認してください。")

    final_clip = concatenate_videoclips(clips, method="compose")
    final_clip.write_videofile(output_mp4, fps=24, codec="libx264", audio_codec="aac")
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

    generate_audios_from_csv(csv_file)

    with open(csv_file, "r", encoding="utf-8") as f:
        slide_count = sum(1 for _ in f) - 1

    mp4_file = render_video_from_slides(slide_count)
    upload_to_youtube(mp4_file)
