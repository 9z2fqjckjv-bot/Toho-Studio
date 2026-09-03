# AquesTalk1 library placement

Place the AquesTalk1 Mac dylib files in this directory.

Expected filenames:

```text
aquestalk1/libAquesTalk1-f1.dylib
aquestalk1/libAquesTalk1-f2.dylib
aquestalk1/libAquesTalk1-f3.dylib
aquestalk1/libAquesTalk1-jgr.dylib
aquestalk1/libAquesTalk1-imd1.dylib
aquestalk1/libAquesTalk1-m1.dylib
aquestalk1/libAquesTalk1-m2.dylib
aquestalk1/libAquesTalk1-r1.dylib
aquestalk1/libAquesTalk1-dvd.dylib
```

The local API uses `AQUESTALK_ENGINE=aquestalk1` and selects the dylib from
the `voice_type` value in `script.csv`.

If the dylibs are stored somewhere else, set this in `.env`:

```text
AQUESTALK1_LIB_DIR=/path/to/aquestalk1/libs
```

For a single fixed voice, you can also set:

```text
AQUESTALK1_LIB_PATH=/path/to/libAquesTalk1-f1.dylib
```
