#!/usr/bin/env python3
import os, runpy, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
os.environ.setdefault("TOHO_PROJECT_ROOT", ROOT)
os.environ.setdefault("TOHO_CHAR_STUDIO_DATA", os.path.join(ROOT, "東方キャラ立ち絵スタジオ"))
sys.path.insert(0, ROOT)
os.chdir(ROOT)
runpy.run_path(os.path.join(ROOT, "psd_studio_app.py"), run_name="__main__")
