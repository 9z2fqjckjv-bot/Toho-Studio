#!/usr/bin/env python3
"""Create 東方キャラ立ち絵スタジオ / 東方ムービーメーカ folder trees under project root."""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, ROOT)
from src.core.path_utils import ensure_app_layout

if __name__ == "__main__":
    layout = ensure_app_layout(ROOT)
    for app, subs in layout.items():
        print(app)
        for k, v in subs.items():
            print(f"  {k}: {v}")
