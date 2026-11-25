/**
 * 『東方Project恋愛シミュレーター』フロントエンド制御 (app.js v1.2)
 * 特徴:
 *   - 『キャラステージ演出メーカー』(stage_fx.js) によるプレゼン風拡大縮小・18種モーション・ハイブリッド効果音統合
 *   - 画像・音声 Blob URL の即時 revoke によるメモリリーク完全防止＋アイドル時CPU 0.0%
 *   - 全セーブデータ一覧ロード・任意ターン巻き戻し/分岐再開・ZIP/JSONインポート＆エクスポート
 *   - 会話内容に合わせた毎ターンの動的性格シフト＋UIからの手動変更・固定＋自由会話入力対応
 */

const state = {
  serverUrl: "http://127.0.0.1:8096",
  sessionToken: "",
  user: null,
  catalog: null,
  localConfig: null,
  localAssets: null,

  // 初期設定 (Slide 14-18)
  playerName: "",
  playerKana: "",
  playerGender: "M",
  catIdx: 0,
  charIdx: 0,
  selectedChar: null,
  aiMode: "purchase",
  standaloneMode: false,
  autoBgGeneration: true,
  charColorProfiles: {},
  voiceEnabled: true,
  seEnabled: true,
  seVolume: 0.8,
  userGeminiKey: "",

  // 購入フロー (Slide 19-24)
  planPage: 1,
  selectedPlan: null,
  selectedVoicePlan: null,
  selectedAutoCharge: null,
  selectedDeposit: null,
  pendingOrderId: "",
  voicePool: null,

  // 性格制御（会話連動 auto / 1つ固定 hybrid / 完全固定 locked）
  personalityMode: "auto",
  pinnedPersonalityIds: [],
  customPersonalityNote: "",

  // ゲーム進行・セーブ (Slide 25-32)
  sessionId: "",
  currentScene: null,
  subStep: "narration",
  history: [],
  currentAudioB64: "",
  currentAudioUrl: "",
  audioUnlocked: false,
  inspectingSaveId: "",
};

const el = (id) => document.getElementById(id);

// 省メモリ効果音＆プレゼンステージ演出＆リアルタイム色変えインスタンス
const stageSound = new window.StageSoundEngine({
  enabled: true,
  volume: 0.8,
  localSeEndpoint: "/local/assets/se",
});
const tachieColorEngine = new window.LiveTachieColorEngine();
let stagePresenter = null;

function isApiKeyFreeInputAllowed() {
  return state.aiMode === "apikey" && Boolean(state.userGeminiKey && state.userGeminiKey.trim());
}

function getCharColorProfile(charObj) {
  const cid = (charObj && charObj.char_id) || "default";
  if (!state.charColorProfiles[cid]) {
    state.charColorProfiles[cid] = window.defaultTachieColorProfile();
  }
  return state.charColorProfiles[cid];
}

// Blob URL リーク防止用トラッカー
const blobTracker = {
  preview: "",
  bg: "",
  portrait: "",
  audio: "",
};

function setTrackedBlobUrl(slot, blob) {
  if (blobTracker[slot]) {
    URL.revokeObjectURL(blobTracker[slot]);
    blobTracker[slot] = "";
  }
  if (!blob) return "";
  blobTracker[slot] = URL.createObjectURL(blob);
  return blobTracker[slot];
}

function showScreen(screenId) {
  document.querySelectorAll(".screen").forEach((s) => s.classList.remove("active"));
  const target = el(screenId);
  if (target) target.classList.add("active");
}

function showLoading(title, sub = "") {
  el("loading-title").textContent = title;
  el("loading-sub").textContent = sub;
  showScreen("screen-loading");
}

async function apiGet(path) {
  if (state.standaloneMode && path === "/api/catalog") {
    return localGet("/local/standalone_api/catalog");
  }
  const headers = {};
  if (state.sessionToken) headers["Authorization"] = `Bearer ${state.sessionToken}`;
  const r = await fetch(`${state.serverUrl}${path}`, { headers });
  if (!r.ok) {
    const err = await r.json().catch(() => ({ detail: `HTTP ${r.status}` }));
    throw new Error(err.detail || `HTTP ${r.status}`);
  }
  return r.json();
}

async function apiPost(path, body) {
  if (state.standaloneMode && path.startsWith("/api/")) {
    const localRoute = `/local/standalone_api${path.slice(4)}`;
    const rLocal = await fetch(localRoute, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const dLocal = await rLocal.json();
    if (!rLocal.ok) throw new Error(dLocal.detail || dLocal.error || `HTTP ${rLocal.status}`);
    return dLocal;
  }
  const headers = { "Content-Type": "application/json" };
  if (state.sessionToken) headers["Authorization"] = `Bearer ${state.sessionToken}`;
  const r = await fetch(`${state.serverUrl}${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
  if (!r.ok) {
    const err = await r.json().catch(() => ({ detail: `HTTP ${r.status}` }));
    throw new Error(err.detail || `HTTP ${r.status}`);
  }
  return r.json();
}

async function localGet(path) {
  const r = await fetch(path);
  return r.json();
}

async function localPost(path, body) {
  const r = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return r.json();
}

// ==================== ローカルPC素材フォルダ URL ビルダー ====================

function localPortraitUrl(charObj, emotion = "normal", preferBlush = false) {
  if (!charObj) return "";
  const aliases = Array.isArray(charObj.aliases) ? charObj.aliases.join(",") : (charObj.aliases_csv || "");
  const params = new URLSearchParams({
    char_name: charObj.name || "",
    aliases,
    emotion: emotion || "normal",
    blush: preferBlush ? "1" : "0",
  });
  return `/local/assets/portrait?${params.toString()}`;
}

function localBackgroundUrl(bgDirective) {
  if (!bgDirective) return `/local/assets/background`;
  const params = new URLSearchParams({
    bg_id: bgDirective.bg_id || "",
    keyword: bgDirective.name || bgDirective.keyword || "",
    time_of_day: bgDirective.time_of_day || "",
  });
  return `/local/assets/background?${params.toString()}`;
}

function updateAssetsBadge(summary) {
  state.localAssets = summary;
  stageSound.setLocalSeCatalog(summary?.sound_effects || []);
  const badge = el("assets-detect-badge");
  const pCnt = summary?.portrait_file_count || 0;
  const bCnt = summary?.background_count || 0;
  const seCnt = summary?.se_count || 0;
  if (pCnt > 0 || bCnt > 0) {
    badge.className = "assets-badge ok";
    badge.textContent = `検出済: 立ち絵 ${pCnt.toLocaleString()}枚 / 背景 ${bCnt.toLocaleString()}枚 / SE 内蔵20種+ローカル${seCnt}件`;
  } else {
    badge.className = "assets-badge warn";
    badge.textContent = "未検出（立ち絵・背景フォルダを指定してください / 内蔵SE20種は有効）";
  }
}

function updateSeHudButton() {
  const btn = el("btn-toggle-se");
  if (btn) btn.textContent = state.seEnabled ? "🔔 SE:ON" : "🔕 SE:OFF";
  if (el("chk-hud-se-enabled")) el("chk-hud-se-enabled").checked = state.seEnabled;
  if (el("rng-se-volume")) el("rng-se-volume").value = Math.round(state.seVolume * 100);
  stageSound.enabled = state.seEnabled;
  stageSound.masterVolume = state.seVolume;
}

// ==================== Slide 11 -> 12 -> 13: 起動検証と初期化 ====================

async function bootSequence() {
  stagePresenter = new window.StagePresenter(
    {
      bgEl: el("novel-bg"),
      screenEl: el("screen-novel"),
      rigEl: el("novel-rig"),
      motionEl: el("novel-motion"),
      portraitEl: el("novel-portrait"),
      overlayEl: el("novel-fx-overlay"),
      badgeEl: el("novel-stage-badge"),
    },
    stageSound
  );

  showLoading("検証中…", "プログラム整合性とローカル素材フォルダを確認しています…");
  await new Promise((r) => setTimeout(r, 320));

  const verify = await localGet("/local/verify");
  if (!verify.ok && verify.blocked) {
    el("blocked-reason").textContent = verify.reason;
    showScreen("screen-blocked");
    return;
  }

  const cfg = await localGet("/local/config");
  state.localConfig = cfg;
  state.serverUrl = cfg.server_url || state.serverUrl;
  state.sessionToken = cfg.session_token || "";
  state.userGeminiKey = cfg.user_gemini_api_key || "";
  state.voiceEnabled = cfg.voice_enabled !== false;
  state.seEnabled = cfg.se_enabled !== false;
  state.seVolume = typeof cfg.se_volume === "number" ? cfg.se_volume : 0.8;
  state.autoBgGeneration = cfg.auto_bg_generation !== false;
  state.charColorProfiles = cfg.char_color_profiles || {};

  el("input-server-url").value = state.serverUrl;
  el("input-gemini-key").value = state.userGeminiKey;
  if (el("chk-auto-bg-gen")) el("chk-auto-bg-gen").checked = state.autoBgGeneration;
  el("chk-voice-enabled").checked = state.voiceEnabled;
  el("chk-hud-voice-enabled").checked = state.voiceEnabled;
  el("input-assets-root").value = cfg.assets_root_dir || "";
  el("input-portraits-override").value = cfg.portraits_dir_override || "";
  el("input-bgs-override").value = cfg.backgrounds_dir_override || "";
  if (el("input-se-override")) el("input-se-override").value = cfg.se_dir_override || "";
  if (cfg.has_stage_studio) el("btn-open-stage-studio").classList.remove("hidden");

  updateSeHudButton();
  updateAssetsBadge(cfg.assets_summary);

  showLoading("起動中…", "キャラクター・声種・性格・演出カタログを読み込んでいます…");
  try {
    state.catalog = await apiGet("/api/catalog");
    state.standaloneMode = false;
    state.voicePool = state.catalog.voice_pool || null;
    if (state.sessionToken) {
      const me = await apiGet("/api/auth/me").catch(() => null);
      if (me && me.user) {
        state.user = me.user;
        state.catalog.monthly_purchase_counts = me.monthly_purchase_counts || {};
      } else {
        state.sessionToken = "";
      }
    }
  } catch (_err) {
    // 外部サーバー未接続環境（GitHub単体ダウンロード実行時等）では内蔵スタンドアロンエンジンへ自動切替
    state.standaloneMode = true;
    state.catalog = await localGet("/local/standalone_api/catalog");
    state.voicePool = state.catalog.voice_pool || null;
    el("auth-status-msg").textContent = "単体起動モードで動作中です。「⚡ APIキー・単体モードで始める」または「📂 セーブデータを読み込む」からすぐに遊べます。";
  }

  setupResumeBanner(cfg);
  showScreen("screen-auth");
}

// ローカル素材フォルダ設定イベント
el("btn-browse-assets").onclick = async () => {
  const res = await localPost("/local/assets/pick_folder", { prompt: "立ち絵・背景・効果音が配置された親フォルダを選択" });
  if (res.ok && res.path) {
    el("input-assets-root").value = res.path;
    await applyLocalAssetsConfig();
  }
};

async function applyLocalAssetsConfig() {
  const root = el("input-assets-root").value.trim();
  const pOv = el("input-portraits-override").value.trim();
  const bOv = el("input-bgs-override").value.trim();
  const seOv = el("input-se-override") ? el("input-se-override").value.trim() : "";
  await localPost("/local/config", {
    assets_root_dir: root,
    portraits_dir_override: pOv,
    backgrounds_dir_override: bOv,
    se_dir_override: seOv,
  });
  const st = await localGet("/local/assets/status?rescan=1");
  updateAssetsBadge(st);
}

el("btn-save-assets").onclick = applyLocalAssetsConfig;
el("btn-open-assets").onclick = async () => {
  await localPost("/local/assets/open_folder", { path: el("input-assets-root").value.trim() });
};

function setupResumeBanner(cfg) {
  const banner = el("resume-banner");
  const saves = cfg.saved_sessions || [];
  const pending = cfg.pending_purchase;

  if (!saves.length && !pending) {
    banner.classList.add("hidden");
    return;
  }
  banner.classList.remove("hidden");
  const parts = [];
  if (saves.length) {
    const latest = saves[0];
    const pTxt = (latest.active_personality_names || []).length ? ` / 性格:${latest.active_personality_names.join("・")}` : "";
    parts.push(`保存セーブ ${saves.length}件 — 最新: ${latest.char_name} × ${latest.player_name} (会話#${latest.latest_turn}, ♥${latest.affection}% ${latest.relationship_stage}${pTxt})`);
    el("btn-resume-save").classList.remove("hidden");
    el("btn-resume-save").onclick = () => resumeSavedSession(latest.session_id);
    el("btn-resume-all-saves").onclick = () => openSaveLoadModal(latest.session_id);
  } else {
    el("btn-resume-save").classList.add("hidden");
  }

  if (pending && pending.selectedPlan) {
    parts.push("中断された購入確認データがあります");
    el("btn-resume-purchase").classList.remove("hidden");
    el("btn-resume-purchase").onclick = () => resumePendingPurchase(pending);
  }
  el("resume-summary").textContent = parts.join(" / ");
}

// ==================== Slide 13: Google OAuth 認証 ====================

el("btn-save-server").onclick = async () => {
  const url = el("input-server-url").value.trim().replace(/\/$/, "");
  if (!url) return;
  state.serverUrl = url;
  await localPost("/local/config", { server_url: url });
  bootSequence();
};

el("btn-standalone-quick").onclick = () => {
  unlockAllAudio();
  state.aiMode = "apikey";
  showScreen("screen-name");
  el("input-player-name").focus();
};

el("btn-auth-start").onclick = async () => {
  unlockAllAudio();
  try {
    if (state.user) {
      showScreen("screen-name");
      return;
    }
    el("auth-status-msg").textContent = "ブラウザで認証画面を開いています…";
    const start = await apiPost("/api/auth/start", {});
    const targetUrl = start.dev_auth_url || start.auth_url;
    await localPost("/local/open_external", { url: targetUrl });

    const reqId = start.auth_request_id;
    for (let i = 0; i < 90; i++) {
      await new Promise((r) => setTimeout(r, 1200));
      const poll = await apiGet(`/api/auth/poll?auth_request_id=${encodeURIComponent(reqId)}`);
      if (poll.status === "COMPLETED") {
        state.sessionToken = poll.session_token;
        state.user = poll.user;
        await localPost("/local/config", { session_token: state.sessionToken });
        state.catalog = await apiGet("/api/catalog");
        showScreen("screen-name");
        return;
      }
    }
    el("auth-status-msg").textContent = "認証がタイムアウトしました。もう一度「認証開始」を押してください。";
  } catch (err) {
    el("auth-status-msg").textContent = `認証開始エラー: ${err.message}`;
  }
};

// ==================== Slide 14-16: プレイヤー名・読み方・NG検証 ====================

el("btn-name-next").onclick = () => {
  const nm = el("input-player-name").value.trim();
  if (!nm) return;
  state.playerName = nm;
  showScreen("screen-kana");
  el("input-player-kana").focus();
};

el("btn-kana-next").onclick = async () => {
  const kn = el("input-player-kana").value.trim();
  if (!kn) return;
  state.playerKana = kn;
  el("name-validation-err").textContent = "";

  showLoading("検証中…", "プレイヤー名と読み方を検証しています…");
  await new Promise((r) => setTimeout(r, 280));

  try {
    const res = await apiPost("/api/validate_player", {
      player_name: state.playerName,
      player_kana: state.playerKana,
    });
    if (!res.ok) {
      showScreen("screen-kana");
      el("name-validation-err").textContent = res.message;
      setTimeout(() => showScreen("screen-name"), 1800);
      return;
    }
    initCharSelector();
    showScreen("screen-char-select");
  } catch (err) {
    showScreen("screen-kana");
    el("name-validation-err").textContent = err.message;
  }
};

// ==================== Slide 17: キャラクターと性別選択 ====================

function initCharSelector() {
  state.catIdx = 0;
  state.charIdx = 0;
  renderCharSelector();
}

async function renderCharSelector() {
  const cats = (state.catalog && state.catalog.categories) || [];
  if (!cats.length) return;
  state.catIdx = (state.catIdx + cats.length) % cats.length;
  const curCat = cats[state.catIdx];
  const chars = curCat.characters || [];
  state.charIdx = (state.charIdx + chars.length) % chars.length;
  const ch = chars[state.charIdx];
  state.selectedChar = ch;

  el("label-category").textContent = curCat.category;
  el("label-char-name").textContent = ch.name;

  const pUrl = localPortraitUrl(ch, "normal", false);
  const imgEl = el("img-char-preview");
  const hintEl = el("char-missing-hint");
  const probe = await fetch(pUrl);
  if (probe.status === 200) {
    const isStarter = probe.headers.get("X-Starter-Fallback") === "1";
    const blob = await probe.blob();
    const prof = getCharColorProfile(ch);
    const swappedUrl = await tachieColorEngine.applyRulesToBlob(blob, `prev_${ch.char_id}`, prof);
    imgEl.src = swappedUrl || setTrackedBlobUrl("preview", blob);
    imgEl.style.filter = tachieColorEngine.buildCssFilter(prof, "day");
    imgEl.classList.remove("hidden");
    hintEl.classList.toggle("hidden", !isStarter);
  } else {
    setTrackedBlobUrl("preview", null);
    imgEl.classList.add("hidden");
    hintEl.classList.remove("hidden");
  }

  el("btn-gender-m").classList.toggle("active", state.playerGender === "M");
  el("btn-gender-w").classList.toggle("active", state.playerGender === "W");
}

el("btn-cat-prev").onclick = () => { state.catIdx--; state.charIdx = 0; renderCharSelector(); };
el("btn-cat-next").onclick = () => { state.catIdx++; state.charIdx = 0; renderCharSelector(); };
el("btn-char-prev").onclick = () => { state.charIdx--; renderCharSelector(); };
el("btn-char-next").onclick = () => { state.charIdx++; renderCharSelector(); };
el("btn-gender-m").onclick = () => { state.playerGender = "M"; renderCharSelector(); };
el("btn-gender-w").onclick = () => { state.playerGender = "W"; renderCharSelector(); };
el("btn-char-confirm").onclick = () => { renderVoiceMeterOnAiScreen(); showScreen("screen-ai-mode"); };

window.addEventListener("keydown", (ev) => {
  if (!el("save-load-modal").classList.contains("hidden")) {
    if (ev.key === "Escape") el("save-load-modal").classList.add("hidden");
    return;
  }
  const activeTag = document.activeElement ? document.activeElement.tagName : "";
  if (activeTag === "INPUT" || activeTag === "TEXTAREA" || activeTag === "SELECT") {
    return;
  }
  if (el("screen-char-select").classList.contains("active")) {
    if (ev.key === "ArrowLeft") { state.catIdx--; state.charIdx = 0; renderCharSelector(); }
    else if (ev.key === "ArrowRight") { state.catIdx++; state.charIdx = 0; renderCharSelector(); }
    else if (ev.key === "ArrowUp") { state.charIdx--; renderCharSelector(); }
    else if (ev.key === "ArrowDown") { state.charIdx++; renderCharSelector(); }
    else if (ev.key === "m" || ev.key === "M") { state.playerGender = "M"; renderCharSelector(); }
    else if (ev.key === "w" || ev.key === "W") { state.playerGender = "W"; renderCharSelector(); }
    else if (ev.key === "Enter") { renderVoiceMeterOnAiScreen(); showScreen("screen-ai-mode"); }
  } else if (el("screen-novel").classList.contains("active")) {
    if ((ev.key === "Enter" || ev.key === " ") && !el("novel-textbox").classList.contains("hidden")) {
      ev.preventDefault();
      advanceNovelTextbox();
    }
  }
});

// ==================== Slide 18: AIの導入方法 ＆ AquesTalkボイス設定 ====================

function describeUserVoiceEntitlement(u, pool, scene = null) {
  if (!state.voiceEnabled) return "🔇 ボイスOFF (¥0)";
  const vMode = scene?.voice_engine_mode || "";
  const vSrc = scene?.voice_entitlement?.source || "";
  if (vMode.startsWith("chara_serif_maker")) return "🔊 キャラセリフメーカー連携";
  if (vSrc === "chara_serif_maker_licensed") {
    return vMode === "synth_placeholder" ? "🔊 連携済 (.so配置待ち)" : "🔊 キャラセリフメーカー連携";
  }
  if (pool?.is_goal_reached) return "🎉 今年度目標達成・無料開放中";
  if (!u) return "🔊 ボイス有効";
  const nowIso = new Date().toISOString();
  if (u.voice_pass_until && u.voice_pass_until > nowIso) return `🔊 パス有効 (${u.voice_pass_until.slice(0, 10)}迄)`;
  if ((u.voice_credits || 0) > 0) return `🔊 ボイス枠 残${u.voice_credits}回`;
  if ((u.voice_trial_left || 0) > 0) return `🔊 無料お試し残${u.voice_trial_left}回`;
  return "🔇 ボイス枠0 (テキスト表示)";
}

function renderVoiceMeterOnAiScreen() {
  const pool = state.voicePool || state.catalog?.voice_pool;
  const u = state.user;
  if (pool) {
    el("vm-bar-fill").style.width = `${pool.progress_pct}%`;
    el("vm-status-badge").textContent = pool.is_goal_reached
      ? "🎉 100%達成（全員無料開放中）"
      : `回収率 ${pool.progress_pct}% (¥${pool.collected_yen.toLocaleString()} / ¥${pool.target_yen.toLocaleString()})`;
    el("vm-caption").textContent = pool.is_goal_reached
      ? "今年度のAquesTalk1ライセンス実費は100%回収完了したため、次期更新まで全プレイヤー無料でフルボイスを利用できます（利益0円）。"
      : `AquesTalk1ライセンス実費（初年度税込¥157,300 / 次年度以降¥107,800）の分担メーターです。100%到達後は自動で徴収停止・全員無料開放されます。現在状態: ${describeUserVoiceEntitlement(u, pool)}`;
  }

  const sel = el("select-initial-voice-plan");
  sel.innerHTML = "";
  const optNone = document.createElement("option");
  optNone.value = "";
  optNone.textContent = pool?.is_goal_reached ? "購入不要（全員無料開放中）" : "今は追加しない（無料お試し枠／保有済み枠で開始）";
  sel.appendChild(optNone);

  if (!pool?.is_goal_reached) {
    (state.catalog?.voice_plans || []).forEach((vp) => {
      const opt = document.createElement("option");
      opt.value = vp.id;
      opt.textContent = `${vp.label} — ${vp.desc}`;
      sel.appendChild(opt);
    });
  }
  sel.disabled = !state.voiceEnabled || Boolean(pool?.is_goal_reached);
}

el("chk-voice-enabled").onchange = async (e) => {
  state.voiceEnabled = e.target.checked;
  el("chk-hud-voice-enabled").checked = state.voiceEnabled;
  await localPost("/local/config", { voice_enabled: state.voiceEnabled });
  renderVoiceMeterOnAiScreen();
};

function _resolveSelectedVoicePlanObj() {
  if (!state.voiceEnabled) return null;
  const vid = el("select-initial-voice-plan").value;
  if (!vid) return null;
  return (state.catalog?.voice_plans || []).find((v) => v.id === vid) || null;
}

el("btn-mode-purchase").onclick = async () => {
  unlockAllAudio();
  state.aiMode = "purchase";
  state.selectedVoicePlan = _resolveSelectedVoicePlanObj();
  if (state.user && state.user.prompt_balance > 0 && !state.selectedVoicePlan) {
    startNewNovelSession();
    return;
  }
  state.planPage = 1;
  renderPromptPlans();
  showScreen("screen-prompt-plan");
};

el("btn-mode-apikey").onclick = () => {
  state.aiMode = "apikey";
  el("apikey-panel").classList.remove("hidden");
  el("input-gemini-key").focus();
};

el("btn-apikey-start").onclick = async () => {
  unlockAllAudio();
  state.aiMode = "apikey";
  state.userGeminiKey = el("input-gemini-key").value.trim();
  state.autoBgGeneration = el("chk-auto-bg-gen") ? el("chk-auto-bg-gen").checked : true;
  state.selectedVoicePlan = _resolveSelectedVoicePlanObj();
  await localPost("/local/config", {
    user_gemini_api_key: state.userGeminiKey,
    auto_bg_generation: state.autoBgGeneration,
  });

  if (state.selectedVoicePlan) {
    const curDep = state.user ? state.user.deposit_yen : 0;
    if (curDep >= state.selectedVoicePlan.price_yen) {
      try {
        const vRes = await apiPost("/api/billing/purchase_voice_plan", { voice_plan_id: state.selectedVoicePlan.id });
        state.user = vRes.user;
        state.voicePool = vRes.voice_pool;
        state.selectedVoicePlan = null;
      } catch (err) {
        alert(err.message);
        return;
      }
    } else {
      state.selectedPlan = null;
      state.selectedAutoCharge = { id: "none", prompts: 0, price_yen: 0, label: "オートチャージなし" };
      renderDepositOptions();
      showScreen("screen-deposit");
      return;
    }
  }
  startNewNovelSession();
};

// ==================== Slide 19-24: プロンプト購入・決済フロー ====================

function renderPromptPlans() {
  const plans = (state.catalog?.prompt_plans || []).filter((p) => p.page === state.planPage);
  const counts = state.catalog?.monthly_purchase_counts || {};
  const listEl = el("prompt-plan-list");
  listEl.innerHTML = "";

  plans.forEach((p) => {
    const used = counts[p.id] || 0;
    const reachedLimit = p.monthly_limit !== null && used >= p.monthly_limit;
    const btn = document.createElement("button");
    btn.className = "action-btn";
    btn.disabled = reachedLimit;
    btn.textContent = `${p.prompts.toLocaleString()}prompt : ¥${p.price_yen.toLocaleString()}${reachedLimit ? " (今月上限)" : ""}`;
    btn.title = p.tagline;
    btn.onclick = () => {
      state.selectedPlan = p;
      renderAutoChargePlans();
      showScreen("screen-autocharge");
    };
    listEl.appendChild(btn);
  });

  el("label-plan-page").textContent = `${state.planPage} / 3`;
}

el("btn-plan-prev").onclick = () => { state.planPage = state.planPage > 1 ? state.planPage - 1 : 3; renderPromptPlans(); };
el("btn-plan-next").onclick = () => { state.planPage = state.planPage < 3 ? state.planPage + 1 : 1; renderPromptPlans(); };
el("btn-plan-back").onclick = () => showScreen("screen-ai-mode");

function renderAutoChargePlans() {
  const listEl = el("autocharge-list");
  listEl.innerHTML = "";
  (state.catalog?.auto_charge_plans || []).forEach((ac) => {
    const btn = document.createElement("button");
    btn.className = "action-btn";
    btn.textContent = ac.label;
    btn.onclick = () => {
      state.selectedAutoCharge = ac;
      renderDepositOptions();
      showScreen("screen-deposit");
    };
    listEl.appendChild(btn);
  });
}

el("btn-ac-back").onclick = () => showScreen("screen-prompt-plan");

function renderDepositOptions() {
  const listEl = el("deposit-list");
  listEl.innerHTML = "";
  const neededPrompt = state.selectedPlan ? state.selectedPlan.price_yen : 0;
  const neededVoice = state.selectedVoicePlan ? state.selectedVoicePlan.price_yen : 0;
  const needed = neededPrompt + neededVoice;
  const curDep = state.user ? state.user.deposit_yen : 0;

  (state.catalog?.deposit_options || []).forEach((dep) => {
    const btn = document.createElement("button");
    btn.className = "action-btn";
    const enough = (curDep + dep.net_yen) >= needed;
    btn.disabled = !enough;
    btn.textContent = `${dep.gross_yen}円`;
    btn.title = `手数料差引後の追加残高: ¥${dep.net_yen.toLocaleString()}`;
    btn.onclick = () => {
      state.selectedDeposit = dep;
      renderPurchaseConfirmation();
      showScreen("screen-confirm");
    };
    listEl.appendChild(btn);
  });
}

el("btn-dep-back").onclick = () => showScreen(state.selectedPlan ? "screen-autocharge" : "screen-ai-mode");

function renderPurchaseConfirmation() {
  const p = state.selectedPlan;
  const vp = state.selectedVoicePlan;
  const ac = state.selectedAutoCharge || { id: "none", prompts: 0, price_yen: 0 };
  const dep = state.selectedDeposit;
  const totalPlanCost = (p ? p.price_yen : 0) + (vp ? vp.price_yen : 0);
  el("conf-prompt").textContent = p ? `プロンプト数：${p.prompts}p ¥${p.price_yen.toLocaleString()}` : "プロンプト数：購入なし（GeminiAPIキー指定）";
  el("conf-voice-plan").textContent = vp ? `AquesTalkボイス：${vp.label}` : "AquesTalkボイス：追加なし（無料お試し／既存枠）";
  el("conf-autocharge").textContent = ac.id === "none" ? "オートチャージ：なし" : `オートチャージ：${ac.prompts} ¥${ac.price_yen.toLocaleString()}`;
  el("conf-deposit").textContent = `デジポット代金：¥${dep.gross_yen.toLocaleString()}`;
  el("conf-net-note").textContent = `（決済手数料差引後の実質チャージ額: ¥${dep.net_yen.toLocaleString()} / プラン差引後残高目安: ¥${((state.user?.deposit_yen || 0) + dep.net_yen - totalPlanCost).toLocaleString()}）`;
  el("conf-err").textContent = "";
}

el("btn-conf-back").onclick = () => showScreen("screen-deposit");

function resumePendingPurchase(pending) {
  state.playerName = pending.playerName;
  state.playerKana = pending.playerKana;
  state.playerGender = pending.playerGender;
  state.selectedChar = pending.selectedChar;
  state.aiMode = pending.aiMode || "purchase";
  state.selectedPlan = pending.selectedPlan || null;
  state.selectedVoicePlan = pending.selectedVoicePlan || null;
  state.selectedAutoCharge = pending.selectedAutoCharge || { id: "none", prompts: 0, price_yen: 0 };
  state.selectedDeposit = pending.selectedDeposit;
  state.pendingOrderId = pending.pendingOrderId || "";
  renderPurchaseConfirmation();
  showScreen("screen-confirm");
}

el("btn-conf-paypal").onclick = async () => {
  el("conf-err").textContent = "";
  showLoading("セーブ中…", "購入設定データをローカルへ保存しています…");
  await new Promise((r) => setTimeout(r, 300));

  try {
    const chk = await apiPost("/api/billing/create_checkout", {
      gross_yen: state.selectedDeposit.gross_yen,
      initial_plan_id: state.selectedPlan ? state.selectedPlan.id : "",
      initial_voice_plan_id: state.selectedVoicePlan ? state.selectedVoicePlan.id : "",
      auto_charge_plan_id: state.selectedAutoCharge ? state.selectedAutoCharge.id : "none",
    });
    state.pendingOrderId = chk.order.order_id;

    await localPost("/local/config", {
      pending_purchase: {
        playerName: state.playerName,
        playerKana: state.playerKana,
        playerGender: state.playerGender,
        selectedChar: state.selectedChar,
        aiMode: state.aiMode,
        selectedPlan: state.selectedPlan,
        selectedVoicePlan: state.selectedVoicePlan,
        selectedAutoCharge: state.selectedAutoCharge,
        selectedDeposit: state.selectedDeposit,
        pendingOrderId: state.pendingOrderId,
      },
    });

    await localPost("/local/open_external", { url: chk.order.approve_url });

    showLoading("支払いを確認中…", "PayPalでの支払い完了を待機しています…");
    for (let i = 0; i < 75; i++) {
      await new Promise((r) => setTimeout(r, 1500));
      try {
        const ver = await apiPost("/api/billing/verify_order", { order_id: state.pendingOrderId });
        if (ver.ok) {
          state.user = ver.user;
          if (ver.voice_pool) state.voicePool = ver.voice_pool;
          state.selectedVoicePlan = null;
          await localPost("/local/config", { pending_purchase: null });
          await startNewNovelSession();
          return;
        }
      } catch (_waitErr) {}
    }
    showScreen("screen-confirm");
    el("conf-err").textContent = "支払いの完了が確認できませんでした。やり直す場合はもう一度ボタンを押してください。";
  } catch (err) {
    showScreen("screen-confirm");
    el("conf-err").textContent = err.message;
  }
};

// ==================== Slide 25-32: 会話本編・プレゼン演出・SE再生・性格動的シフト ====================

async function applySceneVisualsFromLocalPC(scene) {
  const bgUrl = localBackgroundUrl(scene.background);
  const bgResp = await fetch(bgUrl);
  if (bgResp.status === 200) {
    const bgBlob = await bgResp.blob();
    el("novel-bg").style.backgroundImage = `url("${setTrackedBlobUrl("bg", bgBlob)}")`;
  } else {
    setTrackedBlobUrl("bg", null);
    el("novel-bg").style.backgroundImage = "";
  }

  const pImg = el("novel-portrait");
  const pUrl = localPortraitUrl(state.selectedChar, scene.emotion || "normal", Boolean(scene.prefer_blush));
  const pResp = await fetch(pUrl);
  if (pResp.status === 200) {
    const pBlob = await pResp.blob();
    state._lastRawPortraitBlob = pBlob;
    const prof = getCharColorProfile(state.selectedChar);
    const tod = scene.bg_time_of_day || scene.background?.time_of_day || "day";
    const swappedUrl = await tachieColorEngine.applyRulesToBlob(
      pBlob,
      `${state.selectedChar?.char_id}_${scene.emotion}_${scene.prefer_blush ? 1 : 0}`,
      prof
    );
    pImg.src = swappedUrl || setTrackedBlobUrl("portrait", pBlob);
    pImg.style.filter = tachieColorEngine.buildCssFilter(prof, tod);
    pImg.dataset.hasLocal = "1";
  } else {
    setTrackedBlobUrl("portrait", null);
    pImg.src = "";
    pImg.dataset.hasLocal = "0";
  }
}

let _toastTimer = null;
function showPersonalityToast(message) {
  const toast = el("personality-toast");
  if (!toast || !message) return;
  toast.textContent = `🎭 ${message}`;
  toast.classList.remove("hidden");
  clearTimeout(_toastTimer);
  _toastTimer = setTimeout(() => {
    toast.classList.add("hidden");
  }, 4200);
}

async function startNewNovelSession() {
  showLoading("最初の会話を読み込んでます…", `${state.selectedChar.name}との物語を準備しています…`);
  state.sessionId = `sess_${state.selectedChar.char_id}_${Date.now()}`;
  state.history = [];
  state.personalityMode = "auto";
  state.pinnedPersonalityIds = [];
  state.customPersonalityNote = "";

  try {
    if (state.selectedVoicePlan && state.user && state.user.deposit_yen >= state.selectedVoicePlan.price_yen) {
      const vpRes = await apiPost("/api/billing/purchase_voice_plan", { voice_plan_id: state.selectedVoicePlan.id });
      state.user = vpRes.user;
      state.voicePool = vpRes.voice_pool;
      state.selectedVoicePlan = null;
    }

    const res = await apiPost("/api/game/start", {
      char_id: state.selectedChar.char_id,
      player_name: state.playerName,
      player_kana: state.playerKana,
      player_gender: state.playerGender,
      ai_mode: state.aiMode,
      voice_enabled: state.voiceEnabled,
      user_gemini_api_key: state.userGeminiKey,
      available_backgrounds: state.localAssets?.backgrounds || [],
      available_sound_effects: state.localAssets?.sound_effects || [],
    });
    if (res.user) state.user = res.user;
    if (res.voice_pool) state.voicePool = res.voice_pool;
    await presentScene(res.scene, null, true);
  } catch (err) {
    alert(`会話開始エラー: ${err.message}`);
    showScreen("screen-ai-mode");
  }
}

function refreshHudPills(scene) {
  if (scene) {
    el("hud-char-stage").textContent = `${scene.relationship_stage} (♥ ${scene.affection}%)`;
    const pNames = scene.active_personality_names || [];
    const modeIcon = state.personalityMode === "locked" ? "🔒" : (state.personalityMode === "hybrid" ? "📌" : "🔄");
    el("hud-personality").textContent = pNames.length
      ? `${modeIcon} ${pNames.join("・")}`
      : `${modeIcon} 原作準拠`;
  }
  el("hud-voice-status").textContent = describeUserVoiceEntitlement(state.user, state.voicePool, scene);
  if (state.aiMode === "purchase" && state.user) {
    el("hud-balance").textContent = `残 ${state.user.prompt_balance}p / ¥${state.user.deposit_yen.toLocaleString()}`;
  } else if (state.user) {
    el("hud-balance").textContent = `APIキー指定 (¥${state.user.deposit_yen.toLocaleString()})`;
  } else {
    el("hud-balance").textContent = state.userGeminiKey ? "Gemini APIキー指定" : "ローカルデモモード";
  }
}

async function presentScene(scene, playerChoiceMade, startWithNarration = false) {
  state.currentScene = scene;
  state.currentAudioB64 = scene.audio_wav_base64 || "";
  setAudioBlobFromBase64(state.currentAudioB64);

  await applySceneVisualsFromLocalPC(scene);
  refreshHudPills(scene);

  if (scene.personality_changed && scene.personality_shift_reason) {
    showPersonalityToast(scene.personality_shift_reason);
  }

  await localPost("/local/save_turn", {
    session_id: state.sessionId,
    turn_index: scene.turn_index,
    player_choice: playerChoiceMade || "",
    setup: {
      char_id: state.selectedChar.char_id,
      player_name: state.playerName,
      player_kana: state.playerKana,
      player_gender: state.playerGender,
      ai_mode: state.aiMode,
    },
    scene: { ...scene, audio_wav_base64: undefined },
    audio_wav_base64: state.currentAudioB64,
  });

  state.history.push({
    turn_index: scene.turn_index,
    player_choice: playerChoiceMade || "",
    narration: scene.narration,
    dialogue: scene.dialogue,
    personality_names: scene.active_personality_names || [],
  });

  el("wedding-banner").classList.add("hidden");
  showScreen("screen-novel");

  stagePresenter.setDirection(scene.stage_direction);

  const pImg = el("novel-portrait");
  const hasPortrait = pImg.dataset.hasLocal === "1";

  if (scene.narration && (startWithNarration || scene.narration.length > 0)) {
    state.subStep = "narration";
    if (hasPortrait) pImg.classList.remove("hidden");
    else pImg.classList.add("hidden");
    stagePresenter.applyStep("narration", true);
    renderTextbox(scene.narration, false);
  } else {
    state.subStep = "dialogue";
    if (hasPortrait) pImg.classList.remove("hidden");
    stagePresenter.applyStep("dialogue", true);
    renderTextbox(scene.dialogue, true);
    playCurrentVoice();
  }
}

function renderTextbox(text, isDialogue) {
  el("novel-choices-wrap").classList.add("hidden");
  const box = el("novel-textbox");
  const txt = el("novel-text-content");
  box.classList.remove("hidden");
  txt.textContent = text;
  txt.classList.toggle("is-narration", !isDialogue);
  txt.classList.toggle("is-dialogue", isDialogue);
}

function advanceNovelTextbox() {
  unlockAllAudio();
  const sc = state.currentScene;
  if (!sc) return;

  if (state.subStep === "narration") {
    state.subStep = "dialogue";
    if (el("novel-portrait").dataset.hasLocal === "1") {
      el("novel-portrait").classList.remove("hidden");
    }
    stagePresenter.applyStep("dialogue", true);
    renderTextbox(sc.dialogue, true);
    playCurrentVoice();
    return;
  }

  if (state.subStep === "dialogue") {
    if (sc.is_wedding_goal) {
      el("wedding-msg").textContent = `${sc.speaker_name}と${state.playerName}は幻想郷で結婚式を挙げ、永遠の絆を結びました！`;
      el("wedding-banner").classList.remove("hidden");
      return;
    }
    state.subStep = "choices";
    el("novel-textbox").classList.add("hidden");
    renderChoices(sc.choices || []);
  }
}

el("novel-textbox").onclick = advanceNovelTextbox;

function renderChoices(choices) {
  const wrapOuter = el("novel-choices-wrap");
  const wrap = el("novel-choices");
  wrap.innerHTML = "";
  choices.forEach((chText) => {
    const btn = document.createElement("button");
    btn.className = "choice-btn";
    btn.textContent = chText;
    btn.onclick = () => selectChoice(chText, false);
    wrap.appendChild(btn);
  });

  // 自由入力バーは Gemini API キー利用モード時のみ受付・表示
  const freeForm = el("free-talk-form");
  if (isApiKeyFreeInputAllowed()) {
    freeForm.classList.remove("hidden");
    el("input-free-talk").value = "";
    el("input-free-talk").disabled = false;
    el("btn-free-talk-send").disabled = false;
  } else {
    freeForm.classList.add("hidden");
    el("input-free-talk").value = "";
  }
  wrapOuter.classList.remove("hidden");
}

el("free-talk-form").onsubmit = (ev) => {
  ev.preventDefault();
  if (!isApiKeyFreeInputAllowed()) {
    alert("自由入力での会話は、Gemini APIキーを指定して利用している場合のみ使用できます。");
    return;
  }
  const txt = el("input-free-talk").value.trim();
  if (!txt) return;
  selectChoice(txt, true);
};

async function selectChoice(choiceText, isFreeInput = false) {
  unlockAllAudio();
  if (isFreeInput && !isApiKeyFreeInputAllowed()) {
    alert("自由入力での会話は、Gemini APIキーを指定して利用している場合のみ使用できます。");
    return;
  }
  const sc = state.currentScene;
  document.querySelectorAll(".choice-btn").forEach((b) => (b.disabled = true));
  el("btn-free-talk-send").disabled = true;

  try {
    const res = await apiPost("/api/game/turn", {
      char_id: state.selectedChar.char_id,
      player_name: state.playerName,
      player_kana: state.playerKana,
      player_gender: state.playerGender,
      turn_index: sc.turn_index + 1,
      selected_choice: choiceText,
      is_free_input: Boolean(isFreeInput),
      history: state.history,
      current_affection: sc.affection,
      active_personality_ids: sc.active_personality_ids || [],
      personality_mode: state.personalityMode,
      pinned_personality_ids: state.pinnedPersonalityIds,
      custom_personality_note: state.customPersonalityNote,
      current_bg_id: sc.background ? sc.background.bg_id : "",
      allow_paid_bg_generation: false,
      auto_bg_generation: state.autoBgGeneration,
      ai_mode: state.aiMode,
      voice_enabled: state.voiceEnabled,
      user_gemini_api_key: state.userGeminiKey,
      available_backgrounds: state.localAssets?.backgrounds || [],
      available_sound_effects: state.localAssets?.sound_effects || [],
    });
    if (res.user) state.user = res.user;
    if (res.voice_pool) state.voicePool = res.voice_pool;
    if (res.scene.generated_bg_webp_base64) {
      const saved = await localPost("/local/assets/save_generated_bg", {
        bg_id: res.scene.background.bg_id,
        name: res.scene.background.name,
        ext: res.scene.background.ext || "webp",
        image_webp_base64: res.scene.generated_bg_webp_base64,
      });
      if (saved.background) res.scene.background = saved.background;
      const st = await localGet("/local/assets/status");
      updateAssetsBadge(st);
    }
    await presentScene(res.scene, choiceText, Boolean(res.scene.narration));
  } catch (err) {
    alert(`進行エラー: ${err.message}`);
    document.querySelectorAll(".choice-btn").forEach((b) => (b.disabled = false));
    el("btn-free-talk-send").disabled = false;
  }
}

function setAudioBlobFromBase64(b64) {
  if (!b64) {
    setTrackedBlobUrl("audio", null);
    state.currentAudioUrl = "";
    return;
  }
  try {
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    const blob = new Blob([bytes], { type: "audio/wav" });
    state.currentAudioUrl = setTrackedBlobUrl("audio", blob);
  } catch (_e) {
    state.currentAudioUrl = `data:audio/wav;base64,${b64}`;
  }
}

function unlockAllAudio() {
  stageSound.unlock();
  if (state.audioUnlocked) return;
  const player = el("voice-player");
  if (!player) return;
  state.audioUnlocked = true;
  try {
    player.muted = true;
    player.src = "data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=";
    const p = player.play();
    if (p && typeof p.then === "function") {
      p.then(() => { player.pause(); player.muted = false; }).catch(() => { player.muted = false; });
    } else {
      player.muted = false;
    }
  } catch (_e) {
    player.muted = false;
  }
}

function playCurrentVoice(customUrl = "") {
  if (!state.voiceEnabled && !customUrl) return;
  const player = el("voice-player");
  const pImg = el("novel-portrait");
  if (customUrl) state.currentAudioUrl = customUrl;
  const src = customUrl || state.currentAudioUrl || (state.currentAudioB64 ? `data:audio/wav;base64,${state.currentAudioB64}` : "");
  if (!src) return;
  try {
    player.pause();
    player.currentTime = 0;
  } catch (_e) {}
  player.muted = false;
  player.volume = 1.0;
  player.src = src;
  pImg.classList.add("speaking");
  player.onended = () => pImg.classList.remove("speaking");
  player.onerror = () => pImg.classList.remove("speaking");
  player.play().catch(() => pImg.classList.remove("speaking"));
}

el("btn-replay-voice").onclick = () => {
  unlockAllAudio();
  if (state.currentScene) {
    stagePresenter.setDirection(state.currentScene.stage_direction);
    stagePresenter.applyStep("dialogue", true);
  }
  playCurrentVoice();
};

el("btn-toggle-se").onclick = async () => {
  unlockAllAudio();
  state.seEnabled = !state.seEnabled;
  updateSeHudButton();
  await localPost("/local/config", { se_enabled: state.seEnabled });
};

el("btn-open-stage-studio").onclick = async () => {
  await localPost("/local/open_stage_studio", {});
};

el("btn-wedding-restart").onclick = () => bootSequence();

// 会話内容に忠実なAI新規オリジナル背景生成
el("btn-new-bg").onclick = async () => {
  const sc = state.currentScene || {};
  const suggestedTitle = sc.background?.keyword || sc.background?.name || "幻想郷の情景";
  const defaultDesc = sc.suggest_new_bg_prompt
    ? `${suggestedTitle} (${sc.suggest_new_bg_prompt.slice(0, 70)})`
    : suggestedTitle;
  const title = prompt(
    "現在の会話内容に合わせて生成したい背景シーンを入力してください（空欄以外のそのままOKで現在の会話場面を忠実にAI生成します）:",
    defaultDesc
  );
  if (!title) return;
  try {
    const tod = sc.bg_time_of_day || sc.background?.time_of_day || "day";
    const res = await apiPost("/api/game/generate_background", {
      scene_title: suggestedTitle,
      prompt_en: sc.suggest_new_bg_prompt && title === defaultDesc ? sc.suggest_new_bg_prompt : title,
      time_of_day: tod === "any" ? "day" : tod,
      dialogue_context: `${sc.narration || ""} ${sc.dialogue || ""}`.trim(),
      ai_mode: state.aiMode,
      user_gemini_api_key: state.userGeminiKey,
    });
    if (res.user) {
      state.user = res.user;
      refreshHudPills(state.currentScene);
    }
    if (res.background && res.image_webp_base64) {
      const saved = await localPost("/local/assets/save_generated_bg", {
        bg_id: res.background.bg_id,
        name: res.background.name,
        ext: res.background.ext || "webp",
        image_webp_base64: res.image_webp_base64,
      });
      const bgMeta = saved.background || res.background;
      state.currentScene.background = bgMeta;
      const st = await localGet("/local/assets/status");
      updateAssetsBadge(st);
      await applySceneVisualsFromLocalPC(state.currentScene);
    }
  } catch (err) {
    alert(err.message);
  }
};

// ==================== 🎭 会話連動＆手動 性格変更ドロワー ====================

function getPersonalitiesCatalogList() {
  return (state.catalog && state.catalog.personalities) || [];
}

function renderPersonalityDrawer() {
  const allP = getPersonalitiesCatalogList();
  const q = (el("input-pers-search").value || "").trim().toLowerCase();

  document.querySelectorAll('input[name="pers-mode"]').forEach((r) => {
    r.checked = r.value === state.personalityMode;
  });
  el("input-custom-pers-note").value = state.customPersonalityNote || "";

  const activeIds = state.personalityMode === "auto"
    ? (state.currentScene?.active_personality_ids || [])
    : state.pinnedPersonalityIds;

  const selectedNames = activeIds
    .map((id) => allP.find((p) => p.id === id)?.name)
    .filter(Boolean);
  const modeLbl = state.personalityMode === "locked" ? "手動固定" : (state.personalityMode === "hybrid" ? "1つ目固定＋会話連動" : "会話連動で自動変化");
  el("pers-selected-bar").textContent = `モード: ${modeLbl} ／ 適用中: ${selectedNames.length ? selectedNames.join("・") : "原作準拠"}`;

  const wrap = el("personality-chip-list");
  wrap.innerHTML = "";
  allP
    .filter((p) => !q || p.name.toLowerCase().includes(q) || (p.kana || "").includes(q) || (p.category || "").toLowerCase().includes(q))
    .forEach((p) => {
      const btn = document.createElement("button");
      const isSel = activeIds.includes(p.id);
      btn.className = `pers-chip${isSel ? " selected" : ""}`;
      btn.innerHTML = `<div>${p.id}. ${p.name}</div><div style="font-size:10px;opacity:.75">${p.category || ""}</div>`;
      btn.title = p.description || p.behavior_pattern || "";
      btn.onclick = () => togglePersonalityChip(p);
      wrap.appendChild(btn);
    });
}

async function togglePersonalityChip(pObj) {
  unlockAllAudio();
  stageSound.playSe("sparkle_twinkle", 0.55);
  let ids = state.personalityMode === "auto"
    ? [...(state.currentScene?.active_personality_ids || [])]
    : [...state.pinnedPersonalityIds];

  if (ids.includes(pObj.id)) {
    ids = ids.filter((x) => x !== pObj.id);
  } else {
    if (ids.length >= 2) ids.shift();
    ids.push(pObj.id);
  }

  // チップを手動クリックした際、autoモードならその性格を初期ベースとしてセットし、hybrid/lockedならピン留めリストも更新
  state.pinnedPersonalityIds = [...ids];
  const allP = getPersonalitiesCatalogList();
  const names = ids.map((id) => allP.find((x) => x.id === id)?.name).filter(Boolean);

  if (state.currentScene) {
    state.currentScene.active_personality_ids = ids;
    state.currentScene.active_personality_names = names;
    refreshHudPills(state.currentScene);
    await persistCurrentPersonalityToSave();
  }
  renderPersonalityDrawer();
}

async function persistCurrentPersonalityToSave() {
  if (!state.sessionId || !state.currentScene) return;
  await localPost("/local/saves/update_personality", {
    session_id: state.sessionId,
    turn_index: state.currentScene.turn_index,
    active_personality_ids: state.currentScene.active_personality_ids || [],
    active_personality_names: state.currentScene.active_personality_names || [],
    personality_mode: state.personalityMode,
    pinned_personality_ids: state.pinnedPersonalityIds,
    custom_personality_note: state.customPersonalityNote,
  });
}

document.querySelectorAll('input[name="pers-mode"]').forEach((radio) => {
  radio.onchange = async (e) => {
    state.personalityMode = e.target.value;
    if (state.personalityMode !== "auto" && !state.pinnedPersonalityIds.length && state.currentScene?.active_personality_ids?.length) {
      state.pinnedPersonalityIds = [...state.currentScene.active_personality_ids];
    }
    refreshHudPills(state.currentScene);
    renderPersonalityDrawer();
    await persistCurrentPersonalityToSave();
  };
});

el("input-custom-pers-note").onchange = async (e) => {
  state.customPersonalityNote = e.target.value.trim();
  await persistCurrentPersonalityToSave();
};
el("input-pers-search").oninput = () => renderPersonalityDrawer();

el("btn-open-personality").onclick = () => {
  const dr = el("personality-drawer");
  dr.classList.toggle("hidden");
  if (!dr.classList.contains("hidden")) {
    el("voice-drawer").classList.add("hidden");
    renderPersonalityDrawer();
  }
};
el("btn-close-personality").onclick = () => el("personality-drawer").classList.add("hidden");

// ==================== 📂 全画面共通 セーブデータ読込・管理モーダル ====================

async function openSaveLoadModal(preselectSessionId = "") {
  unlockAllAudio();
  const modal = el("save-load-modal");
  modal.classList.remove("hidden");
  const data = await localGet("/local/saves");
  const sessions = data.sessions || [];
  const targetSid = preselectSessionId || state.sessionId || (sessions[0] ? sessions[0].session_id : "");
  renderSaveSessionsList(sessions, targetSid);
}

function renderSaveSessionsList(sessions, selectSid = "") {
  const listEl = el("save-sessions-list");
  listEl.innerHTML = "";
  if (!sessions.length) {
    listEl.innerHTML = `<div class="save-item" style="cursor:default;opacity:.8">保存されたセーブデータはまだありません。「外部セーブ読込」から .zip / .json をインポートすることも可能です。</div>`;
    el("save-turns-heading").textContent = "会話ターン詳細";
    el("save-turns-detail-list").innerHTML = "";
    return;
  }

  sessions.forEach((s) => {
    const div = document.createElement("div");
    div.className = `save-item${s.session_id === selectSid ? " save-card-active" : ""}`;
    const pTxt = (s.active_personality_names || []).length ? ` / 🎭 ${s.active_personality_names.join("・")}` : "";
    const dt = (s.updated_at || "").replace("T", " ").slice(0, 16);
    div.innerHTML = `
      <div><strong>${s.char_name || s.char_id}</strong> × プレイヤー: <strong>${s.player_name}</strong></div>
      <div style="font-size:12px;color:#93c5fd;margin-top:2px">会話 #${s.latest_turn} (${s.turn_count || s.latest_turn + 1}ターン) ・ ♥${s.affection}% (${s.relationship_stage})${pTxt}</div>
      ${s.preview_dialogue ? `<div style="font-size:11px;opacity:.82;margin-top:3px">${s.preview_dialogue}</div>` : ""}
      <div style="font-size:11px;opacity:.65;margin-top:2px">保存日時: ${dt}</div>
      <div class="save-item-actions">
        <button class="save-mini-btn" data-act="resume">▶ 最新から再開</button>
        <button class="save-mini-btn alt" data-act="inspect">📜 ターン一覧・巻き戻し</button>
        <button class="save-mini-btn alt" data-act="export">📦 ZIP書出</button>
        <button class="save-mini-btn danger" data-act="delete">🗑 削除</button>
      </div>
    `;

    div.querySelector('[data-act="resume"]').onclick = async (ev) => {
      ev.stopPropagation();
      el("save-load-modal").classList.add("hidden");
      await resumeSavedSession(s.session_id);
    };
    div.querySelector('[data-act="inspect"]').onclick = (ev) => {
      ev.stopPropagation();
      inspectSessionTurns(s.session_id, s.char_name);
      document.querySelectorAll("#save-sessions-list .save-item").forEach((x) => x.classList.remove("save-card-active"));
      div.classList.add("save-card-active");
    };
    div.querySelector('[data-act="export"]').onclick = (ev) => {
      ev.stopPropagation();
      window.open(`/local/saves/export?session_id=${encodeURIComponent(s.session_id)}`, "_blank");
    };
    div.querySelector('[data-act="delete"]').onclick = async (ev) => {
      ev.stopPropagation();
      if (!confirm(`「${s.char_name} × ${s.player_name} (会話#${s.latest_turn})」のセーブデータを削除しますか？`)) return;
      const res = await localPost("/local/saves/delete", { session_id: s.session_id });
      renderSaveSessionsList(res.sessions || [], "");
    };
    div.onclick = () => {
      inspectSessionTurns(s.session_id, s.char_name);
      document.querySelectorAll("#save-sessions-list .save-item").forEach((x) => x.classList.remove("save-card-active"));
      div.classList.add("save-card-active");
    };
    listEl.appendChild(div);
  });

  if (selectSid) {
    const found = sessions.find((x) => x.session_id === selectSid) || sessions[0];
    if (found) inspectSessionTurns(found.session_id, found.char_name);
  }
}

async function inspectSessionTurns(sessionId, charName = "") {
  state.inspectingSaveId = sessionId;
  el("save-turns-heading").textContent = `📜 ${charName || sessionId} の全ターン履歴`;
  const data = await localGet(`/local/saves?session_id=${encodeURIComponent(sessionId)}`);
  const turns = data.turns || [];
  const wrap = el("save-turns-detail-list");
  wrap.innerHTML = "";

  turns.slice().reverse().forEach((t, revIdx) => {
    const isLatest = revIdx === 0;
    const sc = t.scene || {};
    const sd = sc.stage_direction || {};
    const pNames = (sc.active_personality_names || []).join("・");
    const div = document.createElement("div");
    div.className = "save-item";
    div.innerHTML = `
      <div><strong>会話 #${t.turn_index}</strong> (♥${sc.affection}% / ${sc.relationship_stage}${pNames ? ` / 🎭${pNames}` : ""}) <span style="font-size:11px;color:#38bdf8">🎬${Math.round((sd.dialogue_scale || 1) * 100)}%</span></div>
      ${t.player_choice ? `<div style="font-size:11px;color:#fde047;margin:2px 0">あなた: ${t.player_choice}</div>` : ""}
      <div style="margin-top:2px">${sc.dialogue || ""}</div>
      <div class="save-item-actions">
        <button class="save-mini-btn" data-tact="load">${isLatest ? "▶ この最新ターンから再開" : "⏪ ここまで巻き戻して再開"}</button>
        ${!isLatest ? `<button class="save-mini-btn alt" data-tact="branch">🌿 別セーブに分岐して再開</button>` : ""}
        ${t.saved_wav_file ? `<button class="save-mini-btn alt" data-tact="voice">🔊 ボイス試聴</button>` : ""}
      </div>
    `;
    div.querySelector('[data-tact="load"]').onclick = async (ev) => {
      ev.stopPropagation();
      if (!isLatest && !confirm(`会話 #${t.turn_index} 以降のターンを巻き戻して、ここからやり直しますか？（元の履歴を残したい場合は「別セーブに分岐して再開」を選べます）`)) return;
      const rw = await localPost("/local/saves/rewind", { session_id: sessionId, turn_index: t.turn_index, branch: false });
      el("save-load-modal").classList.add("hidden");
      await restoreSessionFromTurns(rw.session_id, rw.turns || []);
    };
    const brBtn = div.querySelector('[data-tact="branch"]');
    if (brBtn) {
      brBtn.onclick = async (ev) => {
        ev.stopPropagation();
        const rw = await localPost("/local/saves/rewind", { session_id: sessionId, turn_index: t.turn_index, branch: true });
        el("save-load-modal").classList.add("hidden");
        await restoreSessionFromTurns(rw.session_id, rw.turns || []);
      };
    }
    const vBtn = div.querySelector('[data-tact="voice"]');
    if (vBtn) {
      vBtn.onclick = (ev) => {
        ev.stopPropagation();
        playCurrentVoice(`/local/save_audio?session_id=${encodeURIComponent(sessionId)}&file=${encodeURIComponent(t.saved_wav_file)}`);
      };
    }
    wrap.appendChild(div);
  });
}

el("input-import-save-file").onchange = (ev) => {
  const file = ev.target.files && ev.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = async () => {
    try {
      const b64 = String(reader.result || "").split(",")[1] || "";
      const res = await localPost("/local/saves/import", { filename: file.name, data_base64: b64 });
      if (!res.ok) throw new Error(res.error || "インポート失敗");
      renderSaveSessionsList(res.sessions || [], res.meta?.session_id || "");
      alert(`セーブデータ「${res.meta?.char_name || file.name}」を読み込みました！`);
    } catch (err) {
      alert(`セーブ読込エラー: ${err.message}`);
    } finally {
      ev.target.value = "";
    }
  };
  reader.readAsDataURL(file);
};

el("btn-open-load-modal-auth").onclick = () => openSaveLoadModal();
el("btn-open-load-modal-char").onclick = () => openSaveLoadModal();
el("btn-open-saves").onclick = () => openSaveLoadModal(state.sessionId);
el("btn-close-save-modal").onclick = () => el("save-load-modal").classList.add("hidden");

async function resumeSavedSession(sessionId) {
  unlockAllAudio();
  const data = await localGet(`/local/saves?session_id=${encodeURIComponent(sessionId)}`);
  await restoreSessionFromTurns(sessionId, data.turns || []);
}

async function restoreSessionFromTurns(sessionId, turns) {
  if (!turns.length) return;
  const last = turns[turns.length - 1];
  state.sessionId = sessionId;
  state.playerName = last.setup?.player_name || "プレイヤー";
  state.playerKana = last.setup?.player_kana || "ぷれいやー";
  state.playerGender = last.setup?.player_gender || "M";
  state.aiMode = last.setup?.ai_mode || "apikey";

  let foundChar = null;
  for (const cat of state.catalog?.categories || []) {
    const c = cat.characters.find((x) => x.char_id === last.setup?.char_id);
    if (c) { foundChar = c; break; }
  }
  state.selectedChar = foundChar || {
    char_id: last.setup?.char_id || "reimu",
    name: last.scene?.speaker_name || "博麗霊夢",
    aliases: [last.scene?.speaker_name || "博麗霊夢"],
  };

  state.personalityMode = last.scene?.personality_mode || "auto";
  state.pinnedPersonalityIds = last.scene?.pinned_personality_ids || [];
  state.customPersonalityNote = last.scene?.custom_personality_note || "";

  state.history = turns.map((t) => ({
    turn_index: t.turn_index,
    player_choice: t.player_choice || "",
    narration: t.scene?.narration || "",
    dialogue: t.scene?.dialogue || "",
    personality_names: t.scene?.active_personality_names || [],
  }));

  state.currentScene = last.scene;
  state.currentAudioB64 = "";
  state.currentAudioUrl = "";

  el("wedding-banner").classList.add("hidden");
  showScreen("screen-novel");
  refreshHudPills(last.scene);
  await applySceneVisualsFromLocalPC(last.scene);

  if (el("novel-portrait").dataset.hasLocal === "1") {
    el("novel-portrait").classList.remove("hidden");
  }

  stagePresenter.setDirection(last.scene.stage_direction);
  stagePresenter.applyStep("dialogue", true);
  state.subStep = "dialogue";
  renderTextbox(last.scene.dialogue, true);

  if (last.saved_wav_file) {
    playCurrentVoice(`/local/save_audio?session_id=${encodeURIComponent(sessionId)}&file=${encodeURIComponent(last.saved_wav_file)}`);
  }
}

// ==================== ゲーム内 AquesTalk1 ボイス・SE設定ドロワー ====================

function renderVoiceDrawer() {
  const pool = state.voicePool || state.catalog?.voice_pool;
  const depYen = state.user ? state.user.deposit_yen : 0;
  el("chk-hud-voice-enabled").checked = state.voiceEnabled;
  updateSeHudButton();
  el("vd-user-entitlement").textContent = `現在状態: ${describeUserVoiceEntitlement(state.user, pool)} / デポジット残高: ¥${depYen.toLocaleString()}`;

  if (pool) {
    el("vd-bar-fill").style.width = `${pool.progress_pct}%`;
    el("vd-pool-text").textContent = pool.is_goal_reached
      ? `🎉 今年度のAquesTalk1ライセンス実費（¥${pool.target_yen.toLocaleString()}）は100%回収達成しました！次期更新まで全プレイヤー無料開放中です。`
      : `今年度AquesTalk1実費回収額: ¥${pool.collected_yen.toLocaleString()} / ¥${pool.target_yen.toLocaleString()} (${pool.progress_pct}%) — 残り ¥${pool.remaining_yen.toLocaleString()} で全員無料開放（利益0円上限ストッパー付）`;
  }

  const listEl = el("vd-plan-buttons");
  listEl.innerHTML = "";
  if (pool?.is_goal_reached) return;

  (state.catalog?.voice_plans || []).forEach((vp) => {
    const div = document.createElement("div");
    div.className = "save-item";
    div.innerHTML = `<strong>${vp.label}</strong><br><span style="opacity:.85">${vp.desc}</span>`;
    div.onclick = async () => {
      if (!state.user) {
        alert("購入にはログインが必要です。");
        return;
      }
      if (state.user.deposit_yen < vp.price_yen) {
        alert(`デポジット残高が不足しています（残高 ¥${state.user.deposit_yen.toLocaleString()} / 必要額 ¥${vp.price_yen.toLocaleString()}）。初期画面からデポジットを追加できます。`);
        return;
      }
      if (!confirm(`デポジット残高から「${vp.label}」を有効化しますか？`)) return;
      try {
        const res = await apiPost("/api/billing/purchase_voice_plan", { voice_plan_id: vp.id });
        state.user = res.user;
        state.voicePool = res.voice_pool;
        refreshHudPills(state.currentScene);
        renderVoiceDrawer();
      } catch (err) {
        alert(err.message);
      }
    };
    listEl.appendChild(div);
  });
}

el("btn-open-voice-panel").onclick = () => {
  const dr = el("voice-drawer");
  dr.classList.toggle("hidden");
  if (!dr.classList.contains("hidden")) {
    el("personality-drawer").classList.add("hidden");
    renderVoiceDrawer();
  }
};
el("btn-close-voice-drawer").onclick = () => el("voice-drawer").classList.add("hidden");
el("chk-hud-voice-enabled").onchange = async (e) => {
  state.voiceEnabled = e.target.checked;
  el("chk-voice-enabled").checked = state.voiceEnabled;
  await localPost("/local/config", { voice_enabled: state.voiceEnabled });
  refreshHudPills(state.currentScene);
  renderVoiceDrawer();
};
el("chk-hud-se-enabled").onchange = async (e) => {
  state.seEnabled = e.target.checked;
  updateSeHudButton();
  await localPost("/local/config", { se_enabled: state.seEnabled });
};
el("rng-se-volume").oninput = async (e) => {
  state.seVolume = Number(e.target.value) / 100;
  updateSeHudButton();
  await localPost("/local/config", { se_volume: state.seVolume });
};
el("btn-test-se-hud").onclick = () => {
  unlockAllAudio();
  stageSound.playSe("sparkle_twinkle", 0.85);
};

// 低負荷生存通知（ウィンドウ終了後にPythonクライアントを自動終了させ待機メモリ0MBを保つ）
setInterval(() => {
  fetch("/local/ping").catch(() => {});
}, 12000);

window.addEventListener("DOMContentLoaded", bootSequence);

// ==================== 🌸 『東方キャラ立絵スタジオ』モーダル ＆ リアルタイム色変え・スポイト置換制御 ====================

function openFullTachieStudioModal() {
  unlockAllAudio();
  const cname = state.selectedChar?.name || "";
  const modal = el("tachie-studio-modal");
  const iframe = el("tachie-studio-iframe");
  iframe.src = `/tachie_studio/index.html?char_name=${encodeURIComponent(cname)}&t=${Date.now()}`;
  modal.classList.remove("hidden");
}

el("btn-open-tachie-char").onclick = openFullTachieStudioModal;
el("btn-launch-full-tachie-studio").onclick = () => {
  el("color-custom-drawer").classList.add("hidden");
  openFullTachieStudioModal();
};
el("btn-close-tachie-modal").onclick = () => {
  el("tachie-studio-modal").classList.add("hidden");
  el("tachie-studio-iframe").src = "about:blank";
};

window.addEventListener("message", async (ev) => {
  const d = ev.data || {};
  if (d.type === "renai_tachie_updated") {
    tachieColorEngine.clearCache();
    const st = await localGet("/local/assets/status?rescan=1");
    updateAssetsBadge(st);
    if (el("screen-char-select").classList.contains("active")) {
      await renderCharSelector();
    } else if (state.currentScene) {
      await applySceneVisualsFromLocalPC(state.currentScene);
    }
    showPersonalityToast(`『${d.char_name}』のカスタム立ち絵をゲームへ即時反映しました！`);
  }
});

function syncColorDrawerControls() {
  const prof = getCharColorProfile(state.selectedChar);
  el("chk-auto-time-tint").checked = prof.autoTimeTint !== false;
  el("sel-live-filter").value = prof.filter || "normal";
  el("rng-c-hue").value = prof.hue || 0;
  el("lbl-c-hue").textContent = `${prof.hue || 0}°`;
  el("rng-c-sat").value = prof.saturation ?? 100;
  el("lbl-c-sat").textContent = `${prof.saturation ?? 100}%`;
  el("rng-c-bri").value = prof.brightness || 0;
  el("lbl-c-bri").textContent = `${prof.brightness || 0}%`;
  el("rng-c-con").value = prof.contrast || 0;
  el("lbl-c-con").textContent = `${prof.contrast || 0}%`;
  el("rng-c-temp").value = prof.temperature || 0;
  el("lbl-c-temp").textContent = String(prof.temperature || 0);
  renderLiveColorRules();
}

async function applyAndSaveLiveColor(rebuildPixels = false) {
  const prof = getCharColorProfile(state.selectedChar);
  const tod = state.currentScene?.bg_time_of_day || state.currentScene?.background?.time_of_day || "day";
  el("novel-portrait").style.filter = tachieColorEngine.buildCssFilter(prof, tod);
  if (rebuildPixels && state.currentScene) {
    tachieColorEngine.clearCache();
    await applySceneVisualsFromLocalPC(state.currentScene);
  }
  await localPost("/local/config", { char_color_profiles: state.charColorProfiles });
}

function renderLiveColorRules() {
  const prof = getCharColorProfile(state.selectedChar);
  const wrap = el("live-color-rules-list");
  wrap.innerHTML = "";
  (prof.rules || []).forEach((rule, idx) => {
    const row = document.createElement("div");
    row.className = "color-rule-row";
    row.innerHTML = `
      <span>元色</span>
      <input type="color" value="${rule.srcHex}" data-rfield="src" style="width:28px;height:24px;border:none;background:none;cursor:pointer">
      <span>→ 変更色</span>
      <input type="color" value="${rule.dstHex}" data-rfield="dst" style="width:28px;height:24px;border:none;background:none;cursor:pointer">
      <input type="range" min="15" max="110" value="${rule.tolerance || 48}" title="許容範囲" style="flex:1">
      <button class="save-mini-btn danger" style="padding:2px 6px">×</button>
    `;
    const [srcInp, dstInp] = row.querySelectorAll('input[type="color"]');
    const tolInp = row.querySelector('input[type="range"]');
    const delBtn = row.querySelector("button");
    srcInp.onchange = (e) => { rule.srcHex = e.target.value; applyAndSaveLiveColor(true); };
    dstInp.onchange = (e) => { rule.dstHex = e.target.value; applyAndSaveLiveColor(true); };
    tolInp.onchange = (e) => { rule.tolerance = Number(e.target.value); applyAndSaveLiveColor(true); };
    delBtn.onclick = () => {
      prof.rules.splice(idx, 1);
      renderLiveColorRules();
      applyAndSaveLiveColor(true);
    };
    wrap.appendChild(row);
  });
}

el("btn-open-tachie-drawer").onclick = () => {
  const dr = el("color-custom-drawer");
  dr.classList.toggle("hidden");
  if (!dr.classList.contains("hidden")) {
    el("personality-drawer").classList.add("hidden");
    el("voice-drawer").classList.add("hidden");
    syncColorDrawerControls();
  }
};
el("btn-close-color-drawer").onclick = () => el("color-custom-drawer").classList.add("hidden");

el("chk-auto-time-tint").onchange = (e) => {
  getCharColorProfile(state.selectedChar).autoTimeTint = e.target.checked;
  applyAndSaveLiveColor(false);
};
el("sel-live-filter").onchange = (e) => {
  getCharColorProfile(state.selectedChar).filter = e.target.value;
  applyAndSaveLiveColor(false);
};
el("rng-c-hue").oninput = (e) => {
  getCharColorProfile(state.selectedChar).hue = Number(e.target.value);
  el("lbl-c-hue").textContent = `${e.target.value}°`;
  applyAndSaveLiveColor(false);
};
el("rng-c-sat").oninput = (e) => {
  getCharColorProfile(state.selectedChar).saturation = Number(e.target.value);
  el("lbl-c-sat").textContent = `${e.target.value}%`;
  applyAndSaveLiveColor(false);
};
el("rng-c-bri").oninput = (e) => {
  getCharColorProfile(state.selectedChar).brightness = Number(e.target.value);
  el("lbl-c-bri").textContent = `${e.target.value}%`;
  applyAndSaveLiveColor(false);
};
el("rng-c-con").oninput = (e) => {
  getCharColorProfile(state.selectedChar).contrast = Number(e.target.value);
  el("lbl-c-con").textContent = `${e.target.value}%`;
  applyAndSaveLiveColor(false);
};
el("rng-c-temp").oninput = (e) => {
  getCharColorProfile(state.selectedChar).temperature = Number(e.target.value);
  el("lbl-c-temp").textContent = String(e.target.value);
  applyAndSaveLiveColor(false);
};

el("btn-reset-live-color").onclick = () => {
  const cid = state.selectedChar?.char_id || "default";
  state.charColorProfiles[cid] = window.defaultTachieColorProfile();
  syncColorDrawerControls();
  applyAndSaveLiveColor(true);
};

el("btn-pick-sprite-color").onclick = async () => {
  const cvs = el("sprite-eyedropper-canvas");
  if (!cvs.classList.contains("hidden")) {
    cvs.classList.add("hidden");
    return;
  }
  const blob = state._lastRawPortraitBlob;
  if (!blob) return;
  const u = URL.createObjectURL(blob);
  const img = new Image();
  img.onload = () => {
    const scale = Math.min(1, 320 / Math.max(1, img.width));
    cvs.width = Math.round(img.width * scale);
    cvs.height = Math.round(img.height * scale);
    const ctx = cvs.getContext("2d", { willReadFrequently: true });
    ctx.clearRect(0, 0, cvs.width, cvs.height);
    ctx.drawImage(img, 0, 0, cvs.width, cvs.height);
    cvs.classList.remove("hidden");
    URL.revokeObjectURL(u);
  };
  img.src = u;
};

el("sprite-eyedropper-canvas").onclick = (ev) => {
  const cvs = el("sprite-eyedropper-canvas");
  const rect = cvs.getBoundingClientRect();
  const x = Math.floor(((ev.clientX - rect.left) / rect.width) * cvs.width);
  const y = Math.floor(((ev.clientY - rect.top) / rect.height) * cvs.height);
  const ctx = cvs.getContext("2d", { willReadFrequently: true });
  const px = ctx.getImageData(Math.max(0, x), Math.max(0, y), 1, 1).data;
  if (px[3] < 20) return;
  const srcHex = "#" + [px[0], px[1], px[2]].map((v) => v.toString(16).padStart(2, "0")).join("");
  const prof = getCharColorProfile(state.selectedChar);
  prof.rules = prof.rules || [];
  prof.rules.push({ srcHex, dstHex: "#3b82f6", tolerance: 48 });
  cvs.classList.add("hidden");
  renderLiveColorRules();
  applyAndSaveLiveColor(true);
};
