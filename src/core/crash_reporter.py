"""
東方Projectムービーメーカー - クラッシュログ記録 & レポート生成モジュール
"""

import os
import sys
import platform
import traceback
import datetime
from typing import Dict, Any, Optional, List

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
_MOVIE_DATA = os.environ.get(
    "TOHO_MOVIE_MAKER_DATA",
    os.path.join(PROJECT_ROOT, "東方ムービーメーカ"),
)
CRASH_REPORT_DIR = os.path.join(_MOVIE_DATA, "logs", "crash_reports")
LEGACY_CRASH_REPORT_DIR = os.path.join(PROJECT_ROOT, "crash_reports")


class CrashReporter:
    _instance = None
    _activity_logs: List[Dict[str, Any]] = []
    _max_logs = 100

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(CrashReporter, cls).__new__(cls)
            cls._instance._init_reporter()
        return cls._instance

    def _init_reporter(self):
        os.makedirs(CRASH_REPORT_DIR, exist_ok=True)
        self.original_excepthook = sys.excepthook
        sys.excepthook = self._handle_uncaught_exception

    def log_activity(self, action: str, details: Optional[Dict[str, Any]] = None):
        entry = {
            "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
            "action": action,
            "details": details or {}
        }
        self._activity_logs.append(entry)
        if len(self._activity_logs) > self._max_logs:
            self._activity_logs.pop(0)

    def _handle_uncaught_exception(self, exc_type, exc_value, exc_traceback):
        tb_str = "".join(traceback.format_exception(exc_type, exc_value, exc_traceback))
        report_path = self.generate_report(
            error_title=f"{exc_type.__name__}: {exc_value}",
            traceback_str=tb_str,
            context={"source": "uncaught_exception"}
        )
        print(f"\n[CRITICAL ERROR] 東方Projectムービーメーカーが予期せぬエラーで停止しました。")
        print(f"[REPORT] クラッシュレポートを保存しました: {report_path}\n")
        if self.original_excepthook:
            self.original_excepthook(exc_type, exc_value, exc_traceback)

    def generate_report(self, error_title: str, traceback_str: str, context: Optional[Dict[str, Any]] = None) -> str:
        os.makedirs(CRASH_REPORT_DIR, exist_ok=True)
        timestamp_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        report_path = os.path.join(CRASH_REPORT_DIR, f"crash_report_{timestamp_str}.txt")
        uname = platform.uname()
        system_info = f"""
OS: {platform.system()} {platform.release()} ({platform.version()})
Machine: {platform.machine()} ({uname.processor})
Python: {platform.python_version()} ({platform.python_implementation()})
Executable: {sys.executable}
Working Directory: {os.getcwd()}
Project Root: {PROJECT_ROOT}
Time: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
"""
        recent_logs_str = "\n".join([
            f"  [{l['timestamp']}] {l['action']} - {l['details']}"
            for l in self._activity_logs[-20:]
        ]) or "  (なし)"
        report_content = f"""================================================================================
東方Projectムービーメーカー - クラッシュレポート
================================================================================
エラー概要:
  {error_title}

発生時刻:
  {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

--------------------------------------------------------------------------------
システム環境:
{system_info.strip()}

--------------------------------------------------------------------------------
追加コンテキスト:
  {context or {}}

--------------------------------------------------------------------------------
直近の操作履歴 (最新20件):
{recent_logs_str}

--------------------------------------------------------------------------------
スタックトレース:
{traceback_str.strip()}
================================================================================
"""
        try:
            with open(report_path, "w", encoding="utf-8") as f:
                f.write(report_content)
        except Exception as e:
            print(f"[ERROR] Failed to write crash report file: {e}")
        return report_path

    def list_reports(self) -> List[Dict[str, Any]]:
        if not os.path.exists(CRASH_REPORT_DIR):
            return []
        reports = []
        for fname in sorted(os.listdir(CRASH_REPORT_DIR), reverse=True):
            if fname.startswith("crash_report_") and fname.endswith(".txt"):
                p = os.path.join(CRASH_REPORT_DIR, fname)
                try:
                    mtime = os.path.getmtime(p)
                    size = os.path.getsize(p)
                    title = "不明なエラー"
                    with open(p, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                        for i, line in enumerate(lines):
                            if "エラー概要:" in line and i + 1 < len(lines):
                                title = lines[i + 1].strip()
                                break
                    reports.append({
                        "filename": fname,
                        "path": p,
                        "title": title,
                        "created_at": datetime.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S"),
                        "size_bytes": size
                    })
                except Exception:
                    pass
        return reports


def get_crash_reporter() -> CrashReporter:
    return CrashReporter()
