## SSD sync note

Full updated sources for this feature (including large `src/web_psd/app.js`, `src/psd_studio_server.py`, `src/server.py`, `src/core/project_manager.py`, and `src/web_psd/vendor/*`) are applied on the Mac SSD tree:

`/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story`

GitHub receives the path layout, launchers, and path_utils redirects. Copy the remaining studio UI/server files from the SSD if a clone is missing them.

### Zoom / eyedropper (studio)

- Wheel zoom toward cursor (up to 1600%)
- Cmd± / Cmd0 shortcuts; 400% button for fine eyedropper
- `canvasCoordsFromEvent` mapping under CSS transform scale
- pixelated rendering at high zoom; session autosave to `東方キャラ立ち絵スタジオ/projects` + backups
