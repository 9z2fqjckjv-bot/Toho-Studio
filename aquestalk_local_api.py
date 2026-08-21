import ctypes
import json
import os
import re
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


BASE_DIR = Path(__file__).resolve().parent
AQUESTALK_DIR = BASE_DIR / "aquestalk"
AQUESTALK_LIB = AQUESTALK_DIR / "libAquesTalk10.dylib"
DEFAULT_PLAYER = Path("/Applications/AquesTalkPlayer.app/Contents/MacOS/AquesTalkPlayer")
KANJI_PATTERN = re.compile(r"[一-龯々〆ヵヶ]")
LICENSE_ID_ENV = "AQUESTALK_LICENSE_ID"
USER_KEY_ENV = "AQUESTALK_USER_KEY"
LICENSE_KEY_ENV = "AQUESTALK_LICENSE_KEY"
DEV_KEY_ENV = "AQUESTALK_DEV_KEY"


def _load_dotenv():
    env_path = BASE_DIR / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("\"'")
        os.environ.setdefault(key, value)


class AquesTalkError(RuntimeError):
    pass


class Voice(ctypes.Structure):
    _fields_ = [
        ("bas", ctypes.c_int),
        ("spd", ctypes.c_int),
        ("vol", ctypes.c_int),
        ("pit", ctypes.c_int),
        ("acc", ctypes.c_int),
        ("lmd", ctypes.c_int),
        ("fsc", ctypes.c_int),
    ]


VOICE_PRESETS = {
    2: {"voice": Voice(0, 100, 100, 100, 100, 100, 100), "player_preset": "れいむ"},
    3: {"voice": Voice(1, 105, 100, 105, 100, 100, 100), "player_preset": "まりさ"},
    8: {"voice": Voice(2, 100, 100, 100, 90, 100, 100), "player_preset": "男性"},
    13: {"voice": Voice(2, 110, 100, 90, 70, 80, 100), "player_preset": "機械"},
}


def _load_aquestalk():
    if not AQUESTALK_LIB.exists():
        raise AquesTalkError(f"AquesTalk library not found: {AQUESTALK_LIB}")

    lib = ctypes.CDLL(str(AQUESTALK_LIB))
    lib.AquesTalk_SetDevKey.argtypes = [ctypes.c_char_p]
    lib.AquesTalk_SetDevKey.restype = ctypes.c_int
    lib.AquesTalk_SetUsrKey.argtypes = [ctypes.c_char_p]
    lib.AquesTalk_SetUsrKey.restype = ctypes.c_int
    lib.AquesTalk_Synthe_Utf8.argtypes = [
        ctypes.POINTER(Voice),
        ctypes.c_char_p,
        ctypes.POINTER(ctypes.c_int),
    ]
    lib.AquesTalk_Synthe_Utf8.restype = ctypes.POINTER(ctypes.c_ubyte)
    lib.AquesTalk_FreeWave.argtypes = [ctypes.POINTER(ctypes.c_ubyte)]

    dev_key = os.environ.get(DEV_KEY_ENV)
    if dev_key:
        result = lib.AquesTalk_SetDevKey(dev_key.encode("utf-8"))
        if result != 0:
            raise AquesTalkError(f"{DEV_KEY_ENV} is set, but AquesTalk rejected the key")

    user_key = os.environ.get(USER_KEY_ENV) or os.environ.get(LICENSE_KEY_ENV)
    if user_key:
        result = lib.AquesTalk_SetUsrKey(user_key.encode("utf-8"))
        if result != 0:
            raise AquesTalkError(f"{USER_KEY_ENV} is set, but AquesTalk rejected the key")

    return lib


_load_dotenv()
AQUESTALK = _load_aquestalk()


def _license_status():
    return {
        "license_id": "set" if os.environ.get(LICENSE_ID_ENV) else "not set",
        "user_key": "set" if os.environ.get(USER_KEY_ENV) or os.environ.get(LICENSE_KEY_ENV) else "not set",
        "dev_key": "set" if os.environ.get(DEV_KEY_ENV) else "not set",
    }


def _player_path():
    configured = os.environ.get("AQUESTALKPLAYER_PATH")
    if configured:
        path = Path(configured).expanduser()
        if path.exists():
            return path
    if DEFAULT_PLAYER.exists():
        return DEFAULT_PLAYER
    return None


def _voice_for_speaker(speaker, speed_scale):
    preset = VOICE_PRESETS.get(speaker, VOICE_PRESETS[2])
    voice = Voice(
        preset["voice"].bas,
        max(50, min(300, round(preset["voice"].spd * speed_scale))),
        preset["voice"].vol,
        preset["voice"].pit,
        preset["voice"].acc,
        preset["voice"].lmd,
        preset["voice"].fsc,
    )
    return voice, preset["player_preset"]


def _synthesize_with_player(text, preset_name, output_path):
    player = _player_path()
    if player is None:
        raise AquesTalkError(
            "漢字かな混じり文を読むには AquesTalkPlayer Mac が必要です。"
            "ひらがな/カタカナの音声記号列にするか、AquesTalkPlayer.app を /Applications に入れてください。"
        )

    command = [str(player), "-T", text, "-P", preset_name, "-W", str(output_path)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        command = [str(player), "-T", text, "-W", str(output_path)]
        result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit code {result.returncode}"
        raise AquesTalkError(f"AquesTalkPlayer failed: {detail}")

    return output_path.read_bytes()


def synthesize_wav(text, speaker=2, speed_scale=1.0):
    voice, player_preset = _voice_for_speaker(speaker, speed_scale)

    if KANJI_PATTERN.search(text):
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp_path = Path(tmp.name)
        try:
            return _synthesize_with_player(text, player_preset, tmp_path)
        finally:
            tmp_path.unlink(missing_ok=True)

    size = ctypes.c_int()
    wav = AQUESTALK.AquesTalk_Synthe_Utf8(
        ctypes.byref(voice),
        text.encode("utf-8"),
        ctypes.byref(size),
    )
    if not wav:
        raise AquesTalkError(f"AquesTalk synthesis failed with error code {size.value}")

    try:
        return ctypes.string_at(wav, size.value)
    finally:
        AQUESTALK.AquesTalk_FreeWave(wav)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"{self.address_string()} - {format % args}")

    def _send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_wav(self, data):
        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send_json(
                200,
                {
                    "status": "ok",
                    "engine": "AquesTalk10",
                    "license": _license_status(),
                },
            )
            return
        if parsed.path == "/speakers":
            self._send_json(200, {"speakers": sorted(VOICE_PRESETS)})
            return
        self._send_json(404, {"detail": "not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)

        try:
            if parsed.path == "/audio_query":
                text = params.get("text", [""])[0]
                speaker = int(params.get("speaker", ["2"])[0])
                self._send_json(
                    200,
                    {
                        "text": text,
                        "speaker": speaker,
                        "speedScale": 1.0,
                    },
                )
                return

            if parsed.path == "/synthesis":
                body = self._read_json()
                text = body.get("text", "")
                speaker = int(params.get("speaker", [body.get("speaker", 2)])[0])
                speed_scale = float(body.get("speedScale", 1.0))
                self._send_wav(synthesize_wav(text, speaker, speed_scale))
                return

            if parsed.path == "/synthesize":
                body = self._read_json()
                text = body.get("text", "")
                speaker = int(body.get("speaker", 2))
                speed_scale = float(body.get("speedScale", 1.0))
                self._send_wav(synthesize_wav(text, speaker, speed_scale))
                return
        except Exception as exc:
            self._send_json(400, {"detail": str(exc)})
            return

        self._send_json(404, {"detail": "not found"})


def main():
    host = os.environ.get("AQUESTALK_API_HOST", "127.0.0.1")
    port = int(os.environ.get("AQUESTALK_API_PORT", "50021"))
    server = ThreadingHTTPServer((host, port), Handler)
    print(f"AquesTalk local API listening on http://{host}:{port}")
    print(f"AquesTalk10 dylib: {AQUESTALK_LIB}")
    print(f"License ID: {_license_status()['license_id']}")
    print(f"Usage license key: {_license_status()['user_key']}")
    print(f"Development license key: {_license_status()['dev_key']}")
    if _player_path():
        print(f"AquesTalkPlayer: {_player_path()}")
    else:
        print("AquesTalkPlayer: not found; kanji text requires kana/phonetic input")
    server.serve_forever()


if __name__ == "__main__":
    main()
