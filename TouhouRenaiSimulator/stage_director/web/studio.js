/**
 * 『キャラステージ演出メーカー』スタジオ制御 (studio.js)
 */
const el = (id) => document.getElementById(id);

const studioState = {
  catalog: null,
  characters: [],
  backgrounds: [],
  localSe: [],
  saves: [],
  loadedSessionId: "",
  loadedTurns: [],
  activeTurnIdx: -1,
  activeStep: "narration",
  dir: {
    distance_preset: "close",
    narration_scale: 1.0,
    dialogue_scale: 1.18,
    offset_x: 0,
    offset_y: 3.5,
    origin_y_pct: 26,
    narration_motion: "step_closer",
    dialogue_motion: "lean_in",
    transition_ms: 640,
    screen_effect: "warm_bloom",
    bg_zoom: 1.05,
    bg_blur_px: 0.8,
    se_cues: [
      { se_id: "footsteps_walk", trigger: "narration", delay_ms: 0, volume: 0.72 },
      { se_id: "cloth_rustle", trigger: "dialogue", delay_ms: 0, volume: 0.75 },
      { se_id: "blush_pop", trigger: "dialogue", delay_ms: 260, volume: 0.68 },
    ],
  },
};

const soundEngine = new window.StageSoundEngine({ localSeEndpoint: "/local/assets/se" });
let presenter = null;

async function apiGet(path) {
  const r = await fetch(path);
  return r.json();
}

async function apiPost(path, body) {
  const r = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return r.json();
}

async function initStudio(rescan = false) {
  presenter = new window.StagePresenter(
    {
      bgEl: el("studio-bg"),
      screenEl: el("studio-viewport"),
      rigEl: el("studio-rig"),
      motionEl: el("studio-motion"),
      portraitEl: el("studio-portrait"),
      overlayEl: el("studio-fx-overlay"),
      badgeEl: el("studio-badge"),
    },
    soundEngine
  );

  const boot = await apiGet(`/api/bootstrap?rescan=${rescan ? "1" : "0"}`);
  studioState.catalog = boot.catalog;
  studioState.characters = boot.characters || [];
  studioState.backgrounds = boot.backgrounds || [];
  studioState.localSe = boot.local_sound_effects || [];
  studioState.saves = boot.saved_sessions || [];
  soundEngine.setLocalSeCatalog(studioState.localSe);

  renderAssetSelectors();
  renderInspectorCatalog();
  renderSaveSelector();
  renderCustomPresets(studioState.catalog.custom_presets || []);
  syncControlsFromDir();
  applyStudioStep("narration", false);
}

function renderAssetSelectors() {
  const cSel = el("sel-char");
  cSel.innerHTML = "";
  studioState.characters.forEach((c) => {
    const opt = document.createElement("option");
    opt.value = String(c.idx);
    opt.textContent = `${c.name} (${c.group})`;
    cSel.appendChild(opt);
  });
  cSel.onchange = () => populateFaces();
  populateFaces();

  const bSel = el("sel-bg");
  bSel.innerHTML = "";
  studioState.backgrounds.forEach((b) => {
    const opt = document.createElement("option");
    opt.value = String(b.idx);
    opt.textContent = b.name;
    bSel.appendChild(opt);
  });
  bSel.onchange = () => {
    el("studio-bg").style.backgroundImage = `url("/api/asset/bg?bidx=${bSel.value}")`;
  };
  if (studioState.backgrounds.length) {
    el("studio-bg").style.backgroundImage = `url("/api/asset/bg?bidx=0")`;
  }
}

function populateFaces() {
  const cidx = Number(el("sel-char").value || 0);
  const fSel = el("sel-face");
  fSel.innerHTML = "";
  const ch = studioState.characters[cidx];
  if (!ch) return;
  ch.faces.forEach((f) => {
    const opt = document.createElement("option");
    opt.value = String(f.fidx);
    opt.textContent = f.label;
    fSel.appendChild(opt);
  });
  fSel.onchange = () => {
    el("studio-portrait").src = `/api/asset/portrait?cidx=${cidx}&fidx=${fSel.value}`;
  };
  el("studio-portrait").src = `/api/asset/portrait?cidx=${cidx}&fidx=0`;
}

function renderInspectorCatalog() {
  const dGrid = el("distance-grid");
  dGrid.innerHTML = "";
  (studioState.catalog.distance_presets || []).forEach((dp) => {
    const btn = document.createElement("button");
    btn.className = "chip-btn";
    btn.dataset.distId = dp.id;
    btn.textContent = `${dp.label.split("（")[0]} (${Math.round(dp.scale * 100)}%)`;
    btn.title = dp.desc;
    btn.onclick = () => {
      soundEngine.unlock();
      studioState.dir.distance_preset = dp.id;
      studioState.dir.dialogue_scale = dp.scale;
      studioState.dir.narration_scale = dp.scale > 1.1 ? Number((dp.scale - 0.12).toFixed(2)) : dp.scale;
      studioState.dir.offset_y = dp.offset_y_vh;
      studioState.dir.origin_y_pct = dp.origin_y_pct;
      studioState.dir.bg_zoom = dp.bg_zoom;
      studioState.dir.bg_blur_px = dp.bg_blur_px;
      syncControlsFromDir();
      applyStudioStep(studioState.activeStep, false);
    };
    dGrid.appendChild(btn);
  });

  const nMot = el("sel-n-motion");
  const dMot = el("sel-d-motion");
  nMot.innerHTML = "";
  dMot.innerHTML = "";
  (studioState.catalog.motion_presets || []).forEach((m) => {
    [nMot, dMot].forEach((sel) => {
      const opt = document.createElement("option");
      opt.value = m.id;
      opt.textContent = `[${m.category}] ${m.label}`;
      sel.appendChild(opt);
    });
  });

  const fxSel = el("sel-screen-fx");
  fxSel.innerHTML = "";
  (studioState.catalog.screen_effects || []).forEach((fx) => {
    const opt = document.createElement("option");
    opt.value = fx.id;
    opt.textContent = fx.label;
    fxSel.appendChild(opt);
  });

  const seSel = el("sel-se-picker");
  seSel.innerHTML = "";
  studioState.localSe.forEach((ls) => {
    const opt = document.createElement("option");
    opt.value = ls.se_id;
    opt.textContent = `📁 [ローカルSE] ${ls.name}`;
    seSel.appendChild(opt);
  });
  (studioState.catalog.builtin_sound_effects || []).forEach((bs) => {
    const opt = document.createElement("option");
    opt.value = bs.se_id;
    opt.textContent = `🔔 ${bs.name}`;
    seSel.appendChild(opt);
  });
}

function renderSaveSelector() {
  const sel = el("sel-save-session");
  sel.innerHTML = "";
  const optEmpty = document.createElement("option");
  optEmpty.value = "";
  optEmpty.textContent = studioState.saves.length
    ? "── セーブデータを選択してスライド読込 ──"
    : "（セーブデータはまだありません）";
  sel.appendChild(optEmpty);

  studioState.saves.forEach((s) => {
    const opt = document.createElement("option");
    opt.value = s.session_id;
    opt.textContent = `${s.char_name} / ${s.player_name} (#${s.latest_turn} ♥${s.affection}%)`;
    sel.appendChild(opt);
  });

  sel.onchange = async () => {
    const sid = sel.value;
    studioState.loadedSessionId = sid;
    const strip = el("save-turns-strip");
    strip.innerHTML = "";
    el("btn-save-back-turn").classList.add("hidden");
    if (!sid) return;
    const data = await apiGet(`/api/saves/load?session_id=${encodeURIComponent(sid)}`);
    studioState.loadedTurns = data.turns || [];
    studioState.loadedTurns.forEach((t, idx) => {
      const card = document.createElement("div");
      card.className = "slide-card";
      const sd = t.scene.stage_direction || {};
      card.innerHTML = `<span><strong>#${t.turn_index}</strong> ${t.scene.dialogue.slice(0, 17)}…</span><span>${Math.round((sd.dialogue_scale || 1) * 100)}%</span>`;
      card.onclick = () => loadTurnIntoStage(idx, card);
      strip.appendChild(card);
    });
    if (studioState.loadedTurns.length) {
      loadTurnIntoStage(studioState.loadedTurns.length - 1, strip.lastElementChild);
    }
  };
}

function loadTurnIntoStage(idx, cardEl) {
  soundEngine.unlock();
  document.querySelectorAll(".slide-card").forEach((c) => c.classList.remove("active"));
  if (cardEl) cardEl.classList.add("active");
  const t = studioState.loadedTurns[idx];
  if (!t) return;
  studioState.activeTurnIdx = t.turn_index;
  el("btn-save-back-turn").classList.remove("hidden");

  const sc = t.scene || {};
  el("inp-narration").value = sc.narration || "";
  el("inp-dialogue").value = sc.dialogue || "";
  if (sc.background && sc.background.bg_id) {
    el("studio-bg").style.backgroundImage = `url("/api/asset/bg?bg_id=${encodeURIComponent(sc.background.bg_id)}")`;
  }
  if (sc.speaker_name) {
    el("studio-portrait").src = `/api/asset/portrait?char_name=${encodeURIComponent(sc.speaker_name)}&emotion=${encodeURIComponent(sc.emotion || "normal")}`;
  }
  studioState.dir = JSON.parse(JSON.stringify(sc.stage_direction || studioState.dir));
  syncControlsFromDir();
  playTwoStepSequence(t);
}

function syncControlsFromDir() {
  const d = studioState.dir;
  document.querySelectorAll("[data-dist-id]").forEach((b) => {
    b.classList.toggle("active", b.dataset.distId === d.distance_preset);
  });
  el("rng-n-scale").value = Math.round((d.narration_scale || 1) * 100);
  el("lbl-n-scale").textContent = `${Math.round((d.narration_scale || 1) * 100)}%`;
  el("rng-d-scale").value = Math.round((d.dialogue_scale || 1) * 100);
  el("lbl-d-scale").textContent = `${Math.round((d.dialogue_scale || 1) * 100)}%`;
  el("rng-off-x").value = d.offset_x || 0;
  el("lbl-off-x").textContent = `${d.offset_x || 0}vw`;
  el("rng-off-y").value = d.offset_y || 0;
  el("lbl-off-y").textContent = `${d.offset_y || 0}vh`;
  el("rng-trans-ms").value = d.transition_ms || 640;
  el("lbl-trans-ms").textContent = `${d.transition_ms || 640}ms`;
  el("sel-n-motion").value = d.narration_motion || "none";
  el("sel-d-motion").value = d.dialogue_motion || "none";
  el("sel-screen-fx").value = d.screen_effect || "none";
  renderCuesList();
}

function renderCuesList() {
  const wrap = el("se-cues-list");
  wrap.innerHTML = "";
  (studioState.dir.se_cues || []).forEach((c, i) => {
    const row = document.createElement("div");
    row.className = "cue-item";
    const stepLbl = c.trigger === "narration" ? "①地の文" : "②セリフ";
    row.innerHTML = `<span>${stepLbl}: <strong>${c.se_id}</strong> (+${c.delay_ms || 0}ms)</span>`;
    const del = document.createElement("button");
    del.className = "mini-del";
    del.textContent = "削除";
    del.onclick = (ev) => {
      ev.stopPropagation();
      studioState.dir.se_cues.splice(i, 1);
      renderCuesList();
    };
    row.onclick = () => {
      soundEngine.unlock();
      soundEngine.playSe(c.se_id, c.volume || 0.75);
    };
    row.appendChild(del);
    wrap.appendChild(row);
  });
}

function applyStudioStep(stepName, playSe = true) {
  studioState.activeStep = stepName;
  el("btn-step-narration").classList.toggle("active", stepName === "narration");
  el("btn-step-dialogue").classList.toggle("active", stepName === "dialogue");
  const cap = el("studio-caption");
  cap.textContent = stepName === "narration" ? el("inp-narration").value : el("inp-dialogue").value;
  cap.classList.toggle("narration", stepName === "narration");
  presenter.setDirection(studioState.dir);
  presenter.applyStep(stepName, playSe);
}

let _seqTimer = null;
function playTwoStepSequence(turnObj = null) {
  soundEngine.unlock();
  clearTimeout(_seqTimer);
  const vp = el("studio-voice-player");
  vp.pause();
  el("studio-portrait").classList.remove("speaking");

  applyStudioStep("narration", true);
  _seqTimer = setTimeout(() => {
    applyStudioStep("dialogue", true);
    const activeTurn = turnObj || studioState.loadedTurns.find((x) => x.turn_index === studioState.activeTurnIdx);
    if (activeTurn && activeTurn.saved_wav_file && studioState.loadedSessionId) {
      vp.src = `/api/saves/audio?session_id=${encodeURIComponent(studioState.loadedSessionId)}&file=${encodeURIComponent(activeTurn.saved_wav_file)}`;
      el("studio-portrait").classList.add("speaking");
      vp.onended = () => el("studio-portrait").classList.remove("speaking");
      vp.onerror = () => el("studio-portrait").classList.remove("speaking");
      vp.play().catch(() => el("studio-portrait").classList.remove("speaking"));
    }
  }, 1350);
}

function renderCustomPresets(list) {
  const wrap = el("custom-preset-list");
  wrap.innerHTML = "";
  list.forEach((p) => {
    const row = document.createElement("div");
    row.className = "preset-card";
    row.innerHTML = `<span>⭐ ${p.name}</span>`;
    row.onclick = () => {
      studioState.dir = JSON.parse(JSON.stringify(p.stage_direction));
      syncControlsFromDir();
      playTwoStepSequence();
    };
    const del = document.createElement("button");
    del.className = "mini-del";
    del.textContent = "×";
    del.onclick = async (e) => {
      e.stopPropagation();
      const res = await apiPost("/api/presets/delete", { id: p.id });
      renderCustomPresets(res.custom_presets || []);
    };
    row.appendChild(del);
    wrap.appendChild(row);
  });
}

// イベント結線
el("btn-step-narration").onclick = () => { soundEngine.unlock(); applyStudioStep("narration", true); };
el("btn-step-dialogue").onclick = () => { soundEngine.unlock(); applyStudioStep("dialogue", true); };
el("btn-play-sequence").onclick = () => playTwoStepSequence();

el("rng-n-scale").oninput = (e) => {
  studioState.dir.narration_scale = Number(e.target.value) / 100;
  el("lbl-n-scale").textContent = `${e.target.value}%`;
  applyStudioStep("narration", false);
};
el("rng-d-scale").oninput = (e) => {
  const sc = Number(e.target.value) / 100;
  studioState.dir.dialogue_scale = sc;
  studioState.dir.origin_y_pct = sc >= 1.25 ? 23 : (sc <= 0.82 ? 85 : 50);
  el("lbl-d-scale").textContent = `${e.target.value}%`;
  applyStudioStep("dialogue", false);
};
el("rng-off-x").oninput = (e) => {
  studioState.dir.offset_x = Number(e.target.value);
  el("lbl-off-x").textContent = `${e.target.value}vw`;
  applyStudioStep(studioState.activeStep, false);
};
el("rng-off-y").oninput = (e) => {
  studioState.dir.offset_y = Number(e.target.value);
  el("lbl-off-y").textContent = `${e.target.value}vh`;
  applyStudioStep(studioState.activeStep, false);
};
el("rng-trans-ms").oninput = (e) => {
  studioState.dir.transition_ms = Number(e.target.value);
  el("lbl-trans-ms").textContent = `${e.target.value}ms`;
};
el("sel-n-motion").onchange = (e) => {
  studioState.dir.narration_motion = e.target.value;
  soundEngine.unlock();
  applyStudioStep("narration", false);
};
el("sel-d-motion").onchange = (e) => {
  studioState.dir.dialogue_motion = e.target.value;
  soundEngine.unlock();
  applyStudioStep("dialogue", false);
};
el("sel-screen-fx").onchange = (e) => {
  studioState.dir.screen_effect = e.target.value;
  applyStudioStep(studioState.activeStep, false);
};

el("btn-test-se").onclick = () => {
  soundEngine.unlock();
  soundEngine.playSe(el("sel-se-picker").value, 0.82);
};
el("btn-add-cue").onclick = () => {
  soundEngine.unlock();
  studioState.dir.se_cues = studioState.dir.se_cues || [];
  studioState.dir.se_cues.push({
    se_id: el("sel-se-picker").value,
    trigger: el("sel-se-trig").value,
    delay_ms: studioState.dir.se_cues.filter((x) => x.trigger === el("sel-se-trig").value).length * 240,
    volume: 0.75,
  });
  renderCuesList();
};

el("btn-save-preset").onclick = async () => {
  const nm = el("inp-preset-name").value.trim() || `演出_${Date.now() % 1000}`;
  const res = await apiPost("/api/presets/save", { name: nm, stage_direction: studioState.dir });
  el("inp-preset-name").value = "";
  renderCustomPresets(res.custom_presets || []);
};

el("btn-save-back-turn").onclick = async () => {
  if (!studioState.loadedSessionId || studioState.activeTurnIdx < 0) return;
  const res = await apiPost("/api/saves/update_turn", {
    session_id: studioState.loadedSessionId,
    turn_index: studioState.activeTurnIdx,
    stage_direction: studioState.dir,
  });
  if (res.ok) alert(`会話 #${studioState.activeTurnIdx} の演出データをセーブへ保存しました！`);
};

el("btn-open-se-dir").onclick = () => apiPost("/api/open_se_folder", {});
el("btn-rescan").onclick = () => initStudio(true);

// 低頻度ハートビート（10秒おき・ネットワーク負荷ゼロ、ウィンドウ終了後25秒でサーバー自動終了）
setInterval(() => {
  fetch("/api/ping").catch(() => {});
}, 10000);

window.addEventListener("DOMContentLoaded", () => initStudio(false));
