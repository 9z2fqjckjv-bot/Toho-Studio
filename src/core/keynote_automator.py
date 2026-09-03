"""
Keynote 自動化モジュール (AppleScript)
- 生成された音声の長さ（秒）に基づいて、Keynote ファイルの各スライドにトランジション（自動切り替えディレイ）を設定・保存
"""

import os
import subprocess
from typing import List, Dict, Any


def apply_transitions_to_keynote(
    keynote_path: str,
    slide_durations: List[Dict[str, Any]],
    padding_delay: float = 0.5,
    save_changes: bool = True
) -> Dict[str, Any]:
    """
    Keynoteファイルを開き、各スライドのトランジションディレイを設定して保存する。
    @param keynote_path: Keynoteファイルの絶対パス
    @param slide_durations: 各スライドの所要時間リスト [{'slide_index': 1, 'duration': 3.5, 'is_enabled': True}, ...]
    @param padding_delay: 音声終了後から次のスライドへ進むまでの余白時間（秒）
    @param save_changes: 保存するかどうか
    @return: 結果情報 dict
    """
    if not os.path.exists(keynote_path):
        return {"success": False, "error": f"File not found: {keynote_path}"}

    delays_map = {}
    for item in slide_durations:
        s_idx = item.get("slide_index")
        dur = item.get("duration", 0.0)
        is_en = item.get("is_enabled", True)
        slide_pad = float(item.get("extra_delay", 0.0) or 0.0)
        if s_idx is not None:
            if is_en and dur > 0:
                delays_map[s_idx] = round(dur + slide_pad, 2)
            else:
                delays_map[s_idx] = max(1.0, round(float(item.get("extra_delay", 2.0) or 2.0), 2))

    script_commands = []
    for s_idx, delay_val in sorted(delays_map.items()):
        script_commands.append(
            f'try\n'
            f'    set s to slide {s_idx} of doc\n'
            f'    set transition properties of s to {{automatic transition:true, transition delay:{delay_val}, transition duration:0.0, transition effect:no transition effect}}\n'
            f'end try'
        )

    commands_body = "\n".join(script_commands)
    save_action = "save doc\nclose doc saving yes" if save_changes else "close doc saving no"

    applescript = f'''
    tell application "Keynote"
        set docPath to POSIX file "{keynote_path}"
        set doc to open file docPath
        
        {commands_body}
        
        {save_action}
        return "SUCCESS"
    end tell
    '''

    for attempt in range(2):
        try:
            if attempt > 0:
                subprocess.run(["open", "-a", "Keynote"], capture_output=True)
                import time
                time.sleep(2.0)

            proc = subprocess.run(
                ["osascript", "-e", applescript],
                capture_output=True,
                text=True,
                timeout=180
            )

            if proc.returncode != 0:
                err_msg = proc.stderr.strip()
                print(f"[ERROR] AppleScript failed (attempt {attempt + 1}): {err_msg}")
                if "-600" in err_msg and attempt == 0:
                    subprocess.run(["open", "-a", "Keynote"], capture_output=True)
                    import time
                    time.sleep(2.5)
                    continue
                return {"success": False, "error": err_msg}

            return {
                "success": True,
                "updated_slides_count": len(delays_map),
                "delays": delays_map
            }

        except subprocess.TimeoutExpired:
            return {"success": False, "error": "AppleScript execution timed out."}
        except Exception as e:
            if attempt == 0:
                subprocess.run(["open", "-a", "Keynote"], capture_output=True)
                import time
                time.sleep(2.0)
                continue
            return {"success": False, "error": str(e)}

    return {"success": False, "error": "Keynote automation failed."}
