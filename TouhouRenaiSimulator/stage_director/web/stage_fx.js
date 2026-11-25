/**
 * 『キャラステージ演出メーカー』超省リソース 演出＆ハイブリッド効果音エンジン (stage_fx.js)
 * 設計方針:
 *   - 外部ライブラリ依存ゼロ、メモリ常駐ほぼゼロ（単一AudioContext＋0.6秒共有ノイズバッファ約100KBのみ）
 *   - 再生完了したAudioNodeは即座にdisconnectしてGC解放、CSSアニメーションは有限回数完了後にクラス除去（アイドル時CPU 0.0%）
 *   - PCローカル効果音フォルダ (/local/assets/se) と内蔵Web AudioシンセSE（全20種）のハイブリッド再生に対応
 */
(function (global) {
  "use strict";

  const MOTION_LABELS = {
    none: "静止",
    slide_in_left: "左スライド登場",
    slide_in_right: "右スライド登場",
    fade_zoom_in: "フェード登場",
    float_in: "舞い降り登場",
    step_closer: "歩み寄り",
    step_back: "後ずさり",
    nod: "頷き",
    head_tilt: "小首かしげ",
    jump_happy: "喜びジャンプ",
    double_bounce: "2回バウンス",
    tremble: "震え",
    shake_angry: "怒り揺れ",
    sway_gentle: "甘え揺れ",
    lean_in: "覗き込み",
    hug_surge: "抱きつき",
    surprised_jolt: "ビクッ驚き",
    spin_turn: "華麗ターン",
  };

  class StageSoundEngine {
    constructor(options = {}) {
      this.enabled = options.enabled !== false;
      this.masterVolume = typeof options.volume === "number" ? options.volume : 0.8;
      this.localSeEndpoint = options.localSeEndpoint || "/local/assets/se";
      this.localSeIds = new Set();
      this._ctx = null;
      this._noiseBuf = null;
      this._timers = [];
      this._localAudioPool = [new Audio(), new Audio()];
      this._poolIdx = 0;
    }

    setLocalSeCatalog(list) {
      this.localSeIds.clear();
      (list || []).forEach((item) => {
        if (item && item.se_id) this.localSeIds.add(item.se_id);
      });
    }

    unlock() {
      const ctx = this._ensureCtx();
      if (ctx && ctx.state === "suspended") {
        ctx.resume().catch(() => {});
      }
    }

    clearPendingCues() {
      while (this._timers.length) {
        clearTimeout(this._timers.pop());
      }
    }

    playCuesForStep(cues, stepName) {
      this.clearPendingCues();
      if (!this.enabled || !Array.isArray(cues)) return;
      cues.forEach((cue) => {
        if (!cue || !cue.se_id) return;
        const trig = cue.trigger || "dialogue";
        if (trig !== stepName && trig !== "both") return;
        const delay = Math.max(0, Math.min(2500, Number(cue.delay_ms) || 0));
        const vol = Math.max(0.05, Math.min(1.0, Number(cue.volume) || 0.72));
        const tid = setTimeout(() => {
          this.playSe(cue.se_id, vol, cue.keyword || "");
        }, delay);
        this._timers.push(tid);
      });
    }

    playSe(seId, volume = 0.75, keyword = "") {
      if (!this.enabled || !seId) return;
      const effVol = Math.max(0.02, Math.min(1.0, volume * this.masterVolume));

      // 1. ローカル効果音フォルダ内に一致するSEがある場合はローカル音声ファイルを直接再生
      if (this.localSeIds.has(seId) || seId.startsWith("lse_")) {
        const audio = this._localAudioPool[this._poolIdx % this._localAudioPool.length];
        this._poolIdx++;
        const params = new URLSearchParams({ se_id: seId, keyword: keyword || "" });
        audio.pause();
        audio.volume = effVol;
        audio.src = `${this.localSeEndpoint}?${params.toString()}`;
        audio.play().catch(() => {
          this._synthBuiltin(seId, effVol);
        });
        return;
      }

      // 2. 内蔵プロシージャルWeb Audioシンセ再生（ディスク・メモリ負荷ゼロ）
      this._synthBuiltin(seId, effVol);
    }

    _ensureCtx() {
      if (!this._ctx) {
        const AC = global.AudioContext || global.webkitAudioContext;
        if (!AC) return null;
        this._ctx = new AC();
      }
      if (this._ctx.state === "suspended") {
        this._ctx.resume().catch(() => {});
      }
      return this._ctx;
    }

    _getNoiseBuffer(ctx) {
      if (this._noiseBuf) return this._noiseBuf;
      const len = Math.floor(ctx.sampleRate * 0.65);
      const buf = ctx.createBuffer(1, len, ctx.sampleRate);
      const ch = buf.getChannelData(0);
      for (let i = 0; i < len; i++) {
        ch[i] = Math.random() * 2 - 1;
      }
      this._noiseBuf = buf;
      return buf;
    }

    _noiseBurst(ctx, t0, dur, filterType, freq, q, gainPeak) {
      const src = ctx.createBufferSource();
      src.buffer = this._getNoiseBuffer(ctx);
      src.loop = dur > 0.6;
      const flt = ctx.createBiquadFilter();
      flt.type = filterType;
      flt.frequency.setValueAtTime(freq, t0);
      flt.Q.setValueAtTime(q, t0);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, t0);
      g.gain.linearRampToValueAtTime(gainPeak, t0 + Math.min(0.03, dur * 0.25));
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
      src.connect(flt);
      flt.connect(g);
      g.connect(ctx.destination);
      src.start(t0);
      src.stop(t0 + dur + 0.02);
      src.onended = () => {
        src.disconnect();
        flt.disconnect();
        g.disconnect();
      };
    }

    _tone(ctx, t0, dur, type, fStart, fEnd, gainPeak) {
      const osc = ctx.createOscillator();
      osc.type = type;
      osc.frequency.setValueAtTime(fStart, t0);
      if (fEnd && fEnd !== fStart) {
        osc.frequency.exponentialRampToValueAtTime(Math.max(20, fEnd), t0 + dur);
      }
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, t0);
      g.gain.linearRampToValueAtTime(gainPeak, t0 + Math.min(0.018, dur * 0.2));
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
      osc.connect(g);
      g.connect(ctx.destination);
      osc.start(t0);
      osc.stop(t0 + dur + 0.02);
      osc.onended = () => {
        osc.disconnect();
        g.disconnect();
      };
    }

    _synthBuiltin(seId, v) {
      const ctx = this._ensureCtx();
      if (!ctx) return;
      const now = ctx.currentTime + 0.01;

      switch (seId) {
        case "footsteps_walk":
          [0, 0.28, 0.56].forEach((dt, i) => {
            this._tone(ctx, now + dt, 0.075, "triangle", i % 2 ? 155 : 140, 58, 0.26 * v);
            this._noiseBurst(ctx, now + dt, 0.055, "bandpass", 900, 1.8, 0.16 * v);
          });
          break;

        case "footsteps_run":
          [0, 0.14, 0.28, 0.42].forEach((dt, i) => {
            this._tone(ctx, now + dt, 0.06, "triangle", i % 2 ? 185 : 165, 65, 0.28 * v);
            this._noiseBurst(ctx, now + dt, 0.045, "bandpass", 1150, 1.6, 0.18 * v);
          });
          break;

        case "cloth_rustle":
          this._noiseBurst(ctx, now, 0.26, "bandpass", 2100, 1.1, 0.22 * v);
          this._noiseBurst(ctx, now + 0.09, 0.20, "bandpass", 1500, 1.4, 0.16 * v);
          break;

        case "hug_embrace":
          this._noiseBurst(ctx, now, 0.34, "bandpass", 1750, 0.9, 0.28 * v);
          this._tone(ctx, now + 0.04, 0.24, "sine", 130, 52, 0.32 * v);
          this._noiseBurst(ctx, now + 0.18, 0.26, "lowpass", 1100, 1.0, 0.18 * v);
          break;

        case "heartbeat":
          [0, 0.62].forEach((beat) => {
            this._tone(ctx, now + beat, 0.14, "sine", 78, 38, 0.44 * v);
            this._tone(ctx, now + beat + 0.17, 0.12, "sine", 66, 34, 0.32 * v);
          });
          break;

        case "heartbeat_fast":
          [0, 0.38, 0.76].forEach((beat) => {
            this._tone(ctx, now + beat, 0.11, "sine", 88, 42, 0.45 * v);
            this._tone(ctx, now + beat + 0.13, 0.10, "sine", 74, 38, 0.34 * v);
          });
          break;

        case "sparkle_twinkle":
          [587.3, 784.0, 1046.5, 1318.5, 1568.0].forEach((f, idx) => {
            this._tone(ctx, now + idx * 0.065, 0.34, "sine", f, f * 1.01, 0.17 * v);
          });
          break;

        case "blush_pop":
          this._tone(ctx, now, 0.16, "sine", 340, 690, 0.24 * v);
          this._tone(ctx, now + 0.11, 0.20, "sine", 520, 880, 0.18 * v);
          break;

        case "question_pon":
          this._tone(ctx, now, 0.22, "sine", 392, 622, 0.26 * v);
          break;

        case "surprised_biku":
          this._tone(ctx, now, 0.14, "triangle", 320, 980, 0.28 * v);
          this._tone(ctx, now + 0.08, 0.18, "sine", 980, 1320, 0.20 * v);
          break;

        case "angry_boom":
          this._tone(ctx, now, 0.28, "sawtooth", 125, 46, 0.24 * v);
          this._noiseBurst(ctx, now, 0.15, "lowpass", 420, 1.5, 0.24 * v);
          break;

        case "slap_tsukkomi":
          this._noiseBurst(ctx, now, 0.09, "bandpass", 2400, 0.8, 0.38 * v);
          this._tone(ctx, now, 0.08, "triangle", 260, 75, 0.32 * v);
          break;

        case "dark_yandere":
          this._tone(ctx, now, 0.95, "sine", 65.4, 58.0, 0.30 * v);
          this._tone(ctx, now + 0.03, 0.90, "triangle", 92.5, 87.3, 0.16 * v);
          break;

        case "sigh_soft":
          this._noiseBurst(ctx, now, 0.55, "bandpass", 950, 1.6, 0.14 * v);
          break;

        case "door_knock":
          [0, 0.19].forEach((dt) => {
            this._tone(ctx, now + dt, 0.075, "triangle", 210, 88, 0.36 * v);
            this._noiseBurst(ctx, now + dt, 0.04, "bandpass", 700, 2.2, 0.18 * v);
          });
          break;

        case "door_open":
          this._noiseBurst(ctx, now, 0.06, "highpass", 1800, 1.5, 0.20 * v);
          this._tone(ctx, now + 0.07, 0.38, "sawtooth", 190, 255, 0.09 * v);
          break;

        case "tea_pour":
          [0, 0.13, 0.26, 0.39, 0.52].forEach((dt, idx) => {
            this._tone(ctx, now + dt, 0.085, "sine", 420 + idx * 42, 610 + idx * 45, 0.15 * v);
          });
          this._noiseBurst(ctx, now, 0.58, "bandpass", 1600, 1.4, 0.10 * v);
          break;

        case "wind_breeze":
          this._noiseBurst(ctx, now, 0.85, "bandpass", 620, 1.9, 0.15 * v);
          break;

        case "magic_chime":
          [659.3, 880.0, 1174.7, 1568.0, 2093.0].forEach((f, i) => {
            this._tone(ctx, now + i * 0.055, 0.48, "sine", f, f * 1.005, 0.15 * v);
          });
          break;

        case "wedding_bell":
          [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => {
            this._tone(ctx, now + i * 0.22, 0.75, "sine", f, f, 0.24 * v);
            this._tone(ctx, now + i * 0.22, 0.45, "triangle", f * 2, f * 2, 0.08 * v);
          });
          break;

        default:
          this._noiseBurst(ctx, now, 0.18, "bandpass", 1800, 1.2, 0.18 * v);
          break;
      }
    }
  }

  class StagePresenter {
    constructor(elements, soundEngine) {
      this.bgEl = elements.bgEl;
      this.screenEl = elements.screenEl;
      this.rigEl = elements.rigEl;
      this.motionEl = elements.motionEl;
      this.portraitEl = elements.portraitEl;
      this.overlayEl = elements.overlayEl;
      this.badgeEl = elements.badgeEl || null;
      this.sound = soundEngine;
      this._currentDir = null;
      this._activeMotionClass = "";
      this._rigTimer = null;

      if (this.motionEl) {
        this.motionEl.addEventListener("animationend", () => {
          if (this._activeMotionClass) {
            this.motionEl.classList.remove(this._activeMotionClass);
            this._activeMotionClass = "";
          }
        });
      }
      if (this.screenEl) {
        this.screenEl.addEventListener("animationend", () => {
          this.screenEl.classList.remove("stage-screen-shake");
        });
      }
    }

    setDirection(stageDir) {
      this._currentDir = stageDir || {
        distance_preset: "normal",
        narration_scale: 1.0,
        dialogue_scale: 1.0,
        offset_x: 0,
        offset_y: 0,
        origin_y_pct: 55,
        narration_motion: "none",
        dialogue_motion: "nod",
        transition_ms: 600,
        screen_effect: "none",
        bg_zoom: 1.02,
        bg_blur_px: 0,
        se_cues: [],
      };
    }

    applyStep(stepName, playSe = true) {
      const d = this._currentDir;
      if (!d || !this.rigEl) return;

      const isDiag = stepName === "dialogue";
      const scale = isDiag ? (d.dialogue_scale ?? 1.0) : (d.narration_scale ?? 1.0);
      const motion = isDiag ? (d.dialogue_motion || "none") : (d.narration_motion || "none");
      const offX = Number(d.offset_x) || 0;
      // スケールに応じた自然なYオフセット補間
      const baseOffY = Number(d.offset_y) || 0;
      const offY = scale > 1.04 ? baseOffY * ((scale - 1.0) / Math.max(0.08, (d.dialogue_scale || scale) - 1.0 || 0.2)) : baseOffY;
      const clampedOffY = Math.max(-12, Math.min(20, Number.isFinite(offY) ? offY : 0));
      const originY = d.origin_y_pct ?? (scale > 1.1 ? 24 : 55);
      const transMs = d.transition_ms ?? 620;

      // 1. カメラ拡大縮小・XY移動（プレゼンソフトのマジックムーブ補間）
      this.rigEl.classList.add("animating");
      this.rigEl.style.setProperty("--stage-origin-y", `${originY}%`);
      this.rigEl.style.setProperty("--stage-scale", String(scale));
      this.rigEl.style.setProperty("--stage-off-x", `${offX}vw`);
      this.rigEl.style.setProperty("--stage-off-y", `${clampedOffY.toFixed(2)}vh`);
      this.rigEl.style.setProperty("--stage-trans-ms", `${transMs}ms`);
      clearTimeout(this._rigTimer);
      this._rigTimer = setTimeout(() => {
        if (this.rigEl) this.rigEl.classList.remove("animating");
      }, transMs + 80);

      // 2. 背景の被写界深度（至近距離時の微細ズーム＆背景ボケ）
      if (this.bgEl) {
        const bgZ = isDiag ? (d.bg_zoom ?? 1.02) : Math.max(1.0, ((d.bg_zoom ?? 1.02) + 1.0) * 0.5);
        const bgBlur = isDiag ? (d.bg_blur_px ?? 0) : Math.max(0, (d.bg_blur_px ?? 0) * 0.5);
        this.bgEl.style.setProperty("--bg-zoom", String(bgZ.toFixed(3)));
        this.bgEl.style.setProperty("--bg-blur", `${bgBlur.toFixed(1)}px`);
      }

      // 3. 有限回数モーション発火
      if (this.motionEl) {
        if (this._activeMotionClass) {
          this.motionEl.classList.remove(this._activeMotionClass);
          this._activeMotionClass = "";
        }
        if (motion && motion !== "none") {
          void this.motionEl.offsetWidth; // 軽量リフローで同一モーション連続再生にも対応
          const cls = `mot-${motion}`;
          this._activeMotionClass = cls;
          this.motionEl.classList.add(cls);
        }
      }

      // 4. 画面エフェクト
      const fx = d.screen_effect || "none";
      if (this.overlayEl) {
        this.overlayEl.className = "stage-fx-overlay";
        if (fx && fx !== "none" && fx !== "screen_shake") {
          this.overlayEl.classList.add(`fx-${fx}`);
        }
      }
      if (fx === "screen_shake" && this.screenEl && isDiag) {
        this.screenEl.classList.remove("stage-screen-shake");
        void this.screenEl.offsetWidth;
        this.screenEl.classList.add("stage-screen-shake");
      }

      // 5. 効果音タイムライン再生
      if (playSe && this.sound) {
        this.sound.playCuesForStep(d.se_cues || [], stepName);
      }

      // 6. 演出ステータスバッジ更新
      if (this.badgeEl) {
        const pct = Math.round(scale * 100);
        const motLabel = MOTION_LABELS[motion] || motion;
        const seList = (d.se_cues || [])
          .filter((c) => (c.trigger || "dialogue") === stepName || c.trigger === "both")
          .map((c) => c.se_id);
        const seTxt = seList.length ? ` / 🔔 ${seList.join(", ")}` : "";
        this.badgeEl.textContent = `🎬 ${pct}% ・ ${motLabel}${seTxt}`;
      }
    }
  }

  global.StageSoundEngine = StageSoundEngine;
  global.StagePresenter = StagePresenter;
  global.STAGE_MOTION_LABELS = MOTION_LABELS;
})(window);
