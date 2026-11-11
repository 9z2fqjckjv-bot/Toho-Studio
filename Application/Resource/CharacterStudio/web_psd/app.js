/**
 * 東方Project キャラクタースタジオ - フロントエンドアプリケーション
 * - PSDファイルの読み込み & レイヤー構造解析 (ag-psd)
 * - 表情差分パーツ（目・口・眉・漫符）の直感切り替え
 * - 表情ワンクリックプリセット
 * - リアルタイム色彩変換（色相・彩度・明度・コントラスト・部位別色変え・雰囲気フィルター）
 * - エクスポート（PNG / JPG / PXD / PSD）
 */

(function () {
  // ネイティブ Swift からの直接呼び出し用グローバル API
  window.tohoStudioSetCharacters = function(charList) {
    if (Array.isArray(charList)) {
      state.characterList = charList;
      if (elements.charCount) elements.charCount.textContent = charList.length;
      renderCharacterList();
      showToast(`${charList.length} 体のキャラクターを読み込みました`, "success");
    }
  };

  window.tohoStudioLoadPSDFromNative = function(base64Data, filename) {
    try {
      const binaryString = atob(base64Data);
      const len = binaryString.length;
      const bytes = new Uint8Array(len);
      for (let i = 0; i < len; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      parseAndLoadPsd(bytes.buffer, filename || "外部読み込み.psd");
    } catch (e) {
      console.error("tohoStudioLoadPSDFromNative error:", e);
      showToast("PSD読み込みエラー: " + e.message, "error");
    }
  };

  window.tohoStudioApplyToProject = function() {
    try {
      const canvas = document.getElementById("previewCanvas");
      if (canvas && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tohoStudio) {
        const dataUrl = canvas.toDataURL("image/png");
        window.webkit.messageHandlers.tohoStudio.postMessage({
          action: "applyToProject",
          characterName: state.currentCharName || "東方キャラ",
          dataUrl: dataUrl,
          width: canvas.width,
          height: canvas.height
        });
        showToast("TohoStudioプロジェクトに適用しました", "success");
      }
    } catch(e) {
      console.error("tohoStudioApplyToProject error:", e);
    }
  };

  'use strict';

  // ==================== アプリケーション状態 ====================
  const state = {
    psdData: null,          // ag-psd で読み込んだ元のPSDオブジェクト
    flatLayers: [],         // 全レイヤーのフラットリスト
    partGroups: {},         // 目、口、眉などの排他グループ
    toggleLayers: [],       // 漫符などのトグルレイヤー
    characterList: [],      // 内蔵東方キャラリスト
    currentCharName: '',    // 現在読み込み中のキャラ名
    currentFileName: '',    // 現在のファイル名
    
    // ビューポート状態
    zoom: 1.0,
    panX: 0,
    panY: 0,
    isDragging: false,
    dragStartX: 0,
    dragStartY: 0,
    flipH: false,
    bgMode: 'checker',

    // 色彩調整パラメーター
    color: {
      filter: 'normal',
      hue: 0,
      saturation: 100,
      brightness: 0,
      contrast: 0,
      temperature: 0,
      red: 0,
      green: 0,
      blue: 0,
      partTarget: 'all',
      partHue: 0,
      partSaturation: 100,
      partBrightness: 0
    },
    partColors: {}, // 部位・グループごとのカラー調整: { [targetKey]: { hue: 0, saturation: 100, brightness: 0 } }

    // 特定色置換 (カラーリプレイスメント)
    colorRules: [],
    isEyedropperActive: false,
    activeEyedropperRuleId: null,
    hoverSampleColor: null,
    rawCompositeCanvas: null,

    // エクスポート設定
    export: {
      format: 'png',
      scale: 1.0,
      jpgBg: '#ffffff',
      jpgQuality: 0.95,
      filename: '東方キャラ_立絵'
    }
  };

  // ==================== DOM要素の参照 ====================
  const elements = {
    // ヘッダー
    currentFileBadge: document.getElementById('currentFileBadge'),
    currentFileName: document.getElementById('currentFileName'),
    currentFileDims: document.getElementById('currentFileDims'),
    zoomLevelDisplay: document.getElementById('zoomLevelDisplay'),
    btnZoomIn: document.getElementById('btnZoomIn'),
    btnZoomOut: document.getElementById('btnZoomOut'),
    btnZoomFit: document.getElementById('btnZoomFit'),
    btnZoom100: document.getElementById('btnZoom100'),
    bgBtns: document.querySelectorAll('.bg-btn'),
    btnOpenLocalPSD: document.getElementById('btnOpenLocalPSD'),
    psdFileInput: document.getElementById('psdFileInput'),
    btnExportQuick: document.getElementById('btnExportQuick'),

    // タブ
    tabBtns: document.querySelectorAll('.tab-btn'),
    tabPanes: document.querySelectorAll('.tab-pane'),

    // キャラクター一覧
    charSearchInput: document.getElementById('charSearchInput'),
    charCount: document.getElementById('charCount'),
    btnRefreshChars: document.getElementById('btnRefreshChars'),
    characterList: document.getElementById('characterList'),

    // 表情パーツ & プリセット
    expressionPartsContainer: document.getElementById('expressionPartsContainer'),
    btnResetParts: document.getElementById('btnResetParts'),
    expressionPresetsGrid: document.getElementById('expressionPresetsGrid'),
    charEmbeddedPresetsGrid: document.getElementById('charEmbeddedPresetsGrid'),

    // レイヤーツリー
    layerTreeContainer: document.getElementById('layerTreeContainer'),
    btnExpandAllLayers: document.getElementById('btnExpandAllLayers'),
    btnCollapseAllLayers: document.getElementById('btnCollapseAllLayers'),

    // キャンバス
    canvasViewport: document.getElementById('canvasViewport'),
    canvasContainer: document.getElementById('canvasContainer'),
    previewCanvas: document.getElementById('previewCanvas'),
    dropZoneOverlay: document.getElementById('dropZoneOverlay'),
    statusText: document.getElementById('statusText'),
    btnFlipH: document.getElementById('btnFlipH'),
    btnFitWindow: document.getElementById('btnFitWindow'),

    // 色彩調整
    filterChips: document.querySelectorAll('.filter-chip'),
    btnResetFilter: document.getElementById('btnResetFilter'),
    btnResetColorSliders: document.getElementById('btnResetColorSliders'),
    sliderHue: document.getElementById('sliderHue'),
    sliderSaturation: document.getElementById('sliderSaturation'),
    sliderBrightness: document.getElementById('sliderBrightness'),
    sliderContrast: document.getElementById('sliderContrast'),
    sliderTemperature: document.getElementById('sliderTemperature'),
    sliderRed: document.getElementById('sliderRed'),
    sliderGreen: document.getElementById('sliderGreen'),
    sliderBlue: document.getElementById('sliderBlue'),
    valHue: document.getElementById('valHue'),
    valSaturation: document.getElementById('valSaturation'),
    valBrightness: document.getElementById('valBrightness'),
    valContrast: document.getElementById('valContrast'),
    valTemperature: document.getElementById('valTemperature'),
    valRed: document.getElementById('valRed'),
    valGreen: document.getElementById('valGreen'),
    valBlue: document.getElementById('valBlue'),
    partColorTargetSelect: document.getElementById('partColorTargetSelect'),
    btnResetPartColor: document.getElementById('btnResetPartColor'),
    sliderPartHue: document.getElementById('sliderPartHue'),
    valPartHue: document.getElementById('valPartHue'),
    sliderPartSaturation: document.getElementById('sliderPartSaturation'),
    valPartSaturation: document.getElementById('valPartSaturation'),
    sliderPartBrightness: document.getElementById('sliderPartBrightness'),
    valPartBrightness: document.getElementById('valPartBrightness'),

    // 特定色置換 (カラーリプレイスメント)
    btnEyedropper: document.getElementById('btnEyedropper'),
    eyedropperHint: document.getElementById('eyedropperHint'),
    btnAddColorRule: document.getElementById('btnAddColorRule'),
    colorRulesList: document.getElementById('colorRulesList'),
    eyedropperTooltip: document.getElementById('eyedropperTooltip'),
    eyedropperTooltipPreview: document.getElementById('eyedropperTooltipPreview'),
    eyedropperTooltipText: document.getElementById('eyedropperTooltipText'),

    // エクスポート
    exportFormatRadios: document.querySelectorAll('input[name="exportFormat"]'),
    formatCards: document.querySelectorAll('.format-card'),
    jpgOptionsBox: document.getElementById('jpgOptionsBox'),
    jpgBgColor: document.getElementById('jpgBgColor'),
    btnJpgWhite: document.getElementById('btnJpgWhite'),
    btnJpgBlack: document.getElementById('btnJpgBlack'),
    btnJpgGreen: document.getElementById('btnJpgGreen'),
    jpgQuality: document.getElementById('jpgQuality'),
    jpgQualityVal: document.getElementById('jpgQualityVal'),
    scaleBtns: document.querySelectorAll('.scale-btn'),
    exportDimsPreview: document.getElementById('exportDimsPreview'),
    exportFilenameInput: document.getElementById('exportFilenameInput'),
    exportExtBadge: document.getElementById('exportExtBadge'),
    btnDownloadExport: document.getElementById('btnDownloadExport'),
    btnSaveToMaterials: document.getElementById('btnSaveToMaterials'),
    btnBatchExportExpressions: document.getElementById('btnBatchExportExpressions'),

    // トースト
    toastContainer: document.getElementById('toastContainer')
  };

  const ctx = elements.previewCanvas.getContext('2d');

  // ==================== 初期化 ====================
  function init() {
    setupEventListeners();
    initPresetsUI();
    fetchCharacters();
  }

  // ==================== イベントリスナー設定 ====================
  function setupEventListeners() {
    // タブ切り替え
    elements.tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const targetTab = btn.getAttribute('data-tab');
        const parentSidebar = btn.closest('.sidebar');
        
        parentSidebar.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        parentSidebar.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

        btn.classList.add('active');
        const pane = document.getElementById(targetTab);
        if (pane) pane.classList.add('active');
      });
    });

    // ファイル選択
    elements.btnOpenLocalPSD.addEventListener("click", () => {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tohoStudio) {
        window.webkit.messageHandlers.tohoStudio.postMessage({ action: "openLocalPSD" });
      } else {
        elements.psdFileInput.click();
      }
    });
    elements.psdFileInput.addEventListener('change', handleFileSelect);

    // ドラッグ＆ドロップ
    window.addEventListener('dragover', e => {
      e.preventDefault();
      elements.dropZoneOverlay.classList.add('drag-over');
    });
    window.addEventListener('dragleave', e => {
      if (e.relatedTarget === null) {
        elements.dropZoneOverlay.classList.remove('drag-over');
      }
    });
    window.addEventListener('drop', e => {
      e.preventDefault();
      elements.dropZoneOverlay.classList.remove('drag-over');
      if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
        loadPsdFromFile(e.dataTransfer.files[0]);
      }
    });

    // ビューポートズーム・パン
    elements.btnZoomIn.addEventListener('click', () => setZoom(state.zoom * 1.25));
    elements.btnZoomOut.addEventListener('click', () => setZoom(state.zoom / 1.25));
    elements.btnZoomFit.addEventListener('click', fitToViewport);
    elements.btnZoom100.addEventListener('click', () => setZoom(1.0));
    elements.btnFitWindow.addEventListener('click', fitToViewport);
    elements.btnFlipH.addEventListener('click', toggleFlipH);

    window.addEventListener('resize', () => {
      if (state.psdData) {
        fitToViewport();
      }
    });

    if (window.ResizeObserver && elements.canvasViewport) {
      const ro = new ResizeObserver(() => {
        if (state.psdData) {
          fitToViewport();
        }
      });
      ro.observe(elements.canvasViewport);
    }

    // マウスホイールによるズーム
    elements.canvasViewport.addEventListener('wheel', e => {
      if (e.ctrlKey || e.metaKey) {
        e.preventDefault();
        const delta = e.deltaY > 0 ? 0.9 : 1.1;
        setZoom(state.zoom * delta);
      }
    }, { passive: false });

    // パン（ドラッグ移動） & スポイト
    elements.canvasContainer.addEventListener('mousedown', e => {
      if (state.isEyedropperActive) {
        handleEyedropperSample(e);
        return;
      }
      if (e.button === 0) { // 左クリック
        state.isDragging = true;
        state.dragStartX = e.clientX - state.panX;
        state.dragStartY = e.clientY - state.panY;
      }
    });
    window.addEventListener('mousemove', e => {
      if (state.isEyedropperActive) {
        handleEyedropperHover(e);
        return;
      }
      if (state.isDragging) {
        state.panX = e.clientX - state.dragStartX;
        state.panY = e.clientY - state.dragStartY;
        applyCanvasTransform();
      }
    });
    window.addEventListener('mouseup', () => {
      state.isDragging = false;
    });
    window.addEventListener('keydown', e => {
      if (e.key === 'Escape' && state.isEyedropperActive) {
        toggleEyedropper(false);
      }
    });
    elements.canvasViewport.addEventListener('mouseleave', () => {
      if (state.isEyedropperActive && elements.eyedropperTooltip) {
        elements.eyedropperTooltip.style.display = 'none';
      }
    });

    // 背景切り替え
    elements.bgBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        elements.bgBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const bg = btn.getAttribute('data-bg');
        state.bgMode = bg;
        elements.canvasContainer.className = `canvas-container bg-${bg}`;
      });
    });

    // キャラクター検索 & リフレッシュ
    elements.charSearchInput.addEventListener('input', renderCharacterList);
    elements.btnRefreshChars.addEventListener('click', fetchCharacters);

    // パーツリセット
    elements.btnResetParts.addEventListener('click', resetPartsToInitial);

    // 色彩フィルター
    elements.filterChips.forEach(chip => {
      chip.addEventListener('click', () => {
        elements.filterChips.forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        applyFilterPreset(chip.getAttribute('data-filter'));
      });
    });

    // 色彩スライダー
    setupSlider(elements.sliderHue, elements.valHue, v => `${v}°`, v => state.color.hue = parseInt(v));
    setupSlider(elements.sliderSaturation, elements.valSaturation, v => `${v}%`, v => state.color.saturation = parseInt(v));
    setupSlider(elements.sliderBrightness, elements.valBrightness, v => `${v}%`, v => state.color.brightness = parseInt(v));
    setupSlider(elements.sliderContrast, elements.valContrast, v => `${v}%`, v => state.color.contrast = parseInt(v));
    setupSlider(elements.sliderTemperature, elements.valTemperature, v => v, v => state.color.temperature = parseInt(v));
    setupSlider(elements.sliderRed, elements.valRed, v => v, v => state.color.red = parseInt(v));
    setupSlider(elements.sliderGreen, elements.valGreen, v => v, v => state.color.green = parseInt(v));
    setupSlider(elements.sliderBlue, elements.valBlue, v => v, v => state.color.blue = parseInt(v));

    // 部位別スライダー
    elements.partColorTargetSelect.addEventListener('change', e => {
      state.color.partTarget = e.target.value;
      syncPartSlidersUI();
      renderComposite();
    });
    setupPartSlider(elements.sliderPartHue, elements.valPartHue, v => `${v}°`, (s, v) => s.hue = parseInt(v));
    setupPartSlider(elements.sliderPartSaturation, elements.valPartSaturation, v => `${v}%`, (s, v) => s.saturation = parseInt(v));
    setupPartSlider(elements.sliderPartBrightness, elements.valPartBrightness, v => `${v}%`, (s, v) => s.brightness = parseInt(v));

    if (elements.btnResetPartColor) {
      elements.btnResetPartColor.addEventListener('click', resetPartColor);
    }

    elements.btnResetFilter.addEventListener('click', () => applyFilterPreset('normal'));
    elements.btnResetColorSliders.addEventListener('click', resetColorSliders);

    // エクスポート設定
    elements.exportFormatRadios.forEach(radio => {
      radio.addEventListener('change', () => {
        state.export.format = radio.value;
        elements.formatCards.forEach(c => c.classList.remove('active'));
        radio.closest('.format-card').classList.add('active');
        
        elements.jpgOptionsBox.style.display = radio.value === 'jpg' ? 'flex' : 'none';
        elements.exportExtBadge.textContent = `.${radio.value}`;
        updateDimsPreview();
      });
    });

    elements.scaleBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        elements.scaleBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        state.export.scale = parseFloat(btn.getAttribute('data-scale'));
        updateDimsPreview();
      });
    });

    elements.jpgQuality.addEventListener('input', e => {
      state.export.jpgQuality = parseInt(e.target.value) / 100;
      elements.jpgQualityVal.textContent = `${e.target.value}%`;
    });

    elements.jpgBgColor.addEventListener('input', e => {
      state.export.jpgBg = e.target.value;
    });
    elements.btnJpgWhite.addEventListener('click', () => { elements.jpgBgColor.value = '#ffffff'; state.export.jpgBg = '#ffffff'; });
    elements.btnJpgBlack.addEventListener('click', () => { elements.jpgBgColor.value = '#000000'; state.export.jpgBg = '#000000'; });
    elements.btnJpgGreen.addEventListener('click', () => { elements.jpgBgColor.value = '#00ff00'; state.export.jpgBg = '#00ff00'; });

    elements.exportFilenameInput.addEventListener('input', e => {
      state.export.filename = e.target.value.trim() || '東方キャラ_立絵';
    });

    elements.btnExportQuick.addEventListener('click', () => {
      // エクスポートタブに切り替えてエクスポート実行
      const exportTabBtn = document.querySelector('.tab-btn[data-tab="tab-export"]');
      if (exportTabBtn) exportTabBtn.click();
      handleExport(false);
    });

    elements.btnDownloadExport.addEventListener('click', () => handleExport(false));
    elements.btnSaveToMaterials.addEventListener('click', () => handleExport(true));
    elements.btnBatchExportExpressions.addEventListener('click', handleBatchExport);

    // 特定色置換 (カラーリプレイスメント)
    if (elements.btnEyedropper) {
      elements.btnEyedropper.addEventListener('click', toggleEyedropper);
    }
    if (elements.btnAddColorRule) {
      elements.btnAddColorRule.addEventListener('click', () => addColorRule());
    }
  }

  function setupSlider(slider, valDisplay, formatFn, updateStateFn) {
    if (!slider) return;
    slider.addEventListener('input', e => {
      if (valDisplay) valDisplay.textContent = formatFn(e.target.value);
      updateStateFn(e.target.value);
      renderComposite();
    });
  }

  function setupPartSlider(slider, valDisplay, formatFn, updateSettingFn) {
    if (!slider) return;
    slider.addEventListener('input', e => {
      if (valDisplay) valDisplay.textContent = formatFn(e.target.value);
      const target = state.color.partTarget || 'all';
      if (!state.partColors[target]) {
        state.partColors[target] = { hue: 0, saturation: 100, brightness: 0 };
      }
      updateSettingFn(state.partColors[target], e.target.value);
      renderComposite();
    });
  }

  // ==================== キャラクター一覧取得 ====================
  async function fetchCharacters() {
    elements.characterList.innerHTML = '<div class="loading-spinner">キャラクター素材をスキャン中...</div>';
    try {
      const res = await fetch('/api/characters');
      const data = await res.json();
      if (data.success) {
        state.characterList = data.characters;
        elements.charCount.textContent = data.count;
        renderCharacterList();
        showToast(`${data.count} 体の東方キャラクターPSDを検出しました`, 'success');
      } else {
        elements.characterList.innerHTML = `<div class="empty-state">エラー: ${data.error}</div>`;
      }
    } catch (e) {
      elements.characterList.innerHTML = `<div class="empty-state">キャラクター取得に失敗しました。<br>PSDを開くボタンからファイルを選択してください。</div>`;
    }
  }

  function renderCharacterList() {
    const query = elements.charSearchInput.value.trim().toLowerCase();
    const filtered = state.characterList.filter(c => {
      if (!query) return true;
      return (c.name && c.name.toLowerCase().includes(query)) || 
             (c.variation && c.variation.toLowerCase().includes(query)) ||
             (c.category && c.category.toLowerCase().includes(query));
    });

    if (filtered.length === 0) {
      elements.characterList.innerHTML = '<div class="empty-state">該当するキャラクターが見つかりません</div>';
      return;
    }

    elements.characterList.innerHTML = '';
    filtered.forEach(char => {
      const item = document.createElement('div');
      item.className = 'char-item';
      if (state.currentCharName === char.name && state.currentFileName === char.filename) {
        item.classList.add('active');
      }

      const catBadge = (char.category && char.category !== '東方Project' && char.category !== 'その他') 
        ? `<span style="font-size: 9px; background: rgba(255, 71, 133, 0.2); color: var(--accent-color); padding: 1px 5px; border-radius: 4px; margin-right: 4px;">${escapeHtml(char.category)}</span>` 
        : '';

      item.innerHTML = `
        <div class="char-item-info">
          <div style="display: flex; align-items: center;">
            ${catBadge}
            <span class="char-item-name">${escapeHtml(char.name)}</span>
          </div>
          <span class="char-item-var">${escapeHtml(char.variation)}</span>
        </div>
        <span class="char-item-size">${char.size_str}</span>
      `;

      item.addEventListener('click', () => loadCharacterPsd(char));
      elements.characterList.appendChild(item);
    });
  }

  // ==================== PSD読み込み ====================
  async function loadCharacterPsd(char) {
    setStatus(`読み込み中: ${char.name} (${char.variation})...`);
    try {
      const res = await fetch(`/api/psd_file?path=${encodeURIComponent(char.rel_path)}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const buffer = await res.arrayBuffer();
      
      state.currentCharName = char.name;
      state.currentFileName = char.filename;
      elements.exportFilenameInput.value = `${char.name}_${char.variation.replace(/[\/\s]/g, '_')}`;

      parseAndLoadPsd(buffer, `${char.name} - ${char.variation}`);
      renderCharacterList();
    } catch (e) {
      showToast(`PSD読み込み失敗: ${e.message}`, 'error');
      setStatus('読み込み失敗');
    }
  }

  function handleFileSelect(e) {
    if (e.target.files && e.target.files[0]) {
      loadPsdFromFile(e.target.files[0]);
    }
  }

  function loadPsdFromFile(file) {
    setStatus(`ファイル読み込み中: ${file.name}...`);
    const reader = new FileReader();
    reader.onload = e => {
      const buffer = e.target.result;
      state.currentCharName = file.name.replace(/\.[^/.]+$/, '');
      state.currentFileName = file.name;
      elements.exportFilenameInput.value = state.currentCharName;
      parseAndLoadPsd(buffer, file.name);
    };
    reader.readAsArrayBuffer(file);
  }

  function parseAndLoadPsd(buffer, displayName) {
    try {
      if (!window.agPsd) {
        throw new Error('PSDパーサーライブラリが読み込まれていません');
      }

      // ag-psd でパース (各レイヤーのcanvasまたはimageDataを取得)
      const psd = window.agPsd.readPsd(buffer, {
        useImageData: true,
        skipCompositeImageData: false
      });

      state.psdData = psd;
      elements.previewCanvas.width = psd.width;
      elements.previewCanvas.height = psd.height;
      elements.previewCanvas.style.width = psd.width + 'px';
      elements.previewCanvas.style.height = psd.height + 'px';
      if (elements.canvasContainer) {
        elements.canvasContainer.style.width = psd.width + 'px';
        elements.canvasContainer.style.height = psd.height + 'px';
      }

      // ヘッダー情報更新
      elements.currentFileBadge.style.display = 'flex';
      elements.currentFileName.textContent = displayName;
      elements.currentFileDims.textContent = `(${psd.width} × ${psd.height} px)`;
      updateDimsPreview();

      // レイヤーのフラット化とタグ構造解析
      state.partColors = {};
      state.faceBounds = detectFaceBounds(psd);
      analyzeLayerStructure(psd);

      // UIの構築
      buildExpressionPartsUI();
      buildLayerTreeUI();
      populatePartColorSelect();
      checkEmbeddedPresets(psd);

      // 表情タブをアクティブにする
      const exprTabBtn = document.querySelector('.tab-btn[data-tab="tab-expressions"]');
      if (exprTabBtn) exprTabBtn.click();

      // 初回レンダリング & フィット (タブ切り替え・レイアウト確定後に確実に再フィッティング)
      renderComposite();
      fitToViewport();
      setTimeout(fitToViewport, 50);

      setStatus(`読み込み完了: ${displayName}`);
      showToast(`${displayName} を読み込みました (${psd.width}×${psd.height})`, 'success');

    } catch (e) {
      console.error(e);
      showToast(`PSD解析エラー: ${e.message}`, 'error');
      setStatus('解析エラー');
    }
  }

  // 親グループを表示状態にするヘルパー
  function ensureParentsVisible(node) {
    let curr = node;
    while (curr) {
      curr.hidden = false;
      curr = curr._parent;
    }
  }

  // 親グループの可視性を子要素の表示状態に合わせて同期
  function syncEffectParentVisibility(node) {
    let curr = node._parent;
    while (curr) {
      if (curr.children && curr.children.length > 0) {
        const anyChildVisible = curr.children.some(c => !c.hidden);
        curr.hidden = !anyChildVisible;
      }
      curr = curr._parent;
    }
  }

  // ==================== レイヤー構造解析 ====================
  function analyzeLayerStructure(psd) {
    state.flatLayers = [];
    state.partGroups = {};
    state.toggleLayers = [];

    let layerIdCounter = 1;

    function walk(node, parentNode = null, parentPath = []) {
      if (!node) return;

      node._parent = parentNode;
      const layerId = `layer_${layerIdCounter++}`;
      node._layerId = layerId;
      node._initialVisible = !node.hidden;

      const currentPath = [...parentPath, node.name || ''];
      node._fullPath = currentPath.join(' / ');

      // グループノード
      if (node.children && node.children.length > 0) {
        const groupName = (node.name || '').trim();
        const cleanGroupName = groupName.replace(/^[!*]/, '').trim();

        // 子要素にさらにグループ（フォルダ）を持っているか
        const hasChildGroups = node.children.some(c => c.children && c.children.length > 0);
        const isSampleGroup = groupName.includes('表情サンプル') || groupName.includes('サンプル');

        // 排他パーツグループの判定:
        // 子要素にグループを持たず直接描画レイヤーを持ち、かつ名前が ! で始まる、または目・口・眉・体・服・ポーズ等
        const isPartGroup = !hasChildGroups && !isSampleGroup && (
          groupName.startsWith('!') || 
          /^(目|口|眉|体|服|衣装|ポーズ|前髪|後ろ髪|羽|腕|装飾|頭)/.test(cleanGroupName)
        );

        if (isPartGroup) {
          state.partGroups[cleanGroupName] = {
            id: layerId,
            node: node,
            name: cleanGroupName,
            options: []
          };

          node.children.forEach(child => {
            child._parent = node;
            child._layerId = `layer_${layerIdCounter++}`;
            child._initialVisible = !child.hidden;
            child._fullPath = [...currentPath, child.name || ''].join(' / ');
            state.flatLayers.push(child);

            const optName = (child.name || '').replace(/^[!*]/, '').trim();
            state.partGroups[cleanGroupName].options.push({
              id: child._layerId,
              name: optName,
              node: child
            });
          });
        } else {
          // コンテナグループ (例: !表情, 顔色, 感情マーク等)
          node.children.forEach(child => {
            walk(child, node, currentPath);
          });
        }
      } else {
        // リーフノード (漫符、感情マーク、エフェクトなど)
        state.flatLayers.push(node);
        const cleanName = (node.name || '').replace(/^[!*]/, '').trim();
        const fullPath = node._fullPath || '';

        // 漫符・感情・エフェクトの3種類をスマート分類
        let cat = 'その他エフェクト';
        if (/漫符|感情マーク|マーク|記号|音符|ハート|いらっ|気づき|うきうき|どんより|怒り|！|？/.test(fullPath)) {
          cat = '漫符';
        } else if (/涙|汗/.test(fullPath)) {
          cat = '感情';
        } else if (/顔色|赤面|照れ|青ざめ|顔影|影|エフェクト/.test(fullPath)) {
          cat = 'エフェクト';
        }

        state.toggleLayers.push({
          id: layerId,
          name: cleanName,
          category: cat,
          fullPath: fullPath,
          node: node
        });
      }
    }

    if (psd.children) {
      psd.children.forEach(child => walk(child, null));
    }

    // 初期状態での親グループ可視性同期
    state.toggleLayers.forEach(item => {
      if (!item.node.hidden) {
        syncEffectParentVisibility(item.node);
      }
    });
  }

  // ==================== 表情パーツ UI 構築 ====================
  function buildExpressionPartsUI() {
    elements.expressionPartsContainer.innerHTML = '';

    const groupNames = Object.keys(state.partGroups);
    if (groupNames.length === 0 && state.toggleLayers.length === 0) {
      elements.expressionPartsContainer.innerHTML = '<div class="empty-state">切り替え可能な表情パーツが見つかりませんでした</div>';
      return;
    }

    // 1. 排他パーツグループ（目、口、眉、体など）
    groupNames.forEach(groupName => {
      const grp = state.partGroups[groupName];
      if (!grp.options || grp.options.length === 0) return;

      const card = document.createElement('div');
      card.className = 'part-group-card';

      const title = document.createElement('div');
      title.className = 'part-group-title';
      title.innerHTML = `<span>${escapeHtml(groupName)}</span><span style="font-size: 10px; color: var(--text-muted);">${grp.options.length} 差分</span>`;
      card.appendChild(title);

      const grid = document.createElement('div');
      grid.className = 'part-options-grid';

      grp.options.forEach(opt => {
        const btn = document.createElement('button');
        btn.className = 'part-btn';
        btn.textContent = opt.name;
        btn.title = opt.name;
        if (!opt.node.hidden) {
          btn.classList.add('active');
        }

        btn.addEventListener('click', () => {
          // 排他選択: 他のオプションを非表示にし、これだけ表示
          grp.options.forEach(o => {
            o.node.hidden = true;
          });
          opt.node.hidden = false;
          // 親グループチェーン全体を表示状態にする
          ensureParentsVisible(opt.node);

          grid.querySelectorAll('.part-btn').forEach(b => b.classList.remove('active'));
          btn.classList.add('active');

          renderComposite();
          updateLayerTreeStates();
        });

        grid.appendChild(btn);
      });

      card.appendChild(grid);
      elements.expressionPartsContainer.appendChild(card);
    });

    // 2. 漫符・感情・エフェクトの3種類をカテゴリ別にUI構築
    const categories = [
      { key: '漫符', title: '💬 漫符（マーク・感情記号）' },
      { key: '感情', title: '💧 感情（涙・汗）' },
      { key: 'エフェクト', title: '✨ 顔色・エフェクト（赤面・青ざめ・影）' },
      { key: 'その他エフェクト', title: '🌟 その他の装飾・エフェクト' }
    ];

    categories.forEach(catDef => {
      const items = state.toggleLayers.filter(l => l.category === catDef.key);
      if (items.length === 0) return;

      const card = document.createElement('div');
      card.className = 'part-group-card';

      const visibleCount = items.filter(i => !i.node.hidden).length;

      const titleRow = document.createElement('div');
      titleRow.className = 'part-group-title';
      titleRow.innerHTML = `
        <span>${catDef.title}</span>
        <div style="display: flex; align-items: center; gap: 8px;">
          <span class="active-count-badge" style="font-size: 10px; color: var(--accent-color);">${visibleCount > 0 ? `${visibleCount} 個表示中` : 'OFF'}</span>
          <button class="text-btn clear-cat-btn" style="font-size: 10px; padding: 2px 4px;">全解除</button>
        </div>
      `;
      card.appendChild(titleRow);

      const clearBtn = titleRow.querySelector('.clear-cat-btn');
      clearBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        items.forEach(it => {
          it.node.hidden = true;
          syncEffectParentVisibility(it.node);
        });
        buildExpressionPartsUI();
        renderComposite();
        updateLayerTreeStates();
      });

      items.forEach(item => {
        const row = document.createElement('div');
        row.className = 'part-toggle-row';
        if (!item.node.hidden) row.classList.add('active');

        const isDummy = (item.node.imageData && item.node.imageData.width <= 1 && item.node.imageData.height <= 1) ||
                        (item.node.right !== undefined && (item.node.right - item.node.left <= 1) && (item.node.bottom - item.node.top <= 1));

        row.innerHTML = `
          <div style="display: flex; align-items: center;">
            <span class="part-toggle-name">${escapeHtml(item.name)}</span>
            ${isDummy ? '<span style="font-size: 10px; color: var(--text-muted); margin-left: 6px;">(素材なし)</span>' : ''}
          </div>
          <div class="toggle-switch"></div>
        `;

        row.addEventListener('click', () => {
          if (isDummy) {
            showToast(`「${item.name}」はこのPSD素材内に画像データがありません（空レイヤー）`, 'info');
          }
          item.node.hidden = !item.node.hidden;
          // 親グループ（顔色、涙・汗、感情マーク等）の表示状態を即座に完全同期！
          syncEffectParentVisibility(item.node);

          row.classList.toggle('active', !item.node.hidden);

          // タイトルバッジをリアルタイム更新
          const newVisibleCount = items.filter(i => !i.node.hidden).length;
          const badge = card.querySelector('.active-count-badge');
          if (badge) {
            badge.textContent = newVisibleCount > 0 ? `${newVisibleCount} 個表示中` : 'OFF';
          }

          renderComposite();
          updateLayerTreeStates();
        });

        card.appendChild(row);
      });

      elements.expressionPartsContainer.appendChild(card);
    });
  }

  function resetPartsToInitial() {
    if (!state.psdData) return;
    
    function resetNode(node) {
      if (!node) return;
      if (node._initialVisible !== undefined) {
        node.hidden = !node._initialVisible;
      }
      if (node.children) {
        node.children.forEach(resetNode);
      }
    }
    resetNode(state.psdData);

    state.toggleLayers.forEach(item => {
      syncEffectParentVisibility(item.node);
    });

    buildExpressionPartsUI();
    updateLayerTreeStates();
    renderComposite();
    showToast('表情パーツを初期状態に戻しました', 'success');
  }

  // ==================== 表情ワンクリックプリセット ====================
  const PRESETS_DEF = [
    { name: '通常', emoji: '🙂', eyes: ['普通', '普通目', '通常'], mouth: ['閉じ', '口閉じ', '普通'], brow: ['普通', '通常'], effect: [] },
    { name: '笑顔', emoji: '😄', eyes: ['笑い', '笑い目', '目閉じ'], mouth: ['笑い', '口閉じ笑い', '小口笑い'], brow: ['笑う', '普通'], effect: [] },
    { name: '大笑い', emoji: '😆', eyes: ['笑い', '目閉じ'], mouth: ['大口笑い', '大口開け', 'ワハハ'], brow: ['笑う'], effect: ['うきうき'] },
    { name: '怒り', emoji: '😠', eyes: ['見開き', '普通目', '強気'], mouth: ['むっ', '口閉じ（むっ）', 'への字'], brow: ['怒り', '強気'], effect: ['いらっ', '怒り'] },
    { name: '困り・焦り', emoji: '😰', eyes: ['普通目', '見開き'], mouth: ['あわわ', '小口開け'], brow: ['困る', '泣く'], effect: ['汗', '困り'] },
    { name: '泣き顔', emoji: '😭', eyes: ['目閉じ', 'ジト目', '見開き'], mouth: ['あわわ', 'への字'], brow: ['困る', '泣く'], effect: ['涙', '涙、汗'] },
    { name: '驚き', emoji: '😲', eyes: ['見開き目', '見開き'], mouth: ['小口開け', '大口開け'], brow: ['驚く', '困る'], effect: ['気づき'] },
    { name: 'ジト目・呆れ', emoji: '😒', eyes: ['ジト目', '呆れ'], mouth: ['口閉じ', '口閉じ（むっ）'], brow: ['強気', '普通'], effect: ['どんより'] },
    { name: '照れ笑い', emoji: '🥰', eyes: ['笑い', '目閉じ', '普通目'], mouth: ['小口笑い', '口閉じ笑い'], brow: ['笑う'], effect: ['赤面', '照れ', 'ハート'] },
    { name: '目閉じ・眠り', emoji: '😴', eyes: ['目閉じ', '眠気', '寝顔'], mouth: ['口閉じ', '口閉じ（むっ）'], brow: ['普通', '笑う'], effect: [] },
    { name: 'やられ・青ざめ', emoji: '😵', eyes: ['目閉じ', 'ぐるぐる', '見開き'], mouth: ['あわわ', 'への字'], brow: ['困る', '泣く'], effect: ['顔影', '青ざめ', '汗'] },
    { name: '強気・睨み', emoji: '😏', eyes: ['普通目', 'ジト目'], mouth: ['口閉じ笑い', 'むっ'], brow: ['強気', '怒り'], effect: [] }
  ];

  function initPresetsUI() {
    elements.expressionPresetsGrid.innerHTML = '';
    PRESETS_DEF.forEach(preset => {
      const card = document.createElement('div');
      card.className = 'preset-card';
      card.innerHTML = `
        <span class="preset-emoji">${preset.emoji}</span>
        <span class="preset-name">${escapeHtml(preset.name)}</span>
      `;
      card.addEventListener('click', () => applyExpressionPreset(preset, card));
      elements.expressionPresetsGrid.appendChild(card);
    });
  }

  function applyExpressionPreset(preset, cardEl) {
    if (!state.psdData) {
      showToast('先にPSDファイルを読み込んでください', 'error');
      return;
    }

    // サンプル表情グループがあれば非表示にして通常パーツを表示優先にする
    function hideSampleGroups(node) {
      if (!node) return;
      if (node.name && (node.name.includes('表情サンプル') || node.name.includes('サンプル'))) {
        node.hidden = true;
      }
      if (node.children) node.children.forEach(hideSampleGroups);
    }
    hideSampleGroups(state.psdData);

    // 目、口、眉グループを探してマッチするものを選択
    Object.keys(state.partGroups).forEach(groupName => {
      const grp = state.partGroups[groupName];
      let targetNames = [];
      if (/目/.test(groupName)) targetNames = preset.eyes;
      else if (/口/.test(groupName)) targetNames = preset.mouth;
      else if (/眉/.test(groupName)) targetNames = preset.brow;

      if (targetNames && targetNames.length > 0) {
        // マッチするオプションを探す
        let matched = null;
        for (const t of targetNames) {
          matched = grp.options.find(o => o.name.includes(t));
          if (matched) break;
        }
        if (matched) {
          grp.options.forEach(o => o.node.hidden = true);
          matched.node.hidden = false;
          ensureParentsVisible(matched.node);
        }
      }
    });

    // トグル漫符・感情・エフェクトの適用
    state.toggleLayers.forEach(item => {
      const shouldShow = preset.effect.some(e => item.name.includes(e));
      item.node.hidden = !shouldShow;
      syncEffectParentVisibility(item.node);
    });

    // UIを更新
    buildExpressionPartsUI();
    updateLayerTreeStates();
    renderComposite();

    if (cardEl) {
      elements.expressionPresetsGrid.querySelectorAll('.preset-card').forEach(c => c.classList.remove('active'));
      cardEl.classList.add('active');
    }
    showToast(`表情「${preset.name}」を適用しました`, 'success');
  }

  // 内蔵サンプルのチェック
  function checkEmbeddedPresets(psd) {
    elements.charEmbeddedPresetsGrid.innerHTML = '';
    let sampleGroup = null;

    function findSample(node) {
      if (!node) return;
      if (node.name && (node.name.includes('表情サンプル') || node.name.includes('サンプル'))) {
        sampleGroup = node;
        return;
      }
      if (node.children) node.children.forEach(findSample);
    }
    findSample(psd);

    if (sampleGroup && sampleGroup.children && sampleGroup.children.length > 0) {
      sampleGroup.children.forEach(sample => {
        const card = document.createElement('div');
        card.className = 'preset-card';
        card.innerHTML = `
          <span class="preset-emoji">✨</span>
          <span class="preset-name">${escapeHtml(sample.name.replace(/^[!*]/, ''))}</span>
        `;
        card.addEventListener('click', () => {
          sampleGroup.children.forEach(s => s.hidden = true);
          sample.hidden = false;
          sampleGroup.hidden = false;
          renderComposite();
          updateLayerTreeStates();
          showToast(`サンプル「${sample.name}」を適用しました`, 'success');
        });
        elements.charEmbeddedPresetsGrid.appendChild(card);
      });
    } else {
      elements.charEmbeddedPresetsGrid.innerHTML = '<div class="empty-state-sm">PSD内に固有のサンプルグループはありません</div>';
    }
  }

  // ==================== 詳細レイヤーツリー UI ====================
  function buildLayerTreeUI() {
    elements.layerTreeContainer.innerHTML = '';
    if (!state.psdData) return;

    function renderNode(node, depth = 0) {
      const row = document.createElement('div');
      row.className = 'layer-row';
      row.style.paddingLeft = `${depth * 14 + 6}px`;

      const isVisible = !node.hidden;
      const hasChildren = node.children && node.children.length > 0;

      row.innerHTML = `
        <span class="layer-eye ${isVisible ? 'visible' : ''}" title="表示切替">${isVisible ? '👁️' : '🕶️'}</span>
        <span class="layer-icon">${hasChildren ? '📁' : '🖼️'}</span>
        <span class="layer-name">${escapeHtml(node.name || '(名称なし)')}</span>
      `;

      const eye = row.querySelector('.layer-eye');
      eye.addEventListener('click', e => {
        e.stopPropagation();
        node.hidden = !node.hidden;
        eye.classList.toggle('visible', !node.hidden);
        eye.textContent = !node.hidden ? '👁️' : '🕶️';
        renderComposite();
      });

      elements.layerTreeContainer.appendChild(row);

      if (hasChildren) {
        node.children.forEach(child => renderNode(child, depth + 1));
      }
    }

    if (state.psdData.children) {
      state.psdData.children.forEach(child => renderNode(child, 0));
    }
  }

  function updateLayerTreeStates() {
    buildLayerTreeUI();
  }

  // ==================== 高速3x3カラーマトリクス & ピクセル変換エンジン ====================
  function multiplyMatrix3x3(a, b) {
    const out = new Float64Array(9);
    out[0] = a[0]*b[0] + a[1]*b[3] + a[2]*b[6];
    out[1] = a[0]*b[1] + a[1]*b[4] + a[2]*b[7];
    out[2] = a[0]*b[2] + a[1]*b[5] + a[2]*b[8];

    out[3] = a[3]*b[0] + a[4]*b[3] + a[5]*b[6];
    out[4] = a[3]*b[1] + a[4]*b[4] + a[5]*b[7];
    out[5] = a[3]*b[2] + a[4]*b[5] + a[5]*b[8];

    out[6] = a[6]*b[0] + a[7]*b[3] + a[8]*b[6];
    out[7] = a[6]*b[1] + a[7]*b[4] + a[8]*b[7];
    out[8] = a[6]*b[2] + a[7]*b[5] + a[8]*b[8];
    return out;
  }

  function identityMatrix3x3() {
    return new Float64Array([
      1, 0, 0,
      0, 1, 0,
      0, 0, 1
    ]);
  }

  // W3C SVG Filter準拠 色相回転マトリクス
  function getHueRotateMatrix(deg) {
    const rad = (deg % 360) * (Math.PI / 180);
    const cosA = Math.cos(rad);
    const sinA = Math.sin(rad);
    return new Float64Array([
      0.213 + cosA * 0.787 - sinA * 0.213,
      0.715 - cosA * 0.715 - sinA * 0.715,
      0.072 - cosA * 0.072 + sinA * 0.928,

      0.213 - cosA * 0.213 + sinA * 0.143,
      0.715 + cosA * 0.285 + sinA * 0.140,
      0.072 - cosA * 0.072 - sinA * 0.283,

      0.213 - cosA * 0.213 - sinA * 0.787,
      0.715 - cosA * 0.715 + sinA * 0.715,
      0.072 + cosA * 0.928 + sinA * 0.072
    ]);
  }

  // 彩度調整マトリクス (s: 0.0 ~ 2.0, 1.0 = 標準)
  function getSaturateMatrix(s) {
    return new Float64Array([
      0.213 * (1 - s) + s, 0.715 * (1 - s),     0.072 * (1 - s),
      0.213 * (1 - s),     0.715 * (1 - s) + s, 0.072 * (1 - s),
      0.213 * (1 - s),     0.715 * (1 - s),     0.072 * (1 - s) + s
    ]);
  }

  // セピアマトリクス (80%)
  function getSepiaMatrix(amount = 0.8) {
    const inv = 1 - amount;
    return new Float64Array([
      inv + amount * 0.393, amount * 0.769,       amount * 0.189,
      amount * 0.349,       inv + amount * 0.686, amount * 0.168,
      amount * 0.272,       amount * 0.534,       inv + amount * 0.131
    ]);
  }

  // 主要部位の分類定数
  const PART_ID_BODY = 0; // 体（服・衣装 ※顔と髪を除く）
  const PART_ID_HAIR = 1; // 髪
  const PART_ID_FACE = 2; // 顔・肌
  const PART_ID_ACC  = 3; // 追加物（第3の目・コード・装飾など）

  // 顔の位置（アンカーポイント）検出
  function detectFaceBounds(psd) {
    if (!psd) return { neckY: 300 };
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    let found = false;

    function scan(node) {
      if (!node) return;
      const name = node.name || '';
      if (name.includes('表情') || name.includes('目') || name.includes('口') || name.includes('眉') || name.includes('顔色') || name.includes('赤面')) {
        const left = node.left !== undefined ? node.left : 0;
        const top = node.top !== undefined ? node.top : 0;
        const width = node.canvas ? node.canvas.width : (node.imageData ? node.imageData.width : 0);
        const height = node.canvas ? node.canvas.height : (node.imageData ? node.imageData.height : 0);
        const right = node.right !== undefined ? node.right : (left + width);
        const bottom = node.bottom !== undefined ? node.bottom : (top + height);

        if (right > left && bottom > top && (right - left) < psd.width * 0.6 && (bottom - top) < psd.height * 0.6) {
          minX = Math.min(minX, left);
          minY = Math.min(minY, top);
          maxX = Math.max(maxX, right);
          maxY = Math.max(maxY, bottom);
          found = true;
        }
      }
      if (node.children) {
        node.children.forEach(scan);
      }
    }

    scan(psd);

    if (found && maxX > minX && maxY > minY) {
      return {
        x: minX,
        y: minY,
        width: maxX - minX,
        height: maxY - minY,
        neckY: maxY + (maxY - minY) * 0.55
      };
    }

    return {
      x: psd.width * 0.35,
      y: psd.height * 0.15,
      width: psd.width * 0.3,
      height: psd.height * 0.15,
      neckY: psd.height * 0.32
    };
  }

  // RGB から HSV への変換 (h: 0~360, s: 0~1, v: 0~1)
  function rgbToHsv(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    const diff = max - min;
    let h = 0;
    if (diff > 0) {
      if (max === r) {
        h = ((g - b) / diff) % 6;
        if (h < 0) h += 6;
      } else if (max === g) {
        h = (b - r) / diff + 2;
      } else {
        h = (r - g) / diff + 4;
      }
      h *= 60;
    }
    const s = max === 0 ? 0 : diff / max;
    const v = max;
    return [h, s, v];
  }

  // ==================== 部位別カラーセレクター ====================
  function populatePartColorSelect() {
    elements.partColorTargetSelect.innerHTML = '';

    // 1. 全体適用
    const optAll = document.createElement('option');
    optAll.value = 'all';
    optAll.textContent = '（全体に適用）';
    elements.partColorTargetSelect.appendChild(optAll);

    // 2. 🌟 キャラクター主要部位
    const optGroupMajor = document.createElement('optgroup');
    optGroupMajor.label = '🌟 キャラクター主要部位';

    const majorParts = [
      { id: 'part_body', name: '体（服・衣装 ※顔と髪を除く）' },
      { id: 'part_hair', name: '髪' },
      { id: 'part_face', name: '顔・肌' },
      { id: 'part_accessory', name: '追加物（第3の目・装飾など）' }
    ];

    majorParts.forEach(p => {
      const opt = document.createElement('option');
      opt.value = p.id;
      opt.textContent = p.name;
      optGroupMajor.appendChild(opt);
    });
    elements.partColorTargetSelect.appendChild(optGroupMajor);

    // 3. 📂 レイヤーグループ
    const grpNames = Object.keys(state.partGroups);
    if (grpNames.length > 0) {
      const optGroupGroups = document.createElement('optgroup');
      optGroupGroups.label = '📂 レイヤーグループ';
      grpNames.forEach(name => {
        const opt = document.createElement('option');
        opt.value = `group_${name}`;
        opt.textContent = `[グループ] ${name}`;
        optGroupGroups.appendChild(opt);
      });
      elements.partColorTargetSelect.appendChild(optGroupGroups);
    }

    // 4. 📄 個別レイヤー
    const optGroupLayers = document.createElement('optgroup');
    optGroupLayers.label = '📄 個別レイヤー';
    state.flatLayers.forEach(layer => {
      if (layer.name && !layer.name.startsWith('!')) {
        const opt = document.createElement('option');
        opt.value = layer._layerId;
        opt.textContent = layer.name;
        optGroupLayers.appendChild(opt);
      }
    });
    if (optGroupLayers.children.length > 0) {
      elements.partColorTargetSelect.appendChild(optGroupLayers);
    }

    // 初期選択：デフォルトを「体（服・衣装 ※顔と髪を除く）」に設定
    state.color.partTarget = 'part_body';
    elements.partColorTargetSelect.value = 'part_body';

    syncPartSlidersUI();
  }

  // 調整マトリクスの準備
  function prepareAdjMatrix(adj) {
    if (!adj || (adj.hue === 0 && adj.saturation === 100 && adj.brightness === 0)) {
      return { hasAdj: false, m00: 1, m01: 0, m02: 0, m10: 0, m11: 1, m12: 0, m20: 0, m21: 0, m22: 1, bOffset: 0 };
    }

    let mat = identityMatrix3x3();
    if (adj.hue !== 0) {
      mat = multiplyMatrix3x3(getHueRotateMatrix(adj.hue), mat);
    }
    if (adj.saturation !== 100) {
      mat = multiplyMatrix3x3(getSaturateMatrix(adj.saturation / 100), mat);
    }

    return {
      hasAdj: true,
      m00: mat[0], m01: mat[1], m02: mat[2],
      m10: mat[3], m11: mat[4], m12: mat[5],
      m20: mat[6], m21: mat[7], m22: mat[8],
      bOffset: (adj.brightness || 0) * 2.55
    };
  }

  // ノードがベースとなる体レイヤーかチェック
  function isMajorBaseLayer(node) {
    if (!node) return false;
    let curr = node;
    while (curr) {
      const n = (curr.name || '').replace(/^[!*]/, '').trim();
      if (n === '体' || n === '素体' || n === 'ベース' || n === '衣装') return true;
      curr = curr._parent;
    }
    const myName = (node.name || '');
    return myName.includes('体') || myName.includes('第三の目');
  }

  // レイヤー内の各ピクセルを「体」「髪」「顔」「追加物」に分類してマスク（Uint8Array）を生成
  function getOrCreateLayerPartMask(node, imgData) {
    if (node._partMask && node._partMask.length === imgData.data.length / 4) {
      return node._partMask;
    }

    const data = imgData.data;
    const numPixels = data.length / 4;
    const mask = new Uint8Array(numPixels);
    const width = imgData.width;
    const height = imgData.height;
    const nodeLeft = node.left || 0;
    const nodeTop = node.top || 0;

    const faceBounds = state.faceBounds || (state.psdData ? detectFaceBounds(state.psdData) : { neckY: height * 0.32 });
    const localNeckY = (faceBounds.neckY || height * 0.32) - nodeTop;

    // 「第三の目無」など差分レイヤーがあれば探索
    let noEyeImgData = null;
    let dx = 0, dy = 0;
    if (node._parent && node._parent.children) {
      const noEyeNode = node._parent.children.find(c => {
        const n = c.name || '';
        return (n.includes('第三の目無') || n.includes('目無')) && c !== node;
      });
      if (noEyeNode) {
        if (!noEyeNode.imageData && noEyeNode.canvas) {
          noEyeNode.imageData = noEyeNode.canvas.getContext('2d').getImageData(0, 0, noEyeNode.canvas.width, noEyeNode.canvas.height);
        }
        noEyeImgData = noEyeNode.imageData;
        if (noEyeImgData) {
          dx = (noEyeNode.left || 0) - nodeLeft;
          dy = (noEyeNode.top || 0) - nodeTop;
        }
      }
    }

    for (let i = 0, p = 0; i < data.length; i += 4, p++) {
      const a = data[i + 3];
      if (a < 15) {
        mask[p] = PART_ID_BODY;
        continue;
      }

      const x = p % width;
      const y = Math.floor(p / width);

      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];

      const [hDeg, s, v] = rgbToHsv(r, g, b);
      const isLine = (v < 0.15); // 黒い主線

      // 1. 追加物 (第3の目・コード・装飾)
      let isAcc = false;
      if (noEyeImgData) {
        const nx = x - dx;
        const ny = y - dy;
        if (nx >= 0 && nx < noEyeImgData.width && ny >= 0 && ny < noEyeImgData.height) {
          const nIdx = (ny * noEyeImgData.width + nx) * 4;
          const nA = noEyeImgData.data[nIdx + 3];
          if (nA < 15) {
            isAcc = true; // 目無には存在しないピクセル
          } else {
            const diff = Math.max(
              Math.abs(r - noEyeImgData.data[nIdx]),
              Math.abs(g - noEyeImgData.data[nIdx + 1]),
              Math.abs(b - noEyeImgData.data[nIdx + 2])
            );
            if (diff > 30) isAcc = true;
          }
        } else {
          isAcc = true;
        }
      }

      // 色彩特徴による追加物（コードの青緑・シアン、紫ハートなど）フォールバック
      if (!isAcc) {
        const isCyanCord = (hDeg >= 150 && hDeg <= 205 && s > 0.30);
        const isPurpleGem = (hDeg >= 265 && hDeg <= 325 && s > 0.35 && y > localNeckY * 0.7);
        if (isCyanCord || isPurpleGem) {
          isAcc = true;
        }
      }

      if (isAcc) {
        mask[p] = PART_ID_ACC;
        continue;
      }

      // 2. 顔・肌 (Skin)
      const isSkinColor = ((hDeg <= 52 || hDeg >= 345) && s >= 0.05 && s <= 0.65 && v >= 0.45);
      const isHeadOrHand = (y <= localNeckY || (x < width * 0.25 && y < height * 0.65) || (x > width * 0.75 && y < height * 0.65));
      if (isSkinColor && isHeadOrHand) {
        mask[p] = PART_ID_FACE;
        continue;
      }

      // 3. 髪 (Hair) - 頭部領域で肌色・追加物・主線でない部分
      if (y <= localNeckY && !isSkinColor && !isLine) {
        mask[p] = PART_ID_HAIR;
        continue;
      }

      // 4. 体（服・衣装 ※顔と髪を除く）
      mask[p] = PART_ID_BODY;
    }

    node._partMask = mask;
    return mask;
  }

  // 主要ベースレイヤー（体・髪・顔・追加物）のセグメンテーションカラー調整
  function applyMajorPartsColorAdjustment(node, srcCanvas) {
    const adjBody = state.partColors['part_body'] || (state.partColors['group_体'] || null);
    const adjHair = state.partColors['part_hair'];
    const adjFace = state.partColors['part_face'];
    const adjAcc  = state.partColors['part_accessory'];

    const mBody = prepareAdjMatrix(adjBody);
    const mHair = prepareAdjMatrix(adjHair);
    const mFace = prepareAdjMatrix(adjFace);
    const mAcc  = prepareAdjMatrix(adjAcc);

    const hasAnyMajorAdj = mBody.hasAdj || mHair.hasAdj || mFace.hasAdj || mAcc.hasAdj;
    if (!hasAnyMajorAdj) {
      return srcCanvas;
    }

    const pCanvas = document.createElement('canvas');
    pCanvas.width = srcCanvas.width;
    pCanvas.height = srcCanvas.height;
    const pCtx = pCanvas.getContext('2d');
    pCtx.drawImage(srcCanvas, 0, 0);

    const imgData = pCtx.getImageData(0, 0, pCanvas.width, pCanvas.height);
    const data = imgData.data;
    const mask = getOrCreateLayerPartMask(node, imgData);

    const mats = [mBody, mHair, mFace, mAcc];

    const len = data.length;
    for (let i = 0, p = 0; i < len; i += 4, p++) {
      if (data[i + 3] === 0) continue;

      const partType = mask[p];
      const m = mats[partType];
      if (!m.hasAdj) continue; // 変更のない部位はスキップ

      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];

      const nr = r * m.m00 + g * m.m01 + b * m.m02 + m.bOffset;
      const ng = r * m.m10 + g * m.m11 + b * m.m12 + m.bOffset;
      const nb = r * m.m20 + g * m.m21 + b * m.m22 + m.bOffset;

      data[i]     = nr < 0 ? 0 : (nr > 255 ? 255 : nr);
      data[i + 1] = ng < 0 ? 0 : (ng > 255 ? 255 : ng);
      data[i + 2] = nb < 0 ? 0 : (nb > 255 ? 255 : nb);
    }

    pCtx.putImageData(imgData, 0, 0);
    return pCanvas;
  }

  // ノードが対象となる部位設定を取得
  function getLayerPartAdjustment(node) {
    if (!state.partColors) return null;

    // 1. レイヤー直接指定 (layer_*)
    if (node._layerId && state.partColors[node._layerId]) {
      const s = state.partColors[node._layerId];
      if (s.hue !== 0 || s.saturation !== 100 || s.brightness !== 0) return s;
    }

    // 2. 親グループを上へ辿ってグループ指定を判定 (group_*)
    let curr = node._parent;
    while (curr) {
      const gName = (curr.name || '').replace(/^[!*]/, '').trim();
      if (gName && state.partColors[`group_${gName}`]) {
        const s = state.partColors[`group_${gName}`];
        if (s.hue !== 0 || s.saturation !== 100 || s.brightness !== 0) return s;
      }
      curr = curr._parent;
    }

    // 3. node._fullPath によるグループ名判定
    if (node._fullPath) {
      for (const key of Object.keys(state.partColors)) {
        if (key.startsWith('group_')) {
          const gName = key.replace('group_', '');
          if (node._fullPath.includes(gName)) {
            const s = state.partColors[key];
            if (s.hue !== 0 || s.saturation !== 100 || s.brightness !== 0) return s;
          }
        }
      }
    }

    // 4. 「全体に適用」(all)
    if (state.partColors['all']) {
      const s = state.partColors['all'];
      if (s.hue !== 0 || s.saturation !== 100 || s.brightness !== 0) return s;
    }

    return null;
  }

  // 部位用ピクセル直接変換（WKWebViewでも100%確実に即座に動作）
  function applyLayerColorAdjustment(srcCanvas, adj) {
    const pCanvas = document.createElement('canvas');
    pCanvas.width = srcCanvas.width;
    pCanvas.height = srcCanvas.height;
    const pCtx = pCanvas.getContext('2d');
    pCtx.drawImage(srcCanvas, 0, 0);

    const imgData = pCtx.getImageData(0, 0, pCanvas.width, pCanvas.height);
    const data = imgData.data;

    let mat = identityMatrix3x3();
    if (adj.hue !== 0) {
      mat = multiplyMatrix3x3(getHueRotateMatrix(adj.hue), mat);
    }
    if (adj.saturation !== 100) {
      mat = multiplyMatrix3x3(getSaturateMatrix(adj.saturation / 100), mat);
    }

    const m00 = mat[0], m01 = mat[1], m02 = mat[2];
    const m10 = mat[3], m11 = mat[4], m12 = mat[5];
    const m20 = mat[6], m21 = mat[7], m22 = mat[8];
    const bOffset = (adj.brightness || 0) * 2.55;

    const len = data.length;
    for (let i = 0; i < len; i += 4) {
      if (data[i + 3] === 0) continue;
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];

      const nr = r * m00 + g * m01 + b * m02 + bOffset;
      const ng = r * m10 + g * m11 + b * m12 + bOffset;
      const nb = r * m20 + g * m21 + b * m22 + bOffset;

      data[i]     = nr < 0 ? 0 : (nr > 255 ? 255 : nr);
      data[i + 1] = ng < 0 ? 0 : (ng > 255 ? 255 : ng);
      data[i + 2] = nb < 0 ? 0 : (nb > 255 ? 255 : nb);
    }

    pCtx.putImageData(imgData, 0, 0);
    return pCanvas;
  }

  // 全体カラー調整があるか判定
  function hasGlobalAdjustment() {
    return (
      state.color.hue !== 0 ||
      state.color.saturation !== 100 ||
      state.color.brightness !== 0 ||
      state.color.contrast !== 0 ||
      state.color.temperature !== 0 ||
      state.color.red !== 0 ||
      state.color.green !== 0 ||
      state.color.blue !== 0 ||
      (state.color.filter && state.color.filter !== 'normal')
    );
  }

  // 全体カラー調整を1パスの高速ピクセルループで適用（WebKit対応）
  function applyGlobalColorAdjustment(c, w, h) {
    if (!hasGlobalAdjustment()) return;

    const imgData = c.getImageData(0, 0, w, h);
    const data = imgData.data;

    // 1. カラーマトリクス合成
    let mat = identityMatrix3x3();
    if (state.color.hue !== 0) {
      mat = multiplyMatrix3x3(getHueRotateMatrix(state.color.hue), mat);
    }
    if (state.color.saturation !== 100) {
      mat = multiplyMatrix3x3(getSaturateMatrix(state.color.saturation / 100), mat);
    }
    if (state.color.filter === 'sepia') {
      mat = multiplyMatrix3x3(getSepiaMatrix(0.8), mat);
    } else if (state.color.filter === 'monochrome') {
      mat = multiplyMatrix3x3(getSaturateMatrix(0), mat);
    }

    // 2. コントラスト係数 (標準コントラスト補正式)
    let contrastFactor = 1.0;
    if (state.color.contrast !== 0) {
      contrastFactor = (259 * (state.color.contrast + 255)) / (255 * (259 - state.color.contrast));
    }

    // 3. マトリクスとコントラストの事前乗算
    const m00 = mat[0] * contrastFactor;
    const m01 = mat[1] * contrastFactor;
    const m02 = mat[2] * contrastFactor;

    const m10 = mat[3] * contrastFactor;
    const m11 = mat[4] * contrastFactor;
    const m12 = mat[5] * contrastFactor;

    const m20 = mat[6] * contrastFactor;
    const m21 = mat[7] * contrastFactor;
    const m22 = mat[8] * contrastFactor;

    // 4. 定数オフセット事前計算 (コントラスト中心点128、明度、色温度、RGBバランス)
    const contrastOffset = 128 * (1 - contrastFactor);
    const brightnessOffset = state.color.brightness * 2.55;

    const rOffset = contrastOffset + brightnessOffset + state.color.red * 2.55 + (state.color.temperature > 0 ? state.color.temperature * 1.5 : 0);
    const gOffset = contrastOffset + brightnessOffset + state.color.green * 2.55;
    const bOffset = contrastOffset + brightnessOffset + state.color.blue * 2.55 + (state.color.temperature < 0 ? -state.color.temperature * 1.5 : 0);

    const len = data.length;
    for (let i = 0; i < len; i += 4) {
      if (data[i + 3] === 0) continue; // 透明ピクセルはスキップ

      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];

      const nr = r * m00 + g * m01 + b * m02 + rOffset;
      const ng = r * m10 + g * m11 + b * m12 + gOffset;
      const nb = r * m20 + g * m21 + b * m22 + bOffset;

      data[i]     = nr < 0 ? 0 : (nr > 255 ? 255 : nr);
      data[i + 1] = ng < 0 ? 0 : (ng > 255 ? 255 : ng);
      data[i + 2] = nb < 0 ? 0 : (nb > 255 ? 255 : nb);
    }

    c.putImageData(imgData, 0, 0);
  }

  // ==================== リアルタイム合成 & 色彩変換 ====================
  function renderComposite() {
    if (!state.psdData) return;

    const width = elements.previewCanvas.width;
    const height = elements.previewCanvas.height;
    ctx.clearRect(0, 0, width, height);

    // 一時キャンバスに全可視レイヤーを合成
    const tempCanvas = document.createElement('canvas');
    tempCanvas.width = width;
    tempCanvas.height = height;
    const tempCtx = tempCanvas.getContext('2d');

    // レイヤーの再帰的描画
    function drawNode(node) {
      if (!node || node.hidden) return;

      // グループ (正順: 背面 0 から前面 N へ順次描画)
      if (node.children && node.children.length > 0) {
        for (let i = 0; i < node.children.length; i++) {
          drawNode(node.children[i]);
        }
      } else {
        // 画像レイヤー
        const canvasOrImg = node.canvas;
        const imgData = node.imageData;

        let layerCanvas = canvasOrImg;
        if (!layerCanvas && imgData) {
          layerCanvas = document.createElement('canvas');
          layerCanvas.width = imgData.width;
          layerCanvas.height = imgData.height;
          const lCtx = layerCanvas.getContext('2d');
          lCtx.putImageData(imgData, 0, 0);
          node.canvas = layerCanvas; // キャッシュ
        }

        if (layerCanvas) {
          tempCtx.save();
          tempCtx.globalAlpha = node.opacity !== undefined ? node.opacity : 1.0;
          
          const left = node.left || 0;
          const top = node.top || 0;

          // 部位別色調整の適用対象かチェック
          if (isMajorBaseLayer(node)) {
            // 体（顔と髪を除く）、顔、髪、追加物（第3の目など）の主要部位カラー変換
            const adjustedCanvas = applyMajorPartsColorAdjustment(node, layerCanvas);
            tempCtx.drawImage(adjustedCanvas, left, top);
          } else {
            const partAdj = getLayerPartAdjustment(node);
            if (partAdj) {
              // 部位個別カラー変換 (ピクセル直接処理)
              const adjustedCanvas = applyLayerColorAdjustment(layerCanvas, partAdj);
              tempCtx.drawImage(adjustedCanvas, left, top);
            } else {
              tempCtx.drawImage(layerCanvas, left, top);
            }
          }

          tempCtx.restore();
        }
      }
    }

    // ルートの子要素 (正順: 最背面 0 から最前面 N へ順次描画)
    if (state.psdData.children) {
      for (let i = 0; i < state.psdData.children.length; i++) {
        drawNode(state.psdData.children[i]);
      }
    }

    // メインキャンバスへ転写 (水平反転含む)
    ctx.save();
    if (state.flipH) {
      ctx.translate(width, 0);
      ctx.scale(-1, 1);
    }
    ctx.drawImage(tempCanvas, 0, 0);
    ctx.restore();

    // グローバル全体カラー調整 (色相、彩度、明度、コントラスト、色温度、RGB、雰囲気フィルター)
    if (hasGlobalAdjustment()) {
      applyGlobalColorAdjustment(ctx, width, height);
    }

    // 色置換前の純粋な合成キャンバスを保持（スポイトサンプリングの参照用）
    if (!state.rawCompositeCanvas) {
      state.rawCompositeCanvas = document.createElement('canvas');
    }
    if (state.rawCompositeCanvas.width !== width || state.rawCompositeCanvas.height !== height) {
      state.rawCompositeCanvas.width = width;
      state.rawCompositeCanvas.height = height;
    }
    const rawCtx = state.rawCompositeCanvas.getContext('2d');
    rawCtx.clearRect(0, 0, width, height);
    rawCtx.drawImage(elements.previewCanvas, 0, 0);

    // 特定色の置き換え（カラーリプレイスメント）
    const hasActiveRules = state.colorRules && state.colorRules.some(r => r.enabled);
    const hasLiveHover = state.isEyedropperActive && state.hoverSampleColor;
    if (hasActiveRules || hasLiveHover) {
      applyColorReplacementPixels(ctx, width, height);
    }
  }

  // ==================== 特定色置換 (カラーリプレイスメント) ====================
  let nextRuleId = 1;
  let eyedropperRafId = null;

  function toggleEyedropper(target = null) {
    if (typeof target === 'boolean') {
      state.isEyedropperActive = target;
    } else if (typeof target === 'number') {
      state.isEyedropperActive = true;
      state.activeEyedropperRuleId = target;
    } else {
      state.isEyedropperActive = !state.isEyedropperActive;
      if (state.isEyedropperActive) {
        state.activeEyedropperRuleId = state.colorRules.length > 0 ? state.colorRules[state.colorRules.length - 1].id : null;
      }
    }

    if (!state.isEyedropperActive) {
      state.activeEyedropperRuleId = null;
      state.hoverSampleColor = null;
      if (elements.eyedropperTooltip) elements.eyedropperTooltip.style.display = 'none';
      renderComposite();
    }

    if (elements.btnEyedropper) {
      elements.btnEyedropper.classList.toggle('active', state.isEyedropperActive && !state.activeEyedropperRuleId);
    }
    if (elements.eyedropperHint) {
      elements.eyedropperHint.style.display = state.isEyedropperActive ? 'inline' : 'none';
    }
    if (elements.canvasContainer) {
      elements.canvasContainer.classList.toggle('eyedropper-mode', state.isEyedropperActive);
    }

    // 各ルールのスポイトボタン表示状態更新
    document.querySelectorAll('.rule-eyedropper-btn').forEach(btn => {
      const rId = parseInt(btn.getAttribute('data-rule-id'));
      btn.classList.toggle('active', state.isEyedropperActive && state.activeEyedropperRuleId === rId);
    });

    if (state.isEyedropperActive) {
      showToast('キャンバス上をマウス移動でリアルタイムプレビュー、クリックで色決定', 'info');
      setStatus('スポイト中: マウス移動でリアルタイムプレビュー、クリックで決定');
    } else {
      setStatus('待機中');
    }
  }

  function handleEyedropperHover(e) {
    if (!state.isEyedropperActive) return;

    const rect = elements.previewCanvas.getBoundingClientRect();
    const scaleX = elements.previewCanvas.width / rect.width;
    const scaleY = elements.previewCanvas.height / rect.height;
    const x = Math.floor((e.clientX - rect.left) * scaleX);
    const y = Math.floor((e.clientY - rect.top) * scaleY);

    // ツールチップ追従
    if (elements.eyedropperTooltip) {
      elements.eyedropperTooltip.style.display = 'flex';
      elements.eyedropperTooltip.style.left = `${e.clientX}px`;
      elements.eyedropperTooltip.style.top = `${e.clientY}px`;
    }

    if (x < 0 || x >= elements.previewCanvas.width || y < 0 || y >= elements.previewCanvas.height) {
      if (elements.eyedropperTooltip) elements.eyedropperTooltip.style.display = 'none';
      return;
    }

    // rawCompositeCanvas（加工前の生画像）からピクセルを取得
    const sampleSrc = state.rawCompositeCanvas ? state.rawCompositeCanvas.getContext('2d') : ctx;
    const pixel = sampleSrc.getImageData(x, y, 1, 1).data;

    if (pixel[3] < 15) {
      if (elements.eyedropperTooltipText) elements.eyedropperTooltipText.textContent = '透明';
      if (elements.eyedropperTooltipPreview) elements.eyedropperTooltipPreview.style.backgroundColor = 'transparent';
      return;
    }

    const hex = rgbToHex(pixel[0], pixel[1], pixel[2]);
    if (elements.eyedropperTooltipText) elements.eyedropperTooltipText.textContent = hex.toUpperCase();
    if (elements.eyedropperTooltipPreview) elements.eyedropperTooltipPreview.style.backgroundColor = hex;

    // リアルタイムに仮の fromColor としてキャンバスプレビューを描画！
    if (state.hoverSampleColor !== hex) {
      state.hoverSampleColor = hex;
      if (eyedropperRafId) cancelAnimationFrame(eyedropperRafId);
      eyedropperRafId = requestAnimationFrame(() => {
        renderComposite();
      });
    }
  }

  function handleEyedropperSample(e) {
    const rect = elements.previewCanvas.getBoundingClientRect();
    const scaleX = elements.previewCanvas.width / rect.width;
    const scaleY = elements.previewCanvas.height / rect.height;
    const x = Math.floor((e.clientX - rect.left) * scaleX);
    const y = Math.floor((e.clientY - rect.top) * scaleY);

    if (x < 0 || x >= elements.previewCanvas.width || y < 0 || y >= elements.previewCanvas.height) return;

    // rawCompositeCanvas または ctx からピクセルを取得
    const sampleSrc = state.rawCompositeCanvas ? state.rawCompositeCanvas.getContext('2d') : ctx;
    const pixel = sampleSrc.getImageData(x, y, 1, 1).data;
    if (pixel[3] < 15) {
      showToast('透明な部分は選択できません。イラストの上をクリックしてください', 'error');
      return;
    }

    const hex = rgbToHex(pixel[0], pixel[1], pixel[2]);

    // 対象ルールを決定
    let targetRule = null;
    if (state.activeEyedropperRuleId) {
      targetRule = state.colorRules.find(r => r.id === state.activeEyedropperRuleId);
    }
    if (!targetRule) {
      if (state.colorRules.length > 0) {
        targetRule = state.colorRules[state.colorRules.length - 1];
      } else {
        targetRule = addColorRule(hex, '#3498db');
      }
    }

    if (targetRule) {
      targetRule.fromColor = hex;
      targetRule.enabled = true;
    }

    state.hoverSampleColor = null;
    state.activeEyedropperRuleId = null;
    toggleEyedropper(false); // スポイト終了

    renderColorRulesUI();
    renderComposite();
    showToast(`色を取得・置換適用しました: ${hex.toUpperCase()}`, 'success');
  }

  function addColorRule(fromColor = '#e74c3c', toColor = '#3498db') {
    const rule = {
      id: nextRuleId++,
      fromColor: fromColor,
      toColor: toColor,
      tolerance: 35, // 35%
      targetScope: 'all',
      enabled: true
    };
    state.colorRules.push(rule);
    renderColorRulesUI();
    renderComposite();
    showToast('特定色置換ルールを追加しました', 'success');
    return rule;
  }

  function deleteColorRule(id) {
    state.colorRules = state.colorRules.filter(r => r.id !== id);
    if (state.activeEyedropperRuleId === id) {
      state.activeEyedropperRuleId = null;
    }
    renderColorRulesUI();
    renderComposite();
    showToast('色置換ルールを削除しました', 'info');
  }

  function renderColorRulesUI() {
    if (!elements.colorRulesList) return;
    elements.colorRulesList.innerHTML = '';

    if (state.colorRules.length === 0) {
      elements.colorRulesList.innerHTML = '<div class="empty-state-sm">置換ルールがありません。「＋ ルール追加」または「スポイト」で色を追加できます。</div>';
      return;
    }

    state.colorRules.forEach((rule, idx) => {
      const card = document.createElement('div');
      card.className = 'color-rule-card';
      if (!rule.enabled) card.style.opacity = '0.6';

      const isThisRuleEyedropper = state.isEyedropperActive && state.activeEyedropperRuleId === rule.id;

      card.innerHTML = `
        <div class="color-rule-header">
          <label class="color-rule-title-row">
            <input type="checkbox" class="rule-enable-chk" ${rule.enabled ? 'checked' : ''}>
            <span>色置換 #${idx + 1}</span>
          </label>
          <button class="color-rule-delete-btn" title="ルール削除">🗑️</button>
        </div>

        <div class="color-rule-row">
          <div class="color-chip-group">
            <div class="color-chip-wrapper" title="変換前の元色">
              <input type="color" class="from-color-input" value="${rule.fromColor}">
              <span class="color-hex-label">${rule.fromColor.toUpperCase()}</span>
            </div>
            <button class="rule-eyedropper-btn ${isThisRuleEyedropper ? 'active' : ''}" data-rule-id="${rule.id}" title="このルールの色をスポイトで取得">💧</button>
            <span class="color-arrow">➔</span>
            <div class="color-chip-wrapper" title="変換後の目標色">
              <input type="color" class="to-color-input" value="${rule.toColor}">
              <span class="color-hex-label">${rule.toColor.toUpperCase()}</span>
            </div>
          </div>
        </div>

        <div class="tolerance-row">
          <span>許容範囲:</span>
          <div class="tolerance-slider-wrapper">
            <input type="range" class="tolerance-slider" min="5" max="80" value="${rule.tolerance}">
            <span class="tolerance-val" style="width: 32px; text-align: right; font-weight: 600;">${rule.tolerance}%</span>
          </div>
        </div>
      `;

      // イベント
      const chk = card.querySelector('.rule-enable-chk');
      chk.addEventListener('change', e => {
        rule.enabled = e.target.checked;
        card.style.opacity = rule.enabled ? '1' : '0.6';
        renderComposite();
      });

      const delBtn = card.querySelector('.color-rule-delete-btn');
      delBtn.addEventListener('click', () => deleteColorRule(rule.id));

      const eyedropperBtn = card.querySelector('.rule-eyedropper-btn');
      eyedropperBtn.addEventListener('click', () => {
        if (state.isEyedropperActive && state.activeEyedropperRuleId === rule.id) {
          toggleEyedropper(false);
        } else {
          toggleEyedropper(rule.id);
        }
      });

      const fromInput = card.querySelector('.from-color-input');
      const fromHexLabel = card.querySelectorAll('.color-hex-label')[0];
      fromInput.addEventListener('input', e => {
        rule.fromColor = e.target.value;
        fromHexLabel.textContent = e.target.value.toUpperCase();
        renderComposite();
      });

      const toInput = card.querySelector('.to-color-input');
      const toHexLabel = card.querySelectorAll('.color-hex-label')[1];
      toInput.addEventListener('input', e => {
        rule.toColor = e.target.value;
        toHexLabel.textContent = e.target.value.toUpperCase();
        renderComposite();
      });

      const tolSlider = card.querySelector('.tolerance-slider');
      const tolVal = card.querySelector('.tolerance-val');
      tolSlider.addEventListener('input', e => {
        rule.tolerance = parseInt(e.target.value);
        tolVal.textContent = `${rule.tolerance}%`;
        renderComposite();
      });

      elements.colorRulesList.appendChild(card);
    });
  }

  // 陰影保持型ピクセル置換エンジン (新アルゴリズム)
  function applyColorReplacementPixels(c, w, h) {
    // 実際に適用するルールリストを構築
    // スポイトホバー中の場合は、対象ルールの fromColor を一時的に hoverSampleColor に差し替える
    let rulesToApply = state.colorRules.filter(r => r.enabled);

    if (state.isEyedropperActive && state.hoverSampleColor) {
      let targetId = state.activeEyedropperRuleId;
      if (!targetId && rulesToApply.length > 0) {
        targetId = rulesToApply[rulesToApply.length - 1].id;
      }
      if (targetId) {
        rulesToApply = rulesToApply.map(r => {
          if (r.id === targetId) {
            return { ...r, fromColor: state.hoverSampleColor };
          }
          return r;
        });
      } else {
        // ルールが1つもない状態でスポイトホバーしている場合、仮の青色置換ルールを作成してプレビュー
        rulesToApply = [{
          id: -1,
          fromColor: state.hoverSampleColor,
          toColor: '#3498db',
          tolerance: 35,
          enabled: true
        }];
      }
    }

    if (rulesToApply.length === 0) return;

    const imgData = c.getImageData(0, 0, w, h);
    const data = imgData.data;

    // 事前計算
    const prepared = rulesToApply.map(r => {
      const fr = hexToRgb(r.fromColor);
      const [fh, fs, fl] = rgbToHsl(fr[0], fr[1], fr[2]);
      const tr = hexToRgb(r.toColor);
      const [th, ts, tl] = rgbToHsl(tr[0], tr[1], tr[2]);
      const tol = (r.tolerance || 35) / 100;
      return { fh, fs, fl, th, ts, tl, tol };
    });

    for (let i = 0; i < data.length; i += 4) {
      const a = data[i + 3];
      if (a < 15) continue;

      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];

      const [ph, ps, pl] = rgbToHsl(r, g, b);

      // 黒い線画 (pl < 0.12) は保護
      if (pl < 0.12) continue;

      for (let j = 0; j < prepared.length; j++) {
        const pr = prepared[j];

        // 元色が鮮やかな場合、彩度が極端に低いもの（白や純グレー）は保護
        if (pr.fs > 0.3 && ps < 0.15) continue;

        // 色相環距離 (0〜180度 を 0〜1 に正規化)
        let dh = Math.abs(ph - pr.fh);
        if (dh > 180) dh = 360 - dh;
        const dhNorm = dh / 180;

        // 彩度差と明度差
        const dsNorm = Math.abs(ps - pr.fs);
        const dlNorm = Math.abs(pl - pr.fl);

        // 重み付き距離 (色相 70%, 彩度 18%, 明度 12%)
        const dist = dhNorm * 0.70 + dsNorm * 0.18 + dlNorm * 0.12;

        if (dist < pr.tol) {
          const weight = Math.cos((dist / pr.tol) * (Math.PI / 2));
          
          // 明度 pl を 100% 保持（陰影・立体感を完全に維持）
          const newH = pr.th;
          const newS = Math.min(1.0, pr.ts * (ps / Math.max(0.1, pr.fs)));
          const newL = pl;

          const [outR, outG, outB] = hslToRgb(newH, newS, newL);

          data[i] = Math.round(r * (1 - weight) + outR * weight);
          data[i + 1] = Math.round(g * (1 - weight) + outG * weight);
          data[i + 2] = Math.round(b * (1 - weight) + outB * weight);
          break;
        }
      }
    }

    c.putImageData(imgData, 0, 0);
  }

  // 色変換ユーティリティ
  function rgbToHex(r, g, b) {
    return '#' + [r, g, b].map(x => {
      const hex = Math.max(0, Math.min(255, Math.round(x))).toString(16);
      return hex.length === 1 ? '0' + hex : hex;
    }).join('');
  }

  function hexToRgb(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? [parseInt(result[1], 16), parseInt(result[2], 16), parseInt(result[3], 16)] : [0, 0, 0];
  }

  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    let h, s, l = (max + min) / 2;

    if (max === min) {
      h = s = 0;
    } else {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      switch (max) {
        case r: h = (g - b) / d + (g < b ? 6 : 0); break;
        case g: h = (b - r) / d + 2; break;
        case b: h = (r - g) / d + 4; break;
      }
      h *= 60;
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
        if (t < 1/6) return p + (q - p) * 6 * t;
        if (t < 1/2) return q;
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
        return p;
      };
      const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      const p = 2 * l - q;
      const hk = h / 360;
      r = hue2rgb(p, q, hk + 1/3);
      g = hue2rgb(p, q, hk);
      b = hue2rgb(p, q, hk - 1/3);
    }
    return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
  }

  // ==================== 雰囲気プリセット ====================
  function applyFilterPreset(filterType) {
    state.color.filter = filterType;
    resetColorSlidersQuiet();

    switch (filterType) {
      case 'sunset': // 夕暮れ・茜色
        state.color.hue = 15;
        state.color.saturation = 130;
        state.color.brightness = -5;
        state.color.temperature = 45;
        state.color.red = 25;
        break;
      case 'moonlight': // 夜・月光
        state.color.hue = -20;
        state.color.saturation = 80;
        state.color.brightness = -15;
        state.color.temperature = -50;
        state.color.blue = 30;
        break;
      case 'darkness': // 闇落ち・妖気
        state.color.hue = -45;
        state.color.saturation = 140;
        state.color.contrast = 35;
        state.color.brightness = -20;
        state.color.red = 20;
        state.color.blue = 20;
        break;
      case 'suntan': // 日焼け・小麦肌
        state.color.hue = -10;
        state.color.saturation = 120;
        state.color.brightness = -12;
        state.color.temperature = 30;
        break;
      case 'sepia': // セピア
        state.color.saturation = 90;
        state.color.contrast = 10;
        break;
      case 'monochrome': // モノクロ
        state.color.saturation = 0;
        state.color.contrast = 20;
        break;
      case 'cyber': // サイバーネオン
        state.color.saturation = 170;
        state.color.contrast = 30;
        state.color.brightness = 5;
        break;
      case 'pastel': // パステルドリーム
        state.color.saturation = 75;
        state.color.brightness = 15;
        state.color.contrast = -10;
        break;
      case 'horror': // ホラー・怨霊
        state.color.saturation = 60;
        state.color.brightness = -30;
        state.color.contrast = 45;
        state.color.temperature = -30;
        break;
      case 'normal':
      default:
        // 通常リセット済み
        break;
    }

    syncColorSlidersUI();
    renderComposite();
    showToast(`フィルター「${filterType}」を適用しました`, 'success');
  }

  function resetColorSlidersQuiet() {
    state.color.hue = 0;
    state.color.saturation = 100;
    state.color.brightness = 0;
    state.color.contrast = 0;
    state.color.temperature = 0;
    state.color.red = 0;
    state.color.green = 0;
    state.color.blue = 0;
  }

  function resetColorSliders() {
    resetColorSlidersQuiet();
    state.color.filter = 'normal';
    elements.filterChips.forEach(c => c.classList.remove('active'));
    const normalChip = document.querySelector('.filter-chip[data-filter="normal"]');
    if (normalChip) normalChip.classList.add('active');
    syncColorSlidersUI();
    renderComposite();
    showToast('全体カラー調整をリセットしました', 'success');
  }

  function syncColorSlidersUI() {
    if (elements.sliderHue) {
      elements.sliderHue.value = state.color.hue;
      elements.valHue.textContent = `${state.color.hue}°`;
    }
    if (elements.sliderSaturation) {
      elements.sliderSaturation.value = state.color.saturation;
      elements.valSaturation.textContent = `${state.color.saturation}%`;
    }
    if (elements.sliderBrightness) {
      elements.sliderBrightness.value = state.color.brightness;
      elements.valBrightness.textContent = `${state.color.brightness}%`;
    }
    if (elements.sliderContrast) {
      elements.sliderContrast.value = state.color.contrast;
      elements.valContrast.textContent = `${state.color.contrast}%`;
    }
    if (elements.sliderTemperature) {
      elements.sliderTemperature.value = state.color.temperature;
      elements.valTemperature.textContent = state.color.temperature;
    }
    if (elements.sliderRed) {
      elements.sliderRed.value = state.color.red;
      elements.valRed.textContent = state.color.red;
    }
    if (elements.sliderGreen) {
      elements.sliderGreen.value = state.color.green;
      elements.valGreen.textContent = state.color.green;
    }
    if (elements.sliderBlue) {
      elements.sliderBlue.value = state.color.blue;
      elements.valBlue.textContent = state.color.blue;
    }
  }

  function syncPartSlidersUI() {
    const target = state.color.partTarget || 'all';
    const s = state.partColors[target] || { hue: 0, saturation: 100, brightness: 0 };
    
    if (elements.sliderPartHue) {
      elements.sliderPartHue.value = s.hue;
      elements.valPartHue.textContent = `${s.hue}°`;
    }
    if (elements.sliderPartSaturation) {
      elements.sliderPartSaturation.value = s.saturation;
      elements.valPartSaturation.textContent = `${s.saturation}%`;
    }
    if (elements.sliderPartBrightness) {
      elements.sliderPartBrightness.value = s.brightness;
      elements.valPartBrightness.textContent = `${s.brightness}%`;
    }
  }

  function resetPartColor() {
    const target = state.color.partTarget || 'all';
    if (target === 'all') {
      state.partColors = {};
    } else {
      delete state.partColors[target];
    }
    syncPartSlidersUI();
    renderComposite();
    showToast('部位カラー調整をリセットしました', 'success');
  }

  // ==================== ズーム & ビューポート ====================
  function setZoom(newZoom) {
    state.zoom = Math.max(0.1, Math.min(5.0, newZoom));
    elements.zoomLevelDisplay.textContent = `${Math.round(state.zoom * 100)}%`;
    applyCanvasTransform();
  }

  function fitToViewport() {
    if (!state.psdData) return;
    const vpRect = elements.canvasViewport.getBoundingClientRect();
    if (!vpRect.width || !vpRect.height || vpRect.width <= 0 || vpRect.height <= 0) {
      setTimeout(fitToViewport, 50);
      return;
    }
    // 上下左右に安全なマージンを確保。
    // 特に下部フローティング操作バー（高さ約44px + 下余白12px = 56px）と上部ヘッダー境界に
    // キャラクターの頭や足、サードアイコードなどの装飾が重ならないよう安全マージンを設定
    const padX = 60; // 左右各 30px
    const padTop = 30; // 上部 30px
    const padBottom = 80; // 下部 80px (フローティングバー 56px + 24px)
    
    const availableWidth = Math.max(50, vpRect.width - padX);
    const availableHeight = Math.max(50, vpRect.height - (padTop + padBottom));
    
    const scaleX = availableWidth / elements.previewCanvas.width;
    const scaleY = availableHeight / elements.previewCanvas.height;
    // 画面枠から絶対にはみ出さないよう、縦横比を維持したまま最小の縮尺を採用
    const fitScale = Math.min(scaleX, scaleY, 1.0);
    
    // 上下余白の差分 (padBottom - padTop) を考慮して、キャンバスの垂直中央を微調整
    state.panX = 0;
    state.panY = Math.round((padTop - padBottom) / 2);
    setZoom(fitScale);
  }

  function applyCanvasTransform() {
    elements.canvasContainer.style.transform = `translate(${state.panX}px, ${state.panY}px) scale(${state.zoom})`;
  }

  function toggleFlipH() {
    state.flipH = !state.flipH;
    elements.btnFlipH.classList.toggle('active', state.flipH);
    renderComposite();
  }

  function updateDimsPreview() {
    if (!state.psdData) return;
    const w = Math.round(state.psdData.width * state.export.scale);
    const h = Math.round(state.psdData.height * state.export.scale);
    elements.exportDimsPreview.textContent = `出力サイズ: ${w} × ${h} px (${Math.round(state.export.scale * 100)}%)`;
  }

  // ==================== エクスポートエンジン ====================
  async function handleExport(saveToLocalServer = false) {
    if (!state.psdData) {
      showToast('エクスポートする立ち絵がありません', 'error');
      return;
    }

    const fmt = state.export.format;
    const filename = `${state.export.filename}.${fmt}`;
    setStatus(`エクスポート生成中 (${fmt.toUpperCase()})...`);

    try {
      let blob = null;
      let base64Data = null;

      if (fmt === 'png') {
        blob = await generateExportPNG();
      } else if (fmt === 'jpg') {
        blob = await generateExportJPG();
      } else if (fmt === 'pxd') {
        blob = await generateExportPXD();
      } else if (fmt === 'psd') {
        blob = await generateExportPSD();
      }

      if (!blob) throw new Error('データ生成に失敗しました');

      if (saveToLocalServer) {
        // ネイティブ通知用
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tohoStudio) {
            window.webkit.messageHandlers.tohoStudio.postMessage({
              action: "didExportImage",
              filename: filename,
              subfolder: state.currentCharName || "東方キャラ"
            });
          }
        } catch(e) {}

        // ローカルサーバー（動画用/手作り素材/psdtool/エクスポート）に直接保存
        base64Data = await blobToBase64(blob);
        const subfolder = state.currentCharName || '東方キャラ';
        
        const res = await fetch('/api/save_export', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            filename: filename,
            subfolder: subfolder,
            data: base64Data
          })
        });
        const json = await res.json();
        if (json.success) {
          showToast(`素材フォルダに保存完了: ${json.filename}`, 'success');
          setStatus(`保存完了: ${json.saved_path}`);
        } else {
          throw new Error(json.error);
        }
      } else {
        // Macのダウンロードフォルダへダウンロード
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        showToast(`ダウンロード開始: ${filename}`, 'success');
        setStatus(`エクスポート完了: ${filename}`);
      }

    } catch (e) {
      console.error(e);
      showToast(`エクスポート失敗: ${e.message}`, 'error');
      setStatus('エクスポート失敗');
    }
  }

  // PNG 生成
  function generateExportPNG() {
    return new Promise(resolve => {
      const scale = state.export.scale;
      const srcCanvas = elements.previewCanvas;
      
      if (scale === 1.0) {
        srcCanvas.toBlob(blob => resolve(blob), 'image/png');
      } else {
        const outCanvas = document.createElement('canvas');
        outCanvas.width = Math.round(srcCanvas.width * scale);
        outCanvas.height = Math.round(srcCanvas.height * scale);
        const oCtx = outCanvas.getContext('2d');
        oCtx.imageSmoothingEnabled = true;
        oCtx.imageSmoothingQuality = 'high';
        oCtx.drawImage(srcCanvas, 0, 0, outCanvas.width, outCanvas.height);
        outCanvas.toBlob(blob => resolve(blob), 'image/png');
      }
    });
  }

  // JPG 生成
  function generateExportJPG() {
    return new Promise(resolve => {
      const scale = state.export.scale;
      const srcCanvas = elements.previewCanvas;
      const outCanvas = document.createElement('canvas');
      outCanvas.width = Math.round(srcCanvas.width * scale);
      outCanvas.height = Math.round(srcCanvas.height * scale);
      const oCtx = outCanvas.getContext('2d');

      // 背景色で塗りつぶし
      oCtx.fillStyle = state.export.jpgBg || '#ffffff';
      oCtx.fillRect(0, 0, outCanvas.width, outCanvas.height);

      oCtx.imageSmoothingEnabled = true;
      oCtx.imageSmoothingQuality = 'high';
      oCtx.drawImage(srcCanvas, 0, 0, outCanvas.width, outCanvas.height);

      outCanvas.toBlob(blob => resolve(blob), 'image/jpeg', state.export.jpgQuality);
    });
  }

  // PXD (Pixelmator Pro / Pixlr レイヤー保持アーカイブ) 生成
  async function generateExportPXD() {
    if (!window.JSZip) throw new Error('JSZipライブラリが見つかりません');
    const zip = new window.JSZip();

    // Pixelmator Pro / Pixlr 互換パッケージ構造:
    // - manifest.json: ドキュメント情報、レイヤー一覧、可視性、不透明度、位置
    // - composite.png: 統合プレビュー画像
    // - layers/: 各レイヤーのRGBA画像 (PNG)

    const layersMeta = [];
    const layersFolder = zip.folder('layers');

    let layerIdx = 0;
    for (const layer of state.flatLayers) {
      if (layer.hidden) continue; // 非表示レイヤーも残すか？可視レイヤーを保持
      const canvas = layer.canvas;
      if (!canvas) continue;

      const layerFileName = `layer_${String(layerIdx).padStart(3, '0')}.png`;
      const pngBlob = await new Promise(r => canvas.toBlob(r, 'image/png'));
      layersFolder.file(layerFileName, pngBlob);

      layersMeta.push({
        id: layerIdx,
        name: layer.name,
        file: layerFileName,
        left: layer.left || 0,
        top: layer.top || 0,
        width: canvas.width,
        height: canvas.height,
        opacity: layer.opacity !== undefined ? layer.opacity : 1.0,
        blendMode: layer.blendMode || 'normal',
        visible: !layer.hidden
      });
      layerIdx++;
    }

    // 統合プレビュー
    const compBlob = await generateExportPNG();
    zip.file('composite.png', compBlob);

    // ドキュメントメタデータ
    const manifest = {
      format: 'PXD',
      version: '1.0',
      generator: 'Toho Character PSD Studio',
      width: elements.previewCanvas.width,
      height: elements.previewCanvas.height,
      character: state.currentCharName,
      layers: layersMeta
    };
    zip.file('manifest.json', JSON.stringify(manifest, null, 2));

    return await zip.generateAsync({ type: 'blob', compression: 'DEFLATE' });
  }

  // PSD (Photoshop / CLIP STUDIO 互換レイヤー保持PSD) 生成
  async function generateExportPSD() {
    if (!window.agPsd || !window.agPsd.writePsdBuffer) {
      throw new Error('PSDライター機能が見つかりません');
    }

    // 現在のレイヤー状態とキャンバスからエクスポート用PSDオブジェクトを構築
    const psdOut = {
      width: elements.previewCanvas.width,
      height: elements.previewCanvas.height,
      canvas: elements.previewCanvas,
      children: []
    };

    // 状態をクローンして反映
    function copyNode(node) {
      const copy = {
        name: node.name,
        hidden: !!node.hidden,
        opacity: node.opacity !== undefined ? node.opacity : 1.0,
        left: node.left || 0,
        top: node.top || 0
      };
      if (node.canvas) copy.canvas = node.canvas;
      else if (node.imageData) copy.imageData = node.imageData;
      if (node.children) {
        copy.children = node.children.map(copyNode);
      }
      return copy;
    }

    if (state.psdData.children) {
      psdOut.children = state.psdData.children.map(copyNode);
    }

    const buffer = window.agPsd.writePsdBuffer(psdOut);
    return new Blob([buffer], { type: 'image/vnd.adobe.photoshop' });
  }

  // 全表情差分の一括バッチエクスポート (ZIP)
  async function handleBatchExport() {
    if (!state.psdData || !window.JSZip) {
      showToast('PSDまたはJSZipが準備できていません', 'error');
      return;
    }

    setStatus('全表情プリセットの一括書き出し中...');
    showToast('全表情差分の書き出しを開始します...', 'success');

    try {
      const zip = new window.JSZip();
      const folderName = `${state.currentCharName}_表情差分`;
      const zipFolder = zip.folder(folderName);

      for (let i = 0; i < PRESETS_DEF.length; i++) {
        const preset = PRESETS_DEF[i];
        setStatus(`書き出し中 (${i + 1}/${PRESETS_DEF.length}): ${preset.name}...`);

        applyExpressionPreset(preset);
        await new Promise(r => setTimeout(r, 60)); // レンダリング待ち

        const blob = await generateExportPNG();
        const fname = `${String(i + 1).padStart(2, '0')}_${preset.name}.png`;
        zipFolder.file(fname, blob);
      }

      setStatus('ZIPアーカイブ生成中...');
      const zipBlob = await zip.generateAsync({ type: 'blob' });

      // ダウンロード
      const url = URL.createObjectURL(zipBlob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${folderName}.zip`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      showToast(`全 ${PRESETS_DEF.length} 種の表情差分をZIP保存しました！`, 'success');
      setStatus('一括エクスポート完了');

    } catch (e) {
      console.error(e);
      showToast(`一括書き出しエラー: ${e.message}`, 'error');
      setStatus('一括書き出しエラー');
    }
  }

  // ==================== ユーティリティ ====================
  function blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  }

  function setStatus(text) {
    elements.statusText.textContent = text;
  }

  function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `<span>${type === 'success' ? '✅' : type === 'error' ? '❌' : 'ℹ️'}</span><span>${escapeHtml(message)}</span>`;
    elements.toastContainer.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(10px)';
      toast.style.transition = 'all 0.3s';
      setTimeout(() => toast.remove(), 300);
    }, 3500);
  }

  function escapeHtml(str) {
    return (str || '').replace(/[&<>"']/g, m => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    }[m]));
  }

  // アプリ起動
  window.addEventListener('DOMContentLoaded', init);

})();
