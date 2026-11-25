/**
 * 『東方キャラ立絵スタジオ』 ⇄ 『東方Project恋愛シミュレーター』 統合ブリッジ (renai_bridge.js)
 * スタジオで編集・パーツ組替・部位別色変え・スポイト色置換した立ち絵を、
 * ワンクリック（単一表情 または 全表情プリセット一括）で恋愛シミュレーターのヒロイン立ち絵へ即時反映する。
 */
(function () {
  "use strict";

  const params = new URLSearchParams(window.location.search);
  const initialCharName = (params.get("char_name") || "").trim();

  const PRESET_TO_EMOTION = [
    { match: "通常", emo: "normal", file: "normal(普通).png" },
    { match: "笑顔", emo: "smile", file: "smile(笑顔).png" },
    { match: "照れ", emo: "blush", file: "blush(赤面微笑).png" },
    { match: "怒り", emo: "angry", file: "angry(怒り).png" },
    { match: "困り", emo: "troubled", file: "troubled(困り).png" },
    { match: "泣き", emo: "sad", file: "sad(泣き).png" },
    { match: "驚き", emo: "surprised", file: "surprised(驚き).png" },
    { match: "強気", emo: "smug", file: "smug(不敵).png" },
    { match: "ジト目", emo: "question", file: "question(疑問).png" },
    { match: "青ざめ", emo: "yandere", file: "yandere(病み).png" },
  ];

  function getActiveCharName() {
    if (initialCharName) return initialCharName;
    const badge = document.getElementById("currentFileName");
    const raw = badge ? badge.textContent.trim() : "";
    return raw.replace(/\.(psd|psb)$/i, "").split(/[/_(（]/)[0].trim() || "カスタムキャラ";
  }

  async function registerImagesToSimulator(charName, items) {
    const res = await fetch("/local/tachie/register_portraits", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ char_name: charName, items }),
    });
    const data = await res.json();
    if (!data.ok) throw new Error(data.error || "立ち絵登録に失敗しました");
    if (window.parent && window.parent !== window) {
      window.parent.postMessage({ type: "renai_tachie_updated", char_name: charName, count: items.length }, "*");
    }
    return data;
  }

  function mountBridgeToolbar() {
    const headerRight = document.querySelector(".header-right");
    if (!headerRight) return;

    const wrap = document.createElement("div");
    wrap.style.cssText = "display:flex;align-items:center;gap:6px;background:rgba(139,92,246,0.22);border:1px solid rgba(192,132,252,0.55);padding:4px 8px;border-radius:8px;margin-right:6px;";

    const emoSel = document.createElement("select");
    emoSel.id = "renaiTargetEmotion";
    emoSel.style.cssText = "background:#0f172a;color:#f8fafc;border:1px solid #475569;border-radius:6px;padding:5px 6px;font-size:12px;";
    [
      ["normal(普通).png", "表情枠: 通常 (normal)"],
      ["smile(笑顔).png", "表情枠: 笑顔 (smile)"],
      ["blush(赤面微笑).png", "表情枠: 赤面・照れ (blush)"],
      ["question(疑問).png", "表情枠: 疑問 (question)"],
      ["angry(怒り).png", "表情枠: 怒り (angry)"],
      ["surprised(驚き).png", "表情枠: 驚き (surprised)"],
      ["sad(泣き).png", "表情枠: 悲しみ・泣き (sad)"],
      ["troubled(困り).png", "表情枠: 困り (troubled)"],
      ["smug(不敵).png", "表情枠: ドヤ・強気 (smug)"],
      ["yandere(病み).png", "表情枠: ヤンデレ (yandere)"],
    ].forEach(([val, label]) => {
      const o = document.createElement("option");
      o.value = val;
      o.textContent = label;
      emoSel.appendChild(o);
    });

    const btnSingle = document.createElement("button");
    btnSingle.className = "action-btn primary";
    btnSingle.style.cssText = "background:linear-gradient(135deg,#ec4899,#8b5cf6);border:none;font-size:12px;padding:6px 10px;";
    btnSingle.textContent = "🌸 この立ち絵をゲームに反映";
    btnSingle.onclick = async () => {
      const canvas = document.getElementById("previewCanvas");
      if (!canvas || !canvas.width) {
        alert("先に左ペインからキャラクターPSDを選択（またはPSDファイルをドロップ）してください。");
        return;
      }
      btnSingle.disabled = true;
      try {
        const cname = getActiveCharName();
        const dataUrl = canvas.toDataURL("image/png");
        await registerImagesToSimulator(cname, [{ filename: emoSel.value, data_url: dataUrl }]);
        btnSingle.textContent = "✅ ゲームへ反映完了！";
        setTimeout(() => { btnSingle.textContent = "🌸 この立ち絵をゲームに反映"; }, 1800);
      } catch (err) {
        alert(err.message);
      } finally {
        btnSingle.disabled = false;
      }
    };

    const btnBatch = document.createElement("button");
    btnBatch.className = "action-btn secondary";
    btnBatch.style.cssText = "background:#0284c7;color:#fff;border:none;font-size:12px;padding:6px 10px;";
    btnBatch.title = "現在の色変え・フィルターを維持したまま全表情差分を一括生成して恋愛シミュレーターへ登録します";
    btnBatch.textContent = "📦 全表情を色変え一括反映";
    btnBatch.onclick = async () => {
      const canvas = document.getElementById("previewCanvas");
      if (!canvas || !canvas.width) {
        alert("先に左ペインからキャラクターPSDを選択（またはPSDファイルをドロップ）してください。");
        return;
      }
      btnBatch.disabled = true;
      const origLabel = btnBatch.textContent;
      try {
        const cname = getActiveCharName();
        const cards = Array.from(document.querySelectorAll("#expressionPresetsGrid .preset-card"));
        const batchItems = [];
        for (const mapping of PRESET_TO_EMOTION) {
          const card = cards.find((c) => c.textContent.includes(mapping.match));
          if (card) {
            card.click();
            await new Promise((r) => setTimeout(r, 90));
            batchItems.push({ filename: mapping.file, data_url: canvas.toDataURL("image/png") });
          }
        }
        if (!batchItems.length) {
          batchItems.push({ filename: "normal(普通).png", data_url: canvas.toDataURL("image/png") });
        }
        btnBatch.textContent = `保存中 (${batchItems.length}枚)...`;
        await registerImagesToSimulator(cname, batchItems);
        btnBatch.textContent = `✅ 全${batchItems.length}表情を反映完了！`;
        setTimeout(() => { btnBatch.textContent = origLabel; }, 2200);
      } catch (err) {
        alert(err.message);
        btnBatch.textContent = origLabel;
      } finally {
        btnBatch.disabled = false;
      }
    };

    const btnResetCustom = document.createElement("button");
    btnResetCustom.className = "action-btn secondary";
    btnResetCustom.style.cssText = "font-size:11px;padding:6px 8px;";
    btnResetCustom.textContent = "元に戻す";
    btnResetCustom.title = "このキャラのカスタム登録立ち絵を解除して元の立ち絵に戻します";
    btnResetCustom.onclick = async () => {
      const cname = getActiveCharName();
      if (!confirm(`「${cname}」のカスタム登録立ち絵を解除して標準立ち絵に戻しますか？`)) return;
      await fetch("/local/tachie/clear_portraits", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ char_name: cname }),
      });
      if (window.parent && window.parent !== window) {
        window.parent.postMessage({ type: "renai_tachie_updated", char_name: cname, cleared: true }, "*");
      }
      alert("標準の立ち絵に戻しました。");
    };

    wrap.appendChild(emoSel);
    wrap.appendChild(btnSingle);
    wrap.appendChild(btnBatch);
    wrap.appendChild(btnResetCustom);
    headerRight.insertBefore(wrap, headerRight.firstChild);

    // 初期キャラ名が渡されている場合は検索欄へ自動セットして即時絞り込み
    if (initialCharName) {
      setTimeout(() => {
        const searchInp = document.getElementById("charSearchInput");
        if (searchInp) {
          const shortName = initialCharName.split(/[・\s]/)[0];
          searchInp.value = shortName;
          searchInp.dispatchEvent(new Event("input", { bubbles: true }));
        }
      }, 450);
    }
  }

  window.addEventListener("DOMContentLoaded", mountBridgeToolbar);
})();
