/**
 * 『東方キャラ立絵スタジオ』互換 リアルタイム立ち絵色変え＆スポイト特定色置換エンジン (tachie_color_live.js)
 * 特徴:
 *   - PSDがない環境（PNG立ち絵・内蔵スターター立ち絵）でも、雰囲気フィルター10種・色相/彩度/明度/コントラスト/色温度・
 *     スポイト特定色置換（陰影保持）をゲーム内でリアルタイム適用
 *   - GPU CSS filter で完結する調整はピクセル走査ゼロ（CPU 0.0%）、スポイト置換時も1度だけオフスクリーンCanvas変換してキャッシュ
 */
(function (global) {
  "use strict";

  const FILTER_PRESETS = {
    normal: { hue: 0, sat: 100, bri: 0, con: 0, temp: 0, css: "" },
    sunset: { hue: -6, sat: 118, bri: -4, con: 8, temp: 36, css: "sepia(0.22) saturate(1.25)" },
    moonlight: { hue: 10, sat: 88, bri: -10, con: 10, temp: -38, css: "" },
    darkness: { hue: -14, sat: 78, bri: -22, con: 24, temp: -20, css: "" },
    suntan: { hue: -4, sat: 115, bri: -8, con: 10, temp: 22, css: "sepia(0.16)" },
    sepia: { hue: 0, sat: 85, bri: 0, con: 5, temp: 25, css: "sepia(0.75)" },
    monochrome: { hue: 0, sat: 0, bri: 0, con: 12, temp: 0, css: "grayscale(1)" },
    cyber: { hue: 22, sat: 145, bri: 4, con: 18, temp: -28, css: "" },
    pastel: { hue: 4, sat: 82, bri: 12, con: -12, temp: 10, css: "" },
    horror: { hue: 95, sat: 130, bri: -18, con: 28, temp: -35, css: "" },
  };

  function defaultProfile() {
    return {
      filter: "normal",
      autoTimeTint: true,
      hue: 0,
      saturation: 100,
      brightness: 0,
      contrast: 0,
      temperature: 0,
      flipH: false,
      rules: [], // [{ srcHex, dstHex, tolerance: 42 }]
    };
  }

  function hexToRgb(hex) {
    const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex || "#ff0000");
    return m ? [parseInt(m[1], 16), parseInt(m[2], 16), parseInt(m[3], 16)] : [255, 0, 0];
  }

  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    let h = 0, s = 0;
    const l = (max + min) / 2;
    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch (max) {
        case r: h = (g - b) / d + (g < b ? 6 : 0); break;
        case g: h = (b - r) / d + 2; break;
        case b: h = (r - g) / d + 4; break;
      }
      h /= 6;
    }
    return [h, s, l];
  }

  function hslToRgb(h, s, l) {
    let r, g, b;
    if (s === 0) {
      r = g = b = l;
    } else {
      const hue2rgb = (p, q, t) => {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
      };
      const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      const p = 2 * l - q;
      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }
    return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
  }

  class LiveTachieColorEngine {
    constructor() {
      this._cacheKey = "";
      this._cachedBlobUrl = "";
      this._offCanvas = document.createElement("canvas");
    }

    clearCache() {
      if (this._cachedBlobUrl) {
        URL.revokeObjectURL(this._cachedBlobUrl);
        this._cachedBlobUrl = "";
      }
      this._cacheKey = "";
    }

    buildCssFilter(profile, sceneTimeOfDay = "day") {
      const p = Object.assign(defaultProfile(), profile || {});
      const base = FILTER_PRESETS[p.filter] || FILTER_PRESETS.normal;
      let hue = (Number(p.hue) || 0) + base.hue;
      let sat = ((Number(p.saturation) ?? 100) / 100) * (base.sat / 100) * 100;
      let bri = 100 + (Number(p.brightness) || 0) + base.bri;
      let con = 100 + (Number(p.contrast) || 0) + base.con;
      let temp = (Number(p.temperature) || 0) + base.temp;

      if (p.autoTimeTint && p.filter === "normal") {
        if (sceneTimeOfDay === "evening") {
          temp += 18;
          bri -= 3;
        } else if (sceneTimeOfDay === "night") {
          temp -= 18;
          bri -= 6;
        }
      }

      const parts = ["drop-shadow(0 8px 24px rgba(0, 0, 0, 0.32))"];
      if (base.css) parts.push(base.css);
      if (Math.abs(hue) > 0.2) parts.push(`hue-rotate(${hue.toFixed(1)}deg)`);
      if (Math.abs(sat - 100) > 0.5) parts.push(`saturate(${Math.max(0, sat).toFixed(1)}%)`);
      if (Math.abs(bri - 100) > 0.5) parts.push(`brightness(${Math.max(15, bri).toFixed(1)}%)`);
      if (Math.abs(con - 100) > 0.5) parts.push(`contrast(${Math.max(20, con).toFixed(1)}%)`);
      if (temp > 3) {
        parts.push(`sepia(${Math.min(0.45, temp / 180).toFixed(2)}) saturate(${(1 + temp / 260).toFixed(2)})`);
      } else if (temp < -3) {
        parts.push(`hue-rotate(${(temp * 0.22).toFixed(1)}deg)`);
      }
      return parts.join(" ");
    }

    async applyRulesToBlob(rawBlob, srcTag, profile) {
      const rules = (profile && Array.isArray(profile.rules)) ? profile.rules.filter((r) => r && r.srcHex && r.dstHex) : [];
      if (!rules.length || !rawBlob) return null;

      const sig = `${srcTag}|${JSON.stringify(rules)}`;
      if (sig === this._cacheKey && this._cachedBlobUrl) {
        return this._cachedBlobUrl;
      }

      const bmpUrl = URL.createObjectURL(rawBlob);
      try {
        const img = await new Promise((resolve, reject) => {
          const i = new Image();
          i.onload = () => resolve(i);
          i.onerror = reject;
          i.src = bmpUrl;
        });

        const w = img.naturalWidth || img.width;
        const h = img.naturalHeight || img.height;
        if (!w || !h) return null;

        this._offCanvas.width = w;
        this._offCanvas.height = h;
        const ctx = this._offCanvas.getContext("2d", { willReadFrequently: true });
        ctx.clearRect(0, 0, w, h);
        ctx.drawImage(img, 0, 0);

        const imgData = ctx.getImageData(0, 0, w, h);
        const d = imgData.data;

        const compiled = rules.map((r) => {
          const [sr, sg, sb] = hexToRgb(r.srcHex);
          const [dr, dg, db] = hexToRgb(r.dstHex);
          const [, , srcL] = rgbToHsl(sr, sg, sb);
          const [dstH, dstS, dstL] = rgbToHsl(dr, dg, db);
          const tolSq = Math.pow(Math.max(12, Math.min(130, Number(r.tolerance) || 48)) * 1.9, 2);
          return { sr, sg, sb, srcL, dstH, dstS, dstL, tolSq };
        });

        for (let i = 0; i < d.length; i += 4) {
          if (d[i + 3] < 16) continue;
          const pr = d[i], pg = d[i + 1], pb = d[i + 2];
          for (let k = 0; k < compiled.length; k++) {
            const rl = compiled[k];
            const distSq = (pr - rl.sr) * (pr - rl.sr) + (pg - rl.sg) * (pg - rl.sg) + (pb - rl.sb) * (pb - rl.sb);
            if (distSq <= rl.tolSq) {
              const blend = 1 - Math.pow(distSq / rl.tolSq, 0.75);
              const [, , curL] = rgbToHsl(pr, pg, pb);
              // 元の陰影差 (curL - srcL) を保持したままターゲット色へ滑らかに置換
              const targetL = Math.max(0.03, Math.min(0.97, rl.dstL + (curL - rl.srcL) * 0.92));
              const [nr, ng, nb] = hslToRgb(rl.dstH, rl.dstS, targetL);
              d[i] = Math.round(pr + (nr - pr) * blend);
              d[i + 1] = Math.round(pg + (ng - pg) * blend);
              d[i + 2] = Math.round(pb + (nb - pb) * blend);
              break;
            }
          }
        }

        ctx.putImageData(imgData, 0, 0);
        const outBlob = await new Promise((res) => this._offCanvas.toBlob(res, "image/png"));
        if (!outBlob) return null;
        if (this._cachedBlobUrl) URL.revokeObjectURL(this._cachedBlobUrl);
        this._cachedBlobUrl = URL.createObjectURL(outBlob);
        this._cacheKey = sig;
        return this._cachedBlobUrl;
      } finally {
        URL.revokeObjectURL(bmpUrl);
      }
    }
  }

  global.LiveTachieColorEngine = LiveTachieColorEngine;
  global.defaultTachieColorProfile = defaultProfile;
  global.TACHIE_FILTER_PRESETS = FILTER_PRESETS;
})(window);
