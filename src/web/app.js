// ゆっくりボイスメーカー準拠ボイステンプレート
const VOICE_TEMPLATES = [
  { name: "-- テンプレートを選択 --", value: "" },
  { name: "博麗霊夢 (れいむ: f1, 100%, 100%)", voice: "f1", speed: 100, pitch: 100 },
  { name: "霧雨魔理沙 (まりさ: f2, 100%, 100%)", voice: "f2", speed: 100, pitch: 100 },
  { name: "操夢 (そうむ: imd1, 100%, 100%)", voice: "imd1", speed: 100, pitch: 100 },
  { name: "フランドール (ふらん: jgr, 100%, 100%)", voice: "jgr", speed: 100, pitch: 100 },
  { name: "レミリア (れみりあ: f1, 80%, 150%)", voice: "f1", speed: 80, pitch: 150 },
  { name: "十六夜咲夜 (さくや: f1, 105%, 125%)", voice: "f1", speed: 105, pitch: 125 },
  { name: "パチュリー (ぱちゅりー: f2, 120%, 115%)", voice: "f2", speed: 120, pitch: 115 },
  { name: "古明地さとり (さとり: jgr, 115%, 125%)", voice: "jgr", speed: 115, pitch: 125 },
  { name: "古明地こいし (こいし: f2, 50%, 181%)", voice: "f2", speed: 50, pitch: 181 },
  { name: "魂魄妖夢 (ようむ: f2, 115%, 120%)", voice: "f2", speed: 115, pitch: 120 },
  { name: "チルノ (ちるの: f2, 115%, 120%)", voice: "f2", speed: 115, pitch: 120 },
  { name: "アリス (ありす: f1, 110%, 130%)", voice: "f1", speed: 110, pitch: 130 },
  { name: "東風谷早苗 (さなえ: f1, 130%, 95%)", voice: "f1", speed: 130, pitch: 95 },
  { name: "射命丸文 (しゃめいまる: f2, 100%, 125%)", voice: "f2", speed: 100, pitch: 125 },
  { name: "河城にとり (にとり: jgr, 105%, 105%)", voice: "jgr", speed: 105, pitch: 105 },
  { name: "犬走椛 (もみじ: f1, 120%, 110%)", voice: "f1", speed: 120, pitch: 110 },
  { name: "森近霖之助 (こーりん: m1, 100%, 105%)", voice: "m1", speed: 100, pitch: 105 },
  { name: "藤原妹紅 (もこう: f2, 100%, 120%)", voice: "f2", speed: 100, pitch: 120 },
  { name: "鈴仙 (うどんげ: f1, 80%, 120%)", voice: "f1", speed: 80, pitch: 120 },
  { name: "蓬莱山輝夜 (かぐや: f1, 100%, 120%)", voice: "f1", speed: 100, pitch: 120 },
  { name: "八意永琳 (えいりん: f1, 90%, 120%)", voice: "f1", speed: 90, pitch: 120 },
  { name: "八雲紫 (ゆかり: f1, 100%, 100%)", voice: "f1", speed: 100, pitch: 100 },
  { name: "伊吹萃香 (すいか: imd1, 100%, 150%)", voice: "imd1", speed: 100, pitch: 150 },
  { name: "四季映姫 (えいき: f2, 87%, 117%)", voice: "f2", speed: 87, pitch: 117 },
  { name: "霊烏路空 (おくう: imd1, 80%, 170%)", voice: "imd1", speed: 80, pitch: 170 },
  { name: "多々良小傘 (こがさ: imd1, 110%, 130%)", voice: "imd1", speed: 110, pitch: 130 },
  { name: "八坂神奈子 (かなこ: f1, 115%, 90%)", voice: "f1", speed: 115, pitch: 90 },
  { name: "洩矢諏訪子 (すわこ: f1, 80%, 175%)", voice: "f1", speed: 80, pitch: 175 },
  { name: "サニーミルク (さにー: jgr, 125%, 120%)", voice: "jgr", speed: 125, pitch: 120 },
  { name: "ルナチャイルド (るな: f2, 120%, 125%)", voice: "f2", speed: 120, pitch: 125 },
  { name: "因幡てゐ (てゐ: imd1, 110%, 120%)", voice: "imd1", speed: 110, pitch: 120 },
  { name: "比那名居天子 (てんこ: f2, 75%, 134%)", voice: "f2", speed: 75, pitch: 134 },
  { name: "寅丸星 (とらまる: f2, 120%, 110%)", voice: "f2", speed: 120, pitch: 110 },
  { name: "ナズーリン (なずーりん: f1, 90%, 115%)", voice: "f1", speed: 90, pitch: 115 },
  { name: "封獣ぬえ (ぬえ: f2, 100%, 180%)", voice: "f2", speed: 100, pitch: 180 },
  { name: "姫海棠はたて (はたて: f2, 84%, 121%)", voice: "f2", speed: 84, pitch: 121 },
  { name: "水橋パルスィ (ぱるすぃ: f2, 80%, 130%)", voice: "f2", speed: 80, pitch: 130 },
  { name: "聖白蓮 (ひじり: imd1, 102%, 97%)", voice: "imd1", speed: 102, pitch: 97 },
  { name: "ミスティア (みすちー: f1, 100%, 105%)", voice: "f1", speed: 100, pitch: 105 },
  { name: "黒谷ヤマメ (やまめ: f2, 110%, 115%)", voice: "f2", speed: 110, pitch: 115 },
  { name: "リグル (りぐる: m1, 110%, 140%)", voice: "m1", speed: 110, pitch: 140 },
  { name: "リリーホワイト (りりー: f1, 110%, 115%)", voice: "f1", speed: 110, pitch: 115 },
  { name: "リリカ (りりか: f1, 95%, 135%)", voice: "f1", speed: 95, pitch: 135 },
  { name: "雲居一輪 (いちりん: f2, 65%, 145%)", voice: "f2", speed: 65, pitch: 145 },
  { name: "きめぇまる (m1, 80%, 140%)", voice: "m1", speed: 80, pitch: 140 }
];

const App = {
  config: null,
  project: null,
  currentSceneIndex: 0,
  currentDirectory: "/",
  filePickerMode: null,
  
  // 履歴管理 (Undo / Redo)
  undoStack: [],
  redoStack: [],
  clipboardScenes: [],
  
  // 再生管理
  isPlaying: false,
  isAnimPreviewPlaying: false,
  playheadTime: 0.0,
  totalDuration: 0.0,
  playbackTimer: null,
  isLoop: false,
  timelineZoom: 1.0,
  showTelopOverlay: false,
  selectedSceneIndices: new Set(),
  sceneOffsetsCache: [],
  
  // 世代管理・非同期競合防止
  _playSessionId: 0,
  _currentTtsAbortController: null,
  _activeAudioSourceNodes: [],
  _noVoiceTimer: null,
  _activeSceneSeNodes: [],
  _activeSpanSeMap: null,
  
  // マーカー (In点 / Out点)
  markerIn: null,
  markerOut: null,
  
  // オーディオ再生用
  audioElement: new Audio(),
  bgmElement: new Audio(),
  seElement: new Audio(),

  // ==========================================
  // ダブルバッファリング機構 (タイムラグ0秒・完全シームレスプレビュー切り替え)
  // ==========================================
  _activeMediaChannel: 'a', // 'a' (preview-image, preview-video) | 'b' (preview-image-b, preview-video-b)
  _preloadedSceneIndex: -1,

  getActiveMediaElements() {
    const isA = (this._activeMediaChannel === 'a');
    return {
      img: document.getElementById(isA ? "preview-image" : "preview-image-b") || document.getElementById("preview-image"),
      video: document.getElementById(isA ? "preview-video" : "preview-video-b") || document.getElementById("preview-video"),
      channel: this._activeMediaChannel
    };
  },

  getInactiveMediaElements() {
    const isA = (this._activeMediaChannel === 'a');
    return {
      img: document.getElementById(isA ? "preview-image-b" : "preview-image") || document.getElementById("preview-image-b"),
      video: document.getElementById(isA ? "preview-video-b" : "preview-video") || document.getElementById("preview-video-b"),
      channel: isA ? 'b' : 'a'
    };
  },

  // ==========================================
  // ノート・テキスト・ビルド・トランジションのアニメーション包括判定
  // ==========================================
  hasAnimationInstruction(notes, text, builds = null, hasTransition = false) {
    if (builds && Array.isArray(builds) && builds.length > 0) return true;
    if (hasTransition) return true;

    const notesStr = (notes || "").toString().trim();
    const textStr = (text || "").toString().trim();
    const targetStr = notesStr ? notesStr : textStr;
    if (!targetStr) return false;

    // 1. 連動キーワード ([アニメーションに合わせる], [アニメ連動] など)
    if (/[\[【\(\（［](?:アニメーションに合わせる|アニメに合わせる|アニメ連動|アニメーション連動|アニメーション時間)[\]】\)\）］]/i.test(targetStr)) return true;
    // 2. 表示時間 / 総時間指定 ([表示時間: 4.0秒], [時間: 4s], [duration: 4.0] など)
    if (/[\[【\(\（［](?:表示時間|スライド時間|総時間|duration|time|時間)\s*[:：=＝]\s*\d+(?:\.\d+)?\s*(?:秒|s|sec|seconds)?[\]】\)\）］]/i.test(targetStr)) return true;
    // 3. アニメーション待機時間 / 遅延指定 ([アニメ: 2.0秒], [待機: 1.5s], [delay: 2] など)
    if (/[\[【\(\（［](?:アニメーション|アニメ|待機時間|待機|遅延|余白|delay|anim)\s*[:：=＝]\s*\d+(?:\.\d+)?\s*(?:秒|s|sec|seconds)?[\]】\)\）］]/i.test(targetStr)) return true;
    // 4. 動画・クリップ明示タグ ([動画], [動画クリップ], [video] など)
    if (/[\[【\(\（［](?:動画|動画クリップ|video|movie|clip)[\]】\)\）］]/i.test(targetStr)) return true;
    // 5. 無音キーワード ((無音), 音声なし など)
    if (/[\[【\(\（［](?:無音|音声なし|無音スライド)[\]】\)\）］]|(?:^|\n)(?:無音|音声なし)(?:\n|$)/i.test(targetStr)) return true;

    return false;
  },

  // ==========================================
  // シーンメディア照合 (スライド画像・スライド動画・音声) & 比較判定
  // ==========================================
  getSceneMediaComparison(scene) {
    if (!scene) {
      return {
        isVideoMode: false,
        sceneDuration: 0.5,
        audioDur: 0.0,
        videoDur: 0.0,
        imgPath: null,
        videoClip: null,
        audioPath: null,
        isNoVoice: true
      };
    }

    const pName = (this.project && this.project.project_name) ? this.project.project_name : "";
    const sName = (this.project && this.project.series_name) ? this.project.series_name : "交換夫婦";
    const sIdx = scene.slide_index || (this.currentSceneIndex + 1);
    const sNum = sIdx < 10 ? `00${sIdx}` : (sIdx < 100 ? `0${sIdx}` : `${sIdx}`);

    // 1. スライド画像パス解決（常に最優先で解決・表示可能にする）
    let imgPath = scene.image_path || null;
    if (!imgPath && pName) {
      imgPath = `${sName}/スライド画像/${pName}/${pName}.${sNum}.jpeg`;
    }

    // 2. アニメーション指示・ビルド・自動トランジションの判定
    const sBuilds = scene.builds || [];
    const sHasAuto = Boolean(scene.transition_automatic && parseFloat(scene.transition_delay || 0.0) > 0);
    const isAnimInstructed = this.hasAnimationInstruction(scene.notes, scene.text, sBuilds, sHasAuto);
    const hasAnim = Boolean(scene.has_animation || isAnimInstructed);
    let videoClip = hasAnim ? (scene.video_clip_path || scene.animation_path || null) : null;

    // 3. 音声パス解決
    let audioPath = scene.audio_path || null;
    if (!audioPath && pName) {
      audioPath = `${sName}/音声/${pName}/slide_${sNum}.wav`;
    }

    // 4. 音声尺・動画尺・余白の判定
    const isNoVoice = (scene.no_voice === true || scene.is_skipped === true || scene.is_enabled === false);
    const audioDur = (isNoVoice || !scene.audio_duration) ? 0.0 : parseFloat(scene.audio_duration);
    const videoDur = hasAnim ? parseFloat(scene.video_duration || scene.animation_duration || 0.0) : 0.0;
    const extraDelay = (hasAnim || isNoVoice) ? parseFloat(scene.extra_delay || 0.0) : 0.0;

    // アニメーション指定があり、動画が存在する場合に動画モードとして判定
    const isVideoMode = Boolean(hasAnim && videoClip && (videoDur > audioDur || isNoVoice || (extraDelay > 0 && videoDur > 0)));

    let sceneDuration = 0.5;
    if (isVideoMode && videoDur > 0) {
      sceneDuration = videoDur;
    } else {
      if (isNoVoice) {
        const padDur = parseFloat(scene.extra_delay !== undefined ? scene.extra_delay : 2.0);
        sceneDuration = Math.max(1.0, padDur);
      } else if (hasAnim) {
        sceneDuration = Math.max(0.3, audioDur + extraDelay);
      } else {
        // 単純なセリフのみのシーン: セリフ・音声ファイルの長さにシーン長をぴったり合わせる
        sceneDuration = Math.max(0.3, audioDur);
      }
    }

    return {
      isVideoMode,
      sceneDuration,
      audioDur,
      videoDur,
      imgPath,
      videoClip,
      audioPath,
      isNoVoice
    };
  },

  // シーン時間・開始時間・再生位置ヘルパー
  getSceneDuration(s) {
    if (!s) return 0.5;
    const comp = this.getSceneMediaComparison(s);
    return comp.sceneDuration;
  },

  getSceneStartTime(index) {
    if (!this.project || !this.project.scenes || index <= 0) return 0.0;
    const scenes = this.project.scenes;
    const count = Math.min(index, scenes.length);
    let startTime = 0.0;

    if (this.sceneOffsetsCache && this.sceneOffsetsCache.length === scenes.length) {
      for (let i = 0; i < count; i++) {
        startTime += (this.sceneOffsetsCache[i].duration || 1.0);
      }
      return startTime;
    }

    for (let i = 0; i < count; i++) {
      startTime += this.getSceneDuration(scenes[i]);
    }
    return startTime;
  },

  getVideoTargetTime(scene, offsetSec = 0.0) {
    if (!scene) return 0.0;
    const comp = this.getSceneMediaComparison(scene);
    const videoClip = comp.videoClip;
    if (!videoClip) return 0.0;

    const isGlobalMovie = Boolean(this.project && this.project.video_source && videoClip === this.project.video_source);
    let startTime = 0.0;

    if (isGlobalMovie) {
      if (scene.video_start_time !== undefined && scene.video_start_time !== null && parseFloat(scene.video_start_time) > 0) {
        startTime = parseFloat(scene.video_start_time);
      } else {
        const sIdx = this.project && this.project.scenes ? this.project.scenes.indexOf(scene) : -1;
        startTime = this.getSceneStartTime(sIdx !== -1 ? sIdx : this.currentSceneIndex);
      }
    } else {
      // 個別クリップ動画 (slide_XXX.mp4) はファイル先頭が 0.0 秒基準
      startTime = 0.0;
    }

    return Math.max(0.0, startTime + Math.max(0.0, offsetSec || 0.0));
  },

  // 直近次シーンメディアを裏バッファに事前先行デコード＆ロード（タイムラグ0秒化）
  preloadUpcomingMedia(sceneIndex) {
    if (!this.project || !this.project.scenes) return;
    if (sceneIndex < 0 || sceneIndex >= this.project.scenes.length) return;

    // 音声の先行バッファリング (直近4シーン)
    this.preloadSceneAudio(sceneIndex, 4);

    // 後続3シーンの画像キャッシュプリフェッチ (ブラウザメモリキャッシュ)
    for (let i = sceneIndex; i < Math.min(this.project.scenes.length, sceneIndex + 3); i++) {
      const sc = this.project.scenes[i];
      if (sc) {
        const comp = this.getSceneMediaComparison(sc);
        if (comp.imgPath) {
          const preImg = new Image();
          preImg.src = `/media/${encodeURIComponent(comp.imgPath)}`;
        }
      }
    }

    // 直近次シーン (sceneIndex) を裏バッファ（非アクティブチャンネル）に先頭フレームまでデコード待機
    const nextScene = this.project.scenes[sceneIndex];
    if (!nextScene) return;

    const nextComp = this.getSceneMediaComparison(nextScene);
    const inactive = this.getInactiveMediaElements();
    if (!inactive.video || !inactive.img) return;

    this._preloadedSceneIndex = sceneIndex;

    // 1. 画像の裏バッファ設定
    if (nextComp.imgPath) {
      const imgUrl = `/media/${encodeURIComponent(nextComp.imgPath)}`;
      if (inactive.img.src !== window.location.origin + imgUrl && inactive.img.src !== imgUrl) {
        inactive.img.src = imgUrl;
      }
      inactive.img.style.display = "block";
      inactive.img.style.zIndex = "2";
    }

    // 2. 動画の裏バッファ先行ロード (先頭0.00秒でデコード待機)
    if (nextComp.isVideoMode && nextComp.videoClip) {
      const videoUrl = `/media/${encodeURIComponent(nextComp.videoClip)}`;
      const targetTime = this.getVideoTargetTime(nextScene, 0.0);
      inactive.video._targetTime = targetTime;

      const isSameSrc = (inactive.video.src === window.location.origin + videoUrl || inactive.video.src === videoUrl);
      if (!isSameSrc) {
        try { inactive.video.pause(); } catch(e) {}
        inactive.video.src = videoUrl;
        inactive.video.load();
      }

      inactive.video.onloadedmetadata = () => {
        try {
          inactive.video.currentTime = targetTime;
        } catch(e) {}
      };
      if (inactive.video.readyState >= 1) {
        try {
          inactive.video.currentTime = targetTime;
        } catch(e) {}
      }
    } else {
      try { inactive.video.pause(); } catch(e) {}
      inactive.video.style.display = "none";
    }
  },

  syncPreviewVideo(scene, offsetSec = 0.0, shouldPlay = false, comp = null) {
    const active = this.getActiveMediaElements();
    const video = active.video;
    const img = active.img;
    if (!video) return;

    const mediaComp = comp || this.getSceneMediaComparison(scene);

    if (!scene || !mediaComp.isVideoMode || !mediaComp.videoClip) {
      try { video.pause(); } catch(e) {}
      video.style.display = "none";
      if (img) {
        img.style.display = "block";
        img.style.zIndex = "3";
      }
      return;
    }

    const videoClip = mediaComp.videoClip;
    const videoUrl = `/media/${encodeURIComponent(videoClip)}`;
    const targetTime = this.getVideoTargetTime(scene, offsetSec);
    video._targetTime = targetTime;

    // スライド画像は常にベースポスターとして下層に表示（黒画面を完全防止）
    if (mediaComp.imgPath && img) {
      const imgUrl = `/media/${encodeURIComponent(mediaComp.imgPath)}`;
      if (img.src !== window.location.origin + imgUrl && img.src !== imgUrl) {
        img.src = imgUrl;
      }
      img.style.display = "block";
      img.style.zIndex = "2";
    }

    const isSameSrc = (video.src === window.location.origin + videoUrl || video.src === videoUrl);

    const applySeekAndState = () => {
      try {
        const maxDur = (!isNaN(video.duration) && video.duration > 0) ? video.duration : (mediaComp.videoDur || Infinity);
        video.currentTime = Math.min(maxDur, Math.max(0.0, video._targetTime));
      } catch(e) {}

      video.style.display = "block";
      video.style.zIndex = "4";

      if (shouldPlay && this.isPlaying) {
        video.play().catch(e => {
          if (e && e.name !== "AbortError") console.warn("[Preview Video] play error:", e);
        });
      } else {
        try { video.pause(); } catch(e) {}
      }
    };

    video.onerror = () => {
      video.style.display = "none";
      if (img) {
        img.style.display = "block";
        img.style.zIndex = "3";
      }
    };

    if (!isSameSrc) {
      try { video.pause(); } catch(e) {}
      video.onloadedmetadata = () => {
        if (!scene.video_duration && video.duration && !isNaN(video.duration)) {
          scene.video_duration = video.duration;
          scene.animation_duration = video.duration;
        }
        applySeekAndState();
      };
      video.src = videoUrl;
    } else {
      if (video.readyState >= 1) {
        applySeekAndState();
      } else {
        video.onloadedmetadata = () => {
          applySeekAndState();
        };
      }
    }
  },

  getCurrentPlayheadSceneIndex() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return 0;
    const targetSec = Math.max(0, this.playheadTime || 0);

    if (this.sceneOffsetsCache && this.sceneOffsetsCache.length === this.project.scenes.length) {
      let accTime = 0.0;
      for (let i = 0; i < this.sceneOffsetsCache.length; i++) {
        const dur = this.sceneOffsetsCache[i].duration || 1.0;
        if (targetSec >= accTime && targetSec < (accTime + dur - 0.0001)) {
          return i;
        }
        accTime += dur;
      }
      return this.sceneOffsetsCache.length - 1;
    }

    let accTime = 0.0;
    for (let i = 0; i < this.project.scenes.length; i++) {
      const dur = this.getSceneDuration(this.project.scenes[i]);
      if (targetSec >= accTime && targetSec < (accTime + dur - 0.0001)) {
        return i;
      }
      accTime += dur;
    }
    return Math.max(0, this.project.scenes.length - 1);
  },

  getTimeInfoFromTimelineX(clientX) {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return null;
    const scrollArea = document.getElementById("timeline-scroll-area");
    if (!scrollArea) return null;

    const rect = scrollArea.getBoundingClientRect();
    const clickX = (clientX - rect.left) + scrollArea.scrollLeft;
    const trackX = Math.max(0, clickX - 120); // ヘッダー幅 120px 控除

    if (!this.sceneOffsetsCache || this.sceneOffsetsCache.length === 0) {
      return { playheadTime: 0.0, sceneIndex: 0, offsetInScene: 0.0 };
    }

    let accTime = 0.0;
    for (let i = 0; i < this.sceneOffsetsCache.length; i++) {
      const off = this.sceneOffsetsCache[i];
      const stPx = off.leftPx;
      const endPx = off.leftPx + off.widthPx;

      if (trackX >= stPx && trackX <= endPx) {
        const ratio = off.widthPx > 0 ? Math.max(0, Math.min(1.0, (trackX - stPx) / off.widthPx)) : 0;
        const offsetInScene = off.duration * ratio;
        const playheadTime = accTime + offsetInScene;
        return {
          playheadTime: Math.min(this.totalDuration, Math.max(0, playheadTime)),
          sceneIndex: i,
          offsetInScene: offsetInScene
        };
      }
      accTime += off.duration;
    }

    // タイムラインの右端を超えている場合
    const lastIdx = this.sceneOffsetsCache.length - 1;
    const lastOff = this.sceneOffsetsCache[lastIdx];
    return {
      playheadTime: this.totalDuration,
      sceneIndex: lastIdx,
      offsetInScene: lastOff ? lastOff.duration : 0.0
    };
  },

  setupTimelineClick() {
    const scrollArea = document.getElementById("timeline-scroll-area");
    if (!scrollArea || scrollArea._hasClickListener) return;
    scrollArea._hasClickListener = true;

    let isScrubbing = false;

    const handleSeekAtX = (clientX) => {
      const timeInfo = this.getTimeInfoFromTimelineX(clientX);
      if (!timeInfo) return;

      this.playheadTime = timeInfo.playheadTime;
      this.selectScene(timeInfo.sceneIndex, false, timeInfo.offsetInScene);
      this.updatePlayheadDisplay(false);
    };

    scrollArea.addEventListener("mousedown", (e) => {
      // ボタン、入力フォーム、SE/BGM編集ブロック内のインタラクションは通常動作を優先
      if (e.target.closest("button") || e.target.closest("input") || e.target.closest("select") || e.target.closest(".track-header") || e.target.closest(".se-clip") || e.target.closest(".bgm-clip")) {
        return;
      }

      if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;

      const rect = scrollArea.getBoundingClientRect();
      const clickX = (e.clientX - rect.left) + scrollArea.scrollLeft;
      if (clickX < 120) return; // ヘッダー領域

      isScrubbing = true;
      if (this.isPlaying) {
        this.stopAllAudioAndTimers(true);
      }

      handleSeekAtX(e.clientX);
    });

    window.addEventListener("mousemove", (e) => {
      if (!isScrubbing) return;
      handleSeekAtX(e.clientX);
    });

    window.addEventListener("mouseup", () => {
      if (isScrubbing) {
        isScrubbing = false;
        if (this.isPlaying) {
          this.play();
        }
      }
    });
  },

  // 初期化
  async init() {
    console.log("[App] Initializing Toho Project Movie Maker...");
    await this.loadConfig();
    this.setupAudioListeners();
    this.setupKeyboardShortcuts();
    this.setupFullscreenListeners();
    this.setupTimelineClick();
    this.startPlayheadTimer();
    this.renderCharacterOptions();
    this.renderVoiceTemplates();
    this.loadSoundEffects();
    this.updateUndoRedoButtons();
    this.setupDragAndDrop();

    // 10分おき自動バックアップタイマー (最大10世代 / 100分前まで巻き戻し可能)
    setInterval(() => {
      if (this.project && this.project.scenes && this.project.scenes.length > 0) {
        fetch("/api/project/backup_now", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ project: this.project })
        }).catch(() => {});
      }
    }, 600000);
  },

  renderVoiceTemplates() {
    const inspTmpl = document.getElementById("insp-template-select");
    const popupTmpl = document.getElementById("popup-template-select");

    const htmlParts = VOICE_TEMPLATES.map((t, idx) => {
      if (idx === 0) return `<option value="">${t.name}</option>`;
      return `<option value="${idx}">${t.name}</option>`;
    });

    if (inspTmpl) inspTmpl.innerHTML = htmlParts.join("");
    if (popupTmpl) popupTmpl.innerHTML = htmlParts.join("");
  },

  async loadConfig() {
    try {
      const res = await fetch("/api/config");
      const data = await res.json();
      this.config = data;
      this.currentDirectory = data.project_root || "/";

      // 既存のプロジェクトがあれば自動復元可能
      if (data.current_project && data.current_project.scenes && data.current_project.scenes.length > 0) {
        this.project = data.current_project;
        this.preloadAllSceneAudio();
      }
    } catch (e) {
      console.error("Config load failed:", e);
    }
  },

  async loadSoundEffects() {
    try {
      const res = await fetch("/api/sound_effects");
      const data = await res.json();
      if (data.success && data.effects) {
        this.soundEffectsList = data.effects;
        const inspSelect = document.getElementById("insp-se-select");
        const popupSelect = document.getElementById("popup-se-select");

        const optionsHtml = ['<option value="">(効果音なし)</option>'];
        data.effects.forEach(eff => {
          optionsHtml.push(`<option value="${eff.path}">[${eff.category}] ${eff.name}</option>`);
        });

        if (inspSelect) inspSelect.innerHTML = optionsHtml.join("");
        if (popupSelect) popupSelect.innerHTML = optionsHtml.join("");
      }
    } catch (e) {
      console.warn("Sound effects load failed:", e);
    }
  },

  audioCtx: null,
  _audioBufferCache: new Map(),

  getAudioContext() {
    if (!this.audioCtx) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      this.audioCtx = new AudioContext();
    }
    if (this.audioCtx.state === "suspended") {
      this.audioCtx.resume();
    }
    return this.audioCtx;
  },

  async getAudioBuffer(audioSrc) {
    if (!audioSrc) return null;
    if (this._audioBufferCache.has(audioSrc)) {
      return this._audioBufferCache.get(audioSrc);
    }

    try {
      const ctx = this.getAudioContext();
      let arrayBuffer = null;

      if (audioSrc.startsWith("data:audio/wav;base64,")) {
        const base64 = audioSrc.replace("data:audio/wav;base64,", "");
        const binaryStr = atob(base64);
        const len = binaryStr.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = binaryStr.charCodeAt(i);
        }
        arrayBuffer = bytes.buffer.slice(0);
      } else {
        const res = await fetch(audioSrc);
        arrayBuffer = await res.arrayBuffer();
      }

      const decodedBuffer = await ctx.decodeAudioData(arrayBuffer);
      this._audioBufferCache.set(audioSrc, decodedBuffer);
      return decodedBuffer;
    } catch (e) {
      console.warn("[Audio] Decode buffer failed for:", audioSrc, e);
      return null;
    }
  },

  preloadSceneAudio(startIndex = 0, count = 6) {
    if (!this.project || !this.project.scenes) return;
    const scenes = this.project.scenes;
    for (let i = startIndex; i < Math.min(scenes.length, startIndex + count); i++) {
      const s = scenes[i];
      if (s && s.audio_path) {
        let url = `/media/${encodeURIComponent(s.audio_path)}`;
        if (s._cacheBuster) url += `?t=${s._cacheBuster}`;
        if (!this._audioBufferCache.has(url)) {
          this.getAudioBuffer(url).catch(() => {});
        }
      }
    }
  },

  preloadAllSceneAudio() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;
    const scenes = this.project.scenes;
    let idx = 0;
    const loadNextBatch = () => {
      const batch = scenes.slice(idx, idx + 8);
      idx += 8;
      if (batch.length === 0) return;
      Promise.all(batch.map(s => {
        if (s && s.audio_path) {
          let url = `/media/${encodeURIComponent(s.audio_path)}`;
          if (s._cacheBuster) url += `?t=${s._cacheBuster}`;
          return this.getAudioBuffer(url).catch(() => {});
        }
        return Promise.resolve();
      })).then(() => {
        if (idx < scenes.length) {
          setTimeout(loadNextBatch, 30);
        }
      });
    };
    loadNextBatch();
  },

  updateActiveSceneHighlight() {
    // 1. 左側メディアグリッドのアクティブ切り替え (DOM全再構築せずクラス操作のみで超高速化)
    const prevActive = document.querySelector("#extracted-media-list .media-card.active");
    if (prevActive) prevActive.classList.remove("active");
    const newActive = document.getElementById(`media-card-${this.currentSceneIndex}`);
    if (newActive) {
      newActive.classList.add("active");
      newActive.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }

    // 2. タイムライン上のハイライト
    const prevClip = document.querySelector("#track-video-clips .tl-clip.selected");
    if (prevClip) prevClip.classList.remove("selected");
    const vClips = document.querySelectorAll("#track-video-clips .tl-clip");
    if (vClips && vClips[this.currentSceneIndex]) {
      vClips[this.currentSceneIndex].classList.add("selected");
    }
  },

  // ==========================================
  // 全オーディオ・タイマー・非同期通信の完全停止・クリーンアップ
  // ==========================================
  stopAllAudioAndTimers(invalidateSession = true) {
    if (invalidateSession) {
      this._playSessionId = (this._playSessionId || 0) + 1;
    }
    if (this._currentTtsAbortController) {
      try { this._currentTtsAbortController.abort(); } catch(e) {}
      this._currentTtsAbortController = null;
    }
    if (this._noVoiceTimer) {
      clearTimeout(this._noVoiceTimer);
      this._noVoiceTimer = null;
    }
    if (this._sceneTransitionTimer) {
      clearTimeout(this._sceneTransitionTimer);
      this._sceneTransitionTimer = null;
    }
    this._scenePlayStartTime = null;

    if (this._activeAudioSourceNodes && Array.isArray(this._activeAudioSourceNodes)) {
      this._activeAudioSourceNodes.forEach(node => {
        try { node.stop(); } catch(e) {}
        try { node.disconnect(); } catch(e) {}
      });
      this._activeAudioSourceNodes = [];
    }
    if (this._currentSourceNode) {
      try { this._currentSourceNode.stop(); } catch (e) {}
      try { this._currentSourceNode.disconnect(); } catch (e) {}
      this._currentSourceNode = null;
    }
    // シーン個別SEタイマー・ノードの全停止
    if (this._activeSceneSeNodes && Array.isArray(this._activeSceneSeNodes)) {
      this._activeSceneSeNodes.forEach(item => {
        if (item.timer) clearTimeout(item.timer);
        if (item.handle) {
          try { item.handle.stop(); } catch(e) {}
        }
      });
      this._activeSceneSeNodes = [];
    }
    // タイムライン連続SEの全停止
    if (this._activeSpanSeMap) {
      for (const [id, handle] of this._activeSpanSeMap.entries()) {
        try { handle.stop(); } catch(e) {}
      }
      this._activeSpanSeMap.clear();
    }

    // HTML5 Audio 要素の完全停止
    try {
      this.audioElement.pause();
      this.audioElement.onended = null;
    } catch(e) {}

    try {
      this.bgmElement.pause();
    } catch(e) {}

    try {
      this.seElement.pause();
    } catch(e) {}

    // プレビュー動画の停止 (チャンネルA・B両方)
    ["preview-video", "preview-video-b"].forEach(id => {
      const el = document.getElementById(id);
      if (el) {
        try {
          el.pause();
          el.onended = null;
          el.playbackRate = 1.0;
        } catch(e) {}
      }
    });
  },

  async playAudioSafely(audioSrc, onEndedCallback = null) {
    if (!audioSrc) return;

    // 1. Data URI の場合、Web Audio API AudioContext によるダイレクトデコード再生（最も確実・高音質・遅延ゼロ）
    if (audioSrc.startsWith("data:audio/wav;base64,")) {
      try {
        const ctx = this.getAudioContext();
        const base64 = audioSrc.replace("data:audio/wav;base64,", "");
        const binaryStr = atob(base64);
        const len = binaryStr.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = binaryStr.charCodeAt(i);
        }
        
        const bufferCopy = bytes.buffer.slice(0);
        const audioBuffer = await ctx.decodeAudioData(bufferCopy);
        const source = ctx.createBufferSource();
        source.buffer = audioBuffer;
        source.connect(ctx.destination);
        
        if (!this._activeAudioSourceNodes) this._activeAudioSourceNodes = [];
        this._activeAudioSourceNodes.push(source);
        source.onended = () => {
          const idx = this._activeAudioSourceNodes.indexOf(source);
          if (idx !== -1) this._activeAudioSourceNodes.splice(idx, 1);
          if (typeof onEndedCallback === "function") {
            onEndedCallback();
          }
        };
        
        source.start(0);
        return;
      } catch (webaudioErr) {
        console.warn("[Audio] Web Audio API decode failed, fallback to HTML5 Audio element:", webaudioErr);
      }
    }

    // 2. HTML5 Audio 要素によるフォールバック再生
    try {
      this.audioElement.src = audioSrc;
      this.audioElement.volume = 1.0;
      this.audioElement.onended = () => {
        if (typeof onEndedCallback === "function") {
          onEndedCallback();
        }
      };
      await this.audioElement.play();
    } catch (err) {
      console.warn("[Audio] playAudioSafely Audio element error:", err);
    }
  },

  setupAudioListeners() {
    // シーン遷移は _sceneTransitionTimer でタイムライン全体の正確なシーン時間に基づいて制御
    this.audioElement.onended = () => {};
  },

  renderCharacterOptions() {
    if (!this.config || !this.config.characters) return;
    const chars = this.config.characters;

    const inspSelect = document.getElementById("insp-character-select");
    const popupSelect = document.getElementById("popup-character");

    [inspSelect, popupSelect].forEach(sel => {
      if (!sel) return;
      sel.innerHTML = "";
      Object.keys(chars).forEach(name => {
        const c = chars[name];
        const opt = document.createElement("option");
        opt.value = name;
        opt.textContent = `${name} (${c.description})`;
        sel.appendChild(opt);
      });
    });
  },

  // ==========================================
  // 画面遷移管理
  // ==========================================
  showScreen(screenId) {
    document.querySelectorAll(".screen").forEach(s => {
      s.classList.remove("active");
      s.style.display = "none";
    });
    const target = document.getElementById(screenId);
    if (target) {
      target.classList.add("active");
      target.style.display = "flex";
    }
  },

  confirmGoHome() {
    if (confirm("ホーム画面に戻りますか？未保存の変更がある場合は「保存する」を押してください。")) {
      this.pause();
      this.showScreen("screen-welcome");
    }
  },

  // ==========================================
  // 画面1: 新規作成または開く (Screen 1)
  // ==========================================
  getModeExtensions(mode) {
    const extMap = {
      keynote: [".key", ".keynote"],
      pptx: [".pptx"],
      project: [".tpmproj", ".json"],
      ymm: [".ymmp"],
      fcpxml: [".fcpxml", ".xml"],
      replace_images: [".key", ".keynote", ".jpeg", ".jpg", ".png"],
      replace_single_image: [".jpeg", ".jpg", ".png"],
      add_media: [".mp4", ".mov", ".png", ".jpg", ".jpeg", ".wav", ".mp3"]
    };
    return extMap[mode] || [];
  },

  async createBlankProject() {
    const name = prompt("新規プロジェクト名を入力してください:", "東方Project動画");
    if (!name) return;

    try {
      const res = await fetch("/api/project/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ project_name: name })
      });
      const data = await res.json();
      if (data.success && data.project) {
        this.project = data.project;
        this.openEditorScreen();
      } else {
        alert("プロジェクト作成エラー: " + (data.error || ""));
      }
    } catch (e) {
      alert("プロジェクト作成に失敗しました: " + e);
    }
  },

  openFileBrowser(mode) {
    this.filePickerMode = mode;
    const picker = document.getElementById("modal-file-picker");
    const title = document.getElementById("picker-title");
    const filterInfo = document.getElementById("picker-filter-info");

    const titles = {
      keynote: "Keynote ファイル (.key) を選択",
      pptx: "PowerPoint ファイル (.pptx) を選択",
      fcpxml: "Final Cut Pro (FCPXML) を選択",
      ymm: "ゆっくりMovieMaker ファイル (.ymmp) を選択",
      project: "編集プロジェクト (.tpmproj / .json) を選択",
      add_media: "追加するメディアファイルを選択",
      replace_images: "スライド画像のみ一括上書き (Keynoteまたは画像を選択)",
      replace_single_image: "差し替える画像ファイルを選択 (.jpeg / .png)"
    };

    const exts = this.getModeExtensions(mode);
    if (filterInfo) {
      filterInfo.innerText = exts.length > 0 ? `対象: ${exts.join(" / ")}` : "";
    }

    if (title) title.innerText = titles[mode] || "ファイルを選択";
    this.browseDirectory(this.currentDirectory);
    if (picker) picker.classList.add("active");
  },

  closeFilePicker() {
    const picker = document.getElementById("modal-file-picker");
    if (picker) picker.classList.remove("active");
  },

  openReplaceImagesDialog() {
    this.openFileBrowser("replace_images");
  },

  replaceSingleSceneImage() {
    this.openFileBrowser("replace_single_image");
  },

  showTaskProgress(title, stage, percent, detail = "") {
    const modal = document.getElementById("modal-task-progress");
    if (modal) modal.classList.add("active");
    const tEl = document.getElementById("task-progress-title");
    if (tEl) tEl.innerText = title;
    const sEl = document.getElementById("task-progress-stage");
    if (sEl) sEl.innerText = stage;
    const pBar = document.getElementById("task-progress-bar");
    if (pBar) pBar.style.width = `${Math.min(100, Math.max(0, percent))}%`;
    const pEl = document.getElementById("task-progress-percent");
    if (pEl) pEl.innerText = `進捗: ${Math.round(percent)}%`;
    const dEl = document.getElementById("task-progress-detail");
    if (dEl) dEl.innerText = detail || "";
    const fEl = document.getElementById("task-progress-footer");
    if (fEl) fEl.style.display = (percent >= 100) ? "flex" : "none";
  },

  closeTaskProgressModal() {
    const modal = document.getElementById("modal-task-progress");
    if (modal) modal.classList.remove("active");
  },

  async applyReplaceSlideImages(sourcePath) {
    if (!this.project || !this.project.scenes) return;

    this.showTaskProgress("🖼️ スライド画像上書き", "最新のスライド画像を読み込み・上書き中...", 30, "画像ファイルを解析しています...");

    try {
      const res = await fetch("/api/project/update_slide_images", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          scenes: this.project.scenes,
          source_path: sourcePath
        })
      });
      const data = await res.json();
      if (data.success && data.scenes) {
        this.project.scenes = data.scenes;
        this.renderScenesList();
        this.renderTimeline();
        this.selectScene(this.currentSceneIndex);
        this.showTaskProgress("✅ 上書き完了", `台本や音声を完全保持したまま、${data.updated_count} 枚のスライド画像を上書き更新しました！`, 100, "タイムラインを更新しました");
      } else {
        this.closeTaskProgressModal();
        alert("画像上書きエラー: " + (data.error || ""));
      }
    } catch (e) {
      this.closeTaskProgressModal();
      alert("通信エラー: " + e);
    }
  },

  async refreshMediaFromKeynote() {
    if (!this.project || !this.project.scenes) {
      alert("プロジェクトが開かれていません。");
      return;
    }

    if (!confirm("【画像・動画のスマート再同期】\nセリフ本文・音声記号列・キャラクター設定・効果音・BGM・生成済み音声をすべて完全に保持したまま、Keynoteから最新のスライド画像とアニメーション設定を同期しますか？\n（キャラクターやスライドの動きを自動判別し、アニメーションがあるスライドのみ動画として最適に反映します）")) {
      return;
    }

    this.showTaskProgress("🔄 画像・動画のスマート再同期", "Step 1/3: スライド画像およびキャラクターの走査中...", 25, "Keynoteスライドとキャラクターのアニメーション設定を確認しています...");

    let progressVal = 25;
    const progressTimer = setInterval(() => {
      if (progressVal < 90) {
        progressVal += 15;
        if (progressVal >= 50 && progressVal < 80) {
          this.showTaskProgress("🔄 画像・動画のスマート再同期", "Step 2/3: アニメーション判定 & 動画クリップ切り出し中...", progressVal, "動きのあるスライドのみ動画クリップを最適生成中...");
        } else if (progressVal >= 80) {
          this.showTaskProgress("🔄 画像・動画のスマート再同期", "Step 3/3: プロジェクトデータを最新化中...", progressVal, "タイムラインを同期中...");
        }
      }
    }, 1500);

    try {
      const res = await fetch("/api/project/refresh_media", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          project: this.project
        })
      });
      clearInterval(progressTimer);
      const data = await res.json();
      if (data.success) {
        if (data.project) {
          this.project = data.project;
        } else if (data.scenes) {
          this.project.scenes = data.scenes;
        }

        // アニメーション指示のないシーンの余白を確実に0.0に整流
        if (this.project && this.project.scenes) {
          this.project.scenes.forEach(s => {
            if (!this.hasAnimationInstruction(s.notes, s.text)) {
              s.extra_delay = 0.0;
              s.has_animation = false;
              s.video_clip_path = null;
              s.video_duration = null;
              s.animation_duration = null;
              s.target_duration = null;
            }
          });
        }

        this.renderScenesList();
        this.renderTimeline();
        this.selectScene(this.currentSceneIndex);

        const objCounts = data.obj_anim_counts || {};
        const detailMsg = `スライド画像: ${data.updated_count}枚更新 | 🎬 アニメーション動画: ${data.anim_count || 0}件同期完了！\n[全オブジェクト解析] 🌄背景: ${objCounts.background || 0} | 👤キャラ: ${objCounts.character || 0} | 🏷️枠: ${objCounts.telop_frame || 0} | 📝テキスト: ${objCounts.text || 0} | 📋ノート: ${objCounts.presenter_notes || 0}`;
        this.showTaskProgress("✅ スマート再同期完了", detailMsg, 100, "セリフ・音声・SE/BGMはすべて完全に維持されています");
      } else {
        this.closeTaskProgressModal();
        alert("再同期エラー: " + (data.error || ""));
      }
    } catch (e) {
      clearInterval(progressTimer);
      this.closeTaskProgressModal();
      alert("通信エラー: " + e);
    }
  },

  async browseDirectory(dirPath) {
    try {
      const exts = this.getModeExtensions(this.filePickerMode);
      const res = await fetch(`/api/files/browse?dir=${encodeURIComponent(dirPath)}&exts=${encodeURIComponent(exts.join(","))}`);
      const data = await res.json();
      if (data.success) {
        this.currentDirectory = data.current_dir;
        document.getElementById("picker-current-path").innerText = data.current_dir;
        
        // クイックアクセスバーの描画
        const quickContainer = document.getElementById("picker-quick-locations");
        if (quickContainer && data.quick_locations) {
          quickContainer.innerHTML = "";
          data.quick_locations.forEach(loc => {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "btn-quick-loc";
            btn.innerText = loc.name;
            btn.title = loc.path;
            btn.onclick = () => this.browseDirectory(loc.path);
            quickContainer.appendChild(btn);
          });
        }

        const list = document.getElementById("picker-items-list");
        list.innerHTML = "";

        if (data.items.length === 0) {
          list.innerHTML = '<div style="padding: 16px; color: #888; text-align: center;">このフォルダにはファイルがありません</div>';
          return;
        }

        data.items.forEach(item => {
          const row = document.createElement("div");
          const isMatched = (item.is_dir || item.is_matched !== false);
          row.className = `file-row ${item.is_dir ? 'is-directory' : (isMatched ? 'matched' : 'unmatched')}`;
          const icon = item.is_dir ? "📁" : this.getFileIcon(item.extension);
          row.innerHTML = `
            <span class="file-icon">${icon}</span>
            <span class="file-name">${item.name}</span>
            <span class="file-size">${item.is_dir ? "" : this.formatBytes(item.size)}</span>
          `;

          row.onclick = () => {
            if (item.is_dir) {
              this.browseDirectory(item.path);
            } else {
              this.onFileSelected(item.path);
            }
          };

          list.appendChild(row);
        });
      }
    } catch (e) {
      console.error("Browse failed:", e);
    }
  },

  pickerBrowseParent() {
    const parts = this.currentDirectory.split("/").filter(Boolean);
    parts.pop();
    const parent = "/" + parts.join("/");
    this.browseDirectory(parent || "/");
  },

  browseParentDir() {
    this.pickerBrowseParent();
  },

  onFileSelected(filePath) {
    this.closeFilePicker();
    const mode = this.filePickerMode;

    if (mode === "keynote") {
      this.startLoadingProcess(filePath, "keynote");
    } else if (mode === "pptx") {
      this.startLoadingProcess(filePath, "pptx");
    } else if (mode === "ymm") {
      this.startLoadingProcess(filePath, "ymm");
    } else if (mode === "fcpxml") {
      this.startLoadingProcess(filePath, "fcpxml");
    } else if (mode === "project") {
      this.loadExistingProject(filePath);
    } else if (mode === "add_media") {
      this.addMediaToProject(filePath);
    } else if (mode === "replace_images") {
      this.applyReplaceSlideImages(filePath);
    } else if (mode === "replace_single_image") {
      const scene = this.project && this.project.scenes ? this.project.scenes[this.currentSceneIndex] : null;
      if (scene) {
        scene.image_path = filePath;
        this.renderScenesList();
        this.renderTimeline();
        this.selectScene(this.currentSceneIndex);
        alert(`Scene ${scene.slide_index || (this.currentSceneIndex + 1)} のスライド画像を差し替えました！`);
      }
    }
  },

  // ==========================================
  // 画面2: データ読み込み処理 (Screen 2)
  // ==========================================
  startLoadingProcess(filePath, fileType) {
    this.showScreen("screen-loading");

    const fileName = filePath.split("/").pop();
    const fLabel = document.getElementById("loading-file-label");
    if (fLabel) fLabel.innerText = `[${fileName}] を読み込み中です...`;

    const pBar = document.getElementById("loading-progress-bar");
    const sLabel = document.getElementById("loading-size-label");
    const tLabel = document.getElementById("loading-time-label");

    if (pBar) pBar.style.width = "10%";
    if (sLabel) sLabel.innerText = `ファイル解析・スライド抽出中 (10%)...`;
    if (tLabel) tLabel.innerText = `残り時間: 約3秒、完了予定: まもなく`;

    let progress = 10;
    const progressInterval = setInterval(() => {
      if (progress < 85) {
        progress += 15;
        if (pBar) pBar.style.width = `${progress}%`;
        if (sLabel) sLabel.innerText = `台本作成処理・タイムライン復元中 (${progress}%)...`;
      }
    }, 300);

    const endpoint = fileType === "keynote" ? "/api/import/keynote" :
                     fileType === "pptx" ? "/api/import/pptx" :
                     fileType === "fcpxml" ? "/api/import/fcpxml" : "/api/import/ymm";

    fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ file_path: filePath })
    })
    .then(res => res.json())
    .then(data => {
      clearInterval(progressInterval);
      if (data.success && data.project) {
        if (pBar) pBar.style.width = "100%";
        if (sLabel) sLabel.innerText = `読み込み完了！ (全 ${data.slides_count || data.project.scenes.length} シーン抽出)`;
        if (tLabel) tLabel.innerText = `完了時間: ${new Date().toLocaleTimeString()}`;

        this.project = data.project;

        const chkNotify = document.getElementById("chk-notify");
        if (chkNotify && chkNotify.checked) {
          try {
            this.showNotification("データ読み込み完了", `${fileName} の抽出が完了しました。`);
          } catch(e) {}
        }

        setTimeout(() => {
          this.openEditorScreen();
        }, 400);
      } else {
        alert("読み込みエラー: " + (data.error || "データが正しく抽出できませんでした。"));
        this.showScreen("screen-welcome");
      }
    })
    .catch(err => {
      clearInterval(progressInterval);
      alert("読み込み通信エラー: " + err);
      this.showScreen("screen-welcome");
    });
  },

  cancelLoading() {
    if (confirm("データの読み込みを中止しますか？")) {
      this.showScreen("screen-welcome");
    }
  },

  async loadExistingProject(filePath) {
    try {
      const res = await fetch("/api/project/load", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ file_path: filePath })
      });
      const data = await res.json();
      if (data.success && data.project) {
        this.project = data.project;
        if (data.recovered) {
          alert("【自動復元】" + data.warning);
        }
        this.openEditorScreen();
      } else {
        alert("プロジェクト読み込みエラー: " + (data.error || ""));
      }
    } catch (e) {
      alert("通信エラー: " + e);
    }
  },

  // ==========================================
  // ドラッグ＆ドロップ機能
  // ==========================================
  setupDragAndDrop() {
    const overlay = document.getElementById("drag-drop-overlay");
    let dragCounter = 0;

    window.addEventListener("dragenter", (e) => {
      e.preventDefault();
      dragCounter++;
      if (overlay) overlay.style.display = "flex";
    });

    window.addEventListener("dragover", (e) => {
      e.preventDefault();
    });

    window.addEventListener("dragleave", (e) => {
      e.preventDefault();
      dragCounter--;
      if (dragCounter <= 0) {
        dragCounter = 0;
        if (overlay) overlay.style.display = "none";
      }
    });

    window.addEventListener("drop", (e) => {
      e.preventDefault();
      dragCounter = 0;
      if (overlay) overlay.style.display = "none";

      const files = e.dataTransfer ? e.dataTransfer.files : [];
      if (!files || files.length === 0) return;

      const file = files[0];
      const filePath = file.path || file.name;
      const ext = (filePath.substring(filePath.lastIndexOf(".")) || "").toLowerCase();

      if ([".key", ".keynote"].includes(ext)) {
        this.startLoadingProcess(filePath, "keynote");
      } else if ([".pptx"].includes(ext)) {
        this.startLoadingProcess(filePath, "pptx");
      } else if ([".tpmproj", ".json"].includes(ext)) {
        this.loadExistingProject(filePath);
      } else if ([".ymmp"].includes(ext)) {
        this.startLoadingProcess(filePath, "ymm");
      } else if ([".fcpxml", ".xml"].includes(ext)) {
        this.startLoadingProcess(filePath, "fcpxml");
      } else if ([".mp4", ".mov", ".png", ".jpg", ".jpeg", ".wav", ".mp3"].includes(ext)) {
        if (this.project) {
          this.addMediaToProject(filePath);
        } else {
          alert(`メディアファイル [${file.name}] を追加するには、まずプロジェクトを作成または開いてください。`);
        }
      } else {
        alert(`非対応のファイル形式です: ${ext}\n(.key, .pptx, .tpmproj, .json, .ymmp, .fcpxml に対応しています)`);
      }
    });
  },

  // ==========================================
  // 画面3: 編集画面 (Screen 3)
  // ==========================================
  openEditorScreen() {
    this.showScreen("screen-editor");
    this.renderProjectDetails();
    this.preloadAllSceneAudio();
  },

  renderProjectDetails() {
    if (!this.project) return;

    // プロジェクト名
    const pName = this.project.project_name || "名称未設定";
    document.getElementById("nav-project-name").innerText = pName;

    // シーン一覧とタイムライン
    this.renderScenesList();
    this.renderTimeline();

    // 最初のシーンを選択
    if (this.project.scenes && this.project.scenes.length > 0) {
      this.selectScene(0);
    } else {
      this.clearInspector();
    }
  },

  renderScenesList() {
    const list = document.getElementById("extracted-media-list");
    const countBadge = document.getElementById("extracted-scenes-count");
    if (!list) return;

    list.innerHTML = "";
    const scenes = this.project.scenes || [];
    if (countBadge) countBadge.innerText = scenes.length;

    // 選択件数カウンターと全選択チェックボックスの更新
    this.updateSelectionToolbar();

    scenes.forEach((s, idx) => {
      const comp = this.getSceneMediaComparison(s);
      const isNoVoice = comp.isNoVoice;
      const isChecked = this.selectedSceneIndices.has(idx);

      const animObjs = s.animated_objects || [];
      const animBadges = [];
      const buildsList = s.builds || [];

      // 1. ビルドアニメーションバッジ (イン・アクション・アウト)
      buildsList.forEach(b => {
        const bType = b.type || "In";
        const bEff = b.effect_name || b.effect || "";
        const bDur = b.duration ? `${b.duration}s` : "";
        const bDir = b.direction ? ` ${b.direction}` : "";
        if (bType === "In") {
          animBadges.push(`<span class="anim-badge build-in" title="💫 インアニメーション: ${bEff} ${bDur}${bDir} (${b.delivery || '一括'})" style="font-size: 9px; background: #1b4f72; color: #85c1e9; padding: 1px 5px; border-radius: 3px; margin-right: 2px; border: 1px solid #2874a6;">💫イン: ${bEff} ${bDur}</span>`);
        } else if (bType === "Out") {
          animBadges.push(`<span class="anim-badge build-out" title="💨 アウトアニメーション: ${bEff} ${bDur}${bDir} (${b.delivery || '一括'})" style="font-size: 9px; background: #512e5f; color: #d7bde2; padding: 1px 5px; border-radius: 3px; margin-right: 2px; border: 1px solid #76448a;">💨アウト: ${bEff} ${bDur}</span>`);
        } else {
          animBadges.push(`<span class="anim-badge build-action" title="⚡ アクションアニメーション: ${bEff} ${bDur}" style="font-size: 9px; background: #7d6608; color: #f9e79f; padding: 1px 5px; border-radius: 3px; margin-right: 2px; border: 1px solid #b7950b;">⚡アクション: ${bEff}</span>`);
        }
      });

      // 2. トランジションバッジ (自動ディレイ / エフェクト)
      const hasAutoTrans = Boolean(s.transition_automatic && parseFloat(s.transition_delay || 0.0) > 0);
      const hasTransEff = Boolean(s.transition_effect && s.transition_effect !== "no transition effect");
      if (hasAutoTrans || hasTransEff) {
        const transLabel = hasAutoTrans ? `🔄自動 ${s.transition_delay}s` : `🔄切替 ${s.transition_effect}`;
        animBadges.push(`<span class="anim-badge trans" title="🔄 トランジション: ${s.transition_effect || 'エフェクトなし'} (開始: ${s.transition_automatic ? '自動' : 'クリック時'}, 遅れ: ${s.transition_delay || 0}s)" style="font-size: 9px; background: #0e6251; color: #a3e4d7; padding: 1px 5px; border-radius: 3px; margin-right: 2px; border: 1px solid #148f77;">${transLabel}</span>`);
      }

      // 3. テンプレートバッジ
      const tmplName = s.template_name || (s.template_info ? s.template_info.layout_name : "");
      const isSecHeader = s.template_info ? s.template_info.is_section_header : (tmplName.includes("セクション") || tmplName.includes("見出し") || tmplName.includes("タイトル"));
      if (tmplName && tmplName !== "標準") {
        const icon = isSecHeader ? "📁" : "📑";
        animBadges.push(`<span class="anim-badge tmpl" title="スライドテンプレート: ${tmplName}" style="font-size: 9px; background: #2c3e50; color: #a5d8ff; padding: 1px 5px; border-radius: 3px; margin-right: 2px; border: 1px solid #34495e;">${icon} ${tmplName}</span>`);
      }

      // 4. キャラクター動作状態バッジ
      if (s.slide_objects && s.slide_objects.characters) {
        (s.slide_objects.characters || []).forEach(c => {
          if (c.has_movement) {
            animBadges.push(`<span class="anim-badge char-move" title="👤 ${c.name}: ${c.status}" style="font-size: 9px; background: #5c3b00; color: #fed7aa; padding: 1px 5px; border-radius: 3px; margin-right: 2px; border: 1px solid #9a3412;">👤 ${c.name} [💫動作 ${c.duration}s]</span>`);
          }
        });
      }

      // 5. その他要素バッジ
      if (animObjs.includes("background")) animBadges.push('<span class="anim-badge bg" title="🌄 背景アニメーション/変化あり" style="font-size: 9px; background: #2c3e50; color: #74b9ff; padding: 1px 4px; border-radius: 3px; margin-right: 2px;">🌄背景</span>');
      if (animObjs.includes("character")) animBadges.push('<span class="anim-badge char" title="👤 キャラクター立ち絵/差分あり" style="font-size: 9px; background: #2d3436; color: #ffeaa7; padding: 1px 4px; border-radius: 3px; margin-right: 2px;">👤キャラ</span>');
      if (animObjs.includes("telop_frame")) animBadges.push('<span class="anim-badge telop" title="🏷️ テロップ枠あり" style="font-size: 9px; background: #34495e; color: #55efc4; padding: 1px 4px; border-radius: 3px; margin-right: 2px;">🏷️枠</span>');
      if (animObjs.includes("presenter_notes")) animBadges.push('<span class="anim-badge notes" title="📋 発表者ノート指示あり" style="font-size: 9px; background: #4a235a; color: #fd79a8; padding: 1px 4px; border-radius: 3px; margin-right: 2px;">📋ノート</span>');

      let modeBadge = "";
      if (comp.isVideoMode) {
        modeBadge = `<span class="video-badge" style="background: #2980b9; color: #fff; font-size: 9px; padding: 1px 4px; border-radius: 3px;" title="動画尺(${comp.videoDur.toFixed(1)}s) > 音声尺(${comp.audioDur.toFixed(1)}s): スライド動画再生">🎬 動画再生 (${comp.videoDur.toFixed(1)}s)</span>`;
      } else if (comp.videoClip && comp.videoDur > 0) {
        modeBadge = `<span class="image-badge" style="background: #27ae60; color: #fff; font-size: 9px; padding: 1px 4px; border-radius: 3px;" title="音声尺(${comp.audioDur.toFixed(1)}s) >= 動画尺(${comp.videoDur.toFixed(1)}s): スライド画像表示">🖼️ 画像表示 (音声優先 ${comp.audioDur.toFixed(1)}s)</span>`;
      }

      const card = document.createElement("div");
      card.className = `media-card ${idx === this.currentSceneIndex ? "active" : ""} ${isNoVoice ? "is-no-voice" : ""} ${isChecked ? "is-selected" : ""} ${comp.isVideoMode ? "has-video" : ""}`;
      card.id = `media-card-${idx}`;
      card.innerHTML = `
        <div class="media-card-checkbox-wrapper" onclick="event.stopPropagation()" title="このシーンを選択">
          <input type="checkbox" class="media-card-checkbox" data-index="${idx}" ${isChecked ? "checked" : ""} onchange="App.onToggleSceneSelect(${idx}, this.checked)">
        </div>
        <div class="media-thumb">
          ${comp.imgPath ? `<img src="/media/${encodeURIComponent(comp.imgPath)}" alt="">` : "🖼️"}
        </div>
        <div class="media-info-title">
          #${s.slide_index || (idx + 1)} ${s.character || "操夢"} 
          ${modeBadge}
          ${isNoVoice ? '<span class="skip-badge" style="background:#6c757d;">🔇 音声不要</span>' : ''}
        </div>
        <div class="media-anim-tags" style="margin: 2px 0; display: flex; flex-wrap: wrap; gap: 2px;">
          ${animBadges.join("")}
        </div>
        <div class="media-info-sub">${(s.text || "").substring(0, 15)}...</div>
      `;

      card.onclick = () => this.selectScene(idx);
      list.appendChild(card);
    });
  },

  onToggleSceneSelect(index, isChecked) {
    if (isChecked) {
      this.selectedSceneIndices.add(index);
    } else {
      this.selectedSceneIndices.delete(index);
    }
    const card = document.getElementById(`media-card-${index}`);
    if (card) {
      if (isChecked) card.classList.add("is-selected");
      else card.classList.remove("is-selected");
    }
    this.updateSelectionToolbar();
  },

  onToggleSelectAllScenes(isChecked) {
    const scenes = this.project.scenes || [];
    if (isChecked) {
      scenes.forEach((_, idx) => this.selectedSceneIndices.add(idx));
    } else {
      this.selectedSceneIndices.clear();
    }
    this.renderScenesList();
  },

  updateSelectionToolbar() {
    const countText = document.getElementById("selected-scenes-count-text");
    const selectAllChk = document.getElementById("chk-select-all-scenes");
    const regenBtn = document.getElementById("btn-regen-selected");
    const scenes = this.project.scenes || [];
    const selCount = this.selectedSceneIndices.size;

    if (countText) {
      countText.innerText = `${selCount} / ${scenes.length} 件選択`;
    }
    if (selectAllChk) {
      selectAllChk.checked = (scenes.length > 0 && selCount === scenes.length);
      selectAllChk.indeterminate = (selCount > 0 && selCount < scenes.length);
    }
    if (regenBtn) {
      regenBtn.innerText = selCount > 0 ? `⚡ 選択音声(${selCount}件)を再生成` : "⚡ 選択音声を再生成";
    }
  },

  showTimelineTooltip(text, x, y) {
    let tip = document.getElementById("tl-drag-tooltip");
    if (!tip) {
      tip = document.createElement("div");
      tip.id = "tl-drag-tooltip";
      tip.className = "tl-drag-indicator-tooltip";
      document.body.appendChild(tip);
    }
    tip.innerText = text;
    tip.style.left = `${x}px`;
    tip.style.top = `${y}px`;
    tip.style.display = "block";
  },

  hideTimelineTooltip() {
    const tip = document.getElementById("tl-drag-tooltip");
    if (tip) tip.style.display = "none";
  },

  renderTimeline() {
    const trackVideo = document.getElementById("track-video-clips");
    const trackVoice = document.getElementById("track-voice-clips");
    const trackSe = document.getElementById("track-se-clips");
    const trackBgm = document.getElementById("track-bgm-clips");

    if (!trackVideo || !trackVoice) return;

    trackVideo.innerHTML = "";
    trackVoice.innerHTML = "";
    if (trackSe) {
      trackSe.innerHTML = "";
      trackSe.style.position = "relative";
    }
    if (trackBgm) {
      trackBgm.innerHTML = "";
      trackBgm.style.position = "relative";
    }

    const scenes = this.project.scenes || [];
    let calcTotalTime = 0.0;
    const sceneOffsets = []; // 各シーンの開始X位置と幅

    const pps = 90 * this.timelineZoom; // 1秒あたりのピクセル幅 (基準 90px で実尺をしっかり視認・引き伸ばし)
    const gapPx = 4; // flex gap
    const paddingLeftPx = 4; // track-body padding-left
    let currentLeftPx = paddingLeftPx;

    scenes.forEach((s, idx) => {
      const comp = this.getSceneMediaComparison(s);
      const isNoVoice = comp.isNoVoice;
      const audioDur = comp.audioDur;
      const totalSceneDur = comp.sceneDuration;
      const padDur = isNoVoice ? totalSceneDur : Math.max(0.0, totalSceneDur - audioDur);

      calcTotalTime += totalSceneDur;
      const widthPx = Math.max(60, totalSceneDur * pps);

      sceneOffsets.push({
        index: idx,
        slide_index: s.slide_index || (idx + 1),
        leftPx: currentLeftPx,
        widthPx: widthPx,
        duration: totalSceneDur,
        audioDur: audioDur,
        padDur: padDur
      });
      currentLeftPx += (widthPx + gapPx);

      // スライド/映像クリップ (実尺比例で表示)
      const vClip = document.createElement("div");
      vClip.className = `tl-clip video-clip ${idx === this.currentSceneIndex ? "selected" : ""} ${comp.isVideoMode ? "has-video" : ""}`;
      vClip.style.width = `${widthPx}px`;
      vClip.innerHTML = `
        <span class="tl-clip-title" style="font-weight: 700;">${comp.isVideoMode ? '🎬' : '🖼️'} Slide ${s.slide_index || (idx + 1)}</span>
        <span class="tl-clip-dur">${totalSceneDur.toFixed(2)}s</span>
      `;

      // スライドクリップの右端リサイズハンドル (直接ドラッグして長さを伸縮)
      const vHandle = document.createElement("div");
      vHandle.className = "tl-clip-resize-handle";
      vHandle.title = "ドラッグしてスライドの長さを直接伸縮";

      let isResizing = false;
      vHandle.onmousedown = (e) => {
        e.stopPropagation();
        e.preventDefault();
        isResizing = true;
        vHandle.classList.add("active");

        const startX = e.clientX;
        const startWidth = widthPx;
        const origDur = totalSceneDur;
        let currentDur = origDur;

        const onMouseMove = (ev) => {
          if (!isResizing) return;
          const deltaX = ev.clientX - startX;
          const newWidth = Math.max(40, startWidth + deltaX);
          currentDur = Math.max(0.3, Math.round((newWidth / pps) * 10) / 10);

          vClip.style.width = `${newWidth}px`;
          const durSpan = vClip.querySelector(".tl-clip-dur");
          if (durSpan) durSpan.innerText = `${currentDur.toFixed(2)}s`;

          const deltaDur = currentDur - origDur;
          const sign = deltaDur >= 0 ? "+" : "";
          this.showTimelineTooltip(`⏱️ Slide ${s.slide_index || (idx + 1)} 長さ: ${currentDur.toFixed(2)}s (${sign}${deltaDur.toFixed(2)}s)`, ev.clientX, ev.clientY);
        };

        const onMouseUp = (ev) => {
          if (!isResizing) return;
          isResizing = false;
          vHandle.classList.remove("active");
          this.hideTimelineTooltip();
          window.removeEventListener("mousemove", onMouseMove);
          window.removeEventListener("mouseup", onMouseUp);

          if (Math.abs(currentDur - origDur) > 0.04) {
            this.pushUndoState();
            if (isNoVoice) {
              s.extra_delay = Math.max(0.5, currentDur);
            } else {
              s.extra_delay = Math.max(0.0, currentDur - audioDur);
            }
            if (comp.isVideoMode) {
              s.video_duration = currentDur;
              s.target_duration = currentDur;
              s.animation_duration = currentDur;
            }

            const delayInp = document.getElementById("insp-extra-delay");
            if (delayInp && idx === this.currentSceneIndex) {
              delayInp.value = s.extra_delay !== undefined ? s.extra_delay : 0.0;
            }

            this.renderScenesList();
            this.renderTimeline();
            this.selectScene(idx, false);
          } else {
            vClip.style.width = `${widthPx}px`;
            const durSpan = vClip.querySelector(".tl-clip-dur");
            if (durSpan) durSpan.innerText = `${totalSceneDur.toFixed(2)}s`;
          }
        };

        window.addEventListener("mousemove", onMouseMove);
        window.addEventListener("mouseup", onMouseUp);
      };

      vClip.appendChild(vHandle);

      vClip.onclick = (e) => {
        if (isResizing) return;
        const clickX = e.offsetX !== undefined ? e.offsetX : 0;
        const ratio = widthPx > 0 ? Math.max(0, Math.min(1.0, clickX / widthPx)) : 0.0;
        const offsetSec = totalSceneDur * ratio;
        this.selectScene(idx, true, offsetSec);
      };
      trackVideo.appendChild(vClip);

      // ボイスクリップ (音声実尺と余白を分割・可視化)
      const aClip = document.createElement("div");
      aClip.className = `tl-clip voice-clip ${idx === this.currentSceneIndex ? "selected" : ""} ${isNoVoice ? "is-no-voice" : ""}`;
      aClip.style.width = `${widthPx}px`;

      if (isNoVoice) {
        aClip.style.opacity = "0.5";
        aClip.style.background = "#333";
        aClip.innerHTML = `
          <div class="voice-pad-part" style="width: 100%;">
            <span>🔇 音声不要 (${padDur.toFixed(1)}s)</span>
          </div>
        `;
      } else {
        const audioWidthPx = Math.min(widthPx - 15, Math.max(20, audioDur * pps));
        aClip.innerHTML = `
          <div class="voice-audio-part" style="width: ${audioWidthPx}px;" title="音声実測: ${audioDur.toFixed(2)}秒">
            <span class="tl-clip-title" style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 10px; font-weight: 700;">🗣️ ${s.character || "操夢"}: ${s.text || ""}</span>
            <span class="tl-clip-dur" style="font-size: 9px; color: #a5d8ff;">🎵 ${audioDur.toFixed(2)}s</span>
          </div>
          <div class="voice-pad-part" title="待機余白: ${padDur.toFixed(2)}秒">
            <span>+${padDur.toFixed(1)}s</span>
          </div>
        `;
      }
      aClip.onclick = (e) => {
        const clickX = e.offsetX !== undefined ? e.offsetX : 0;
        const ratio = widthPx > 0 ? Math.max(0, Math.min(1.0, clickX / widthPx)) : 0.0;
        const offsetSec = totalSceneDur * ratio;
        this.selectScene(idx, true, offsetSec);
      };
      trackVoice.appendChild(aClip);
    });

    // ==========================================
    // タイムライン上の複数シーン連続効果音 (SE) トラックの完全同期描画
    // ==========================================
    if (trackSe && this.project.timeline && this.project.timeline.sound_effects) {
      const vClips = trackVideo.children;
      const seClipsData = [];

      // インデックス解決ヘルパー
      const resolveSceneIndex = (num) => {
        if (num === undefined || num === null) return 0;
        const targetNum = parseInt(num);
        // 1. slide_index と完全一致 (例: スライド80)
        let idx = scenes.findIndex(s => parseInt(s.slide_index) === targetNum);
        if (idx !== -1) return idx;
        // 2. 1-indexed 通し番号 (例: 1番目のシーン = index 0)
        if (targetNum >= 1 && targetNum <= scenes.length) {
          return targetNum - 1;
        }
        // 3. 0-indexed インデックス
        if (targetNum >= 0 && targetNum < scenes.length) {
          return targetNum;
        }
        return Math.max(0, Math.min(scenes.length - 1, targetNum - 1));
      };

      this.project.timeline.sound_effects.forEach(se => {
        const stIdx = resolveSceneIndex(se.start_scene_index);
        const endIdx = resolveSceneIndex(se.end_scene_index || se.start_scene_index);

        const realStIdx = Math.min(stIdx, endIdx);
        const realEndIdx = Math.max(stIdx, endIdx);

        // 映像/スライド画像クリップの物理DOM要素から正確な座標を取得
        const stEl = vClips[realStIdx];
        const endEl = vClips[realEndIdx];

        let leftPx = 0;
        let widthPx = 40;

        if (stEl && endEl) {
          leftPx = stEl.offsetLeft;
          widthPx = Math.max(30, (endEl.offsetLeft + endEl.offsetWidth) - stEl.offsetLeft);
        } else if (sceneOffsets[realStIdx] && sceneOffsets[realEndIdx]) {
          const stOff = sceneOffsets[realStIdx];
          const endOff = sceneOffsets[realEndIdx];
          leftPx = stOff.leftPx;
          widthPx = Math.max(30, (endOff.leftPx + endOff.widthPx) - leftPx);
        }

        seClipsData.push({
          se: se,
          realStIdx: realStIdx,
          realEndIdx: realEndIdx,
          stSlide: (scenes[realStIdx] ? (scenes[realStIdx].slide_index || (realStIdx + 1)) : se.start_scene_index),
          endSlide: (scenes[realEndIdx] ? (scenes[realEndIdx].slide_index || (realEndIdx + 1)) : se.end_scene_index),
          leftPx: leftPx,
          rightPx: leftPx + widthPx,
          widthPx: widthPx
        });
      });

      // マルチレーン（上下段分け）割り当て
      const laneEndPositions = [];
      let maxLane = 0;
      seClipsData.forEach(item => {
        let assignedLane = -1;
        for (let l = 0; l < laneEndPositions.length; l++) {
          if (item.leftPx >= laneEndPositions[l] + 2) {
            assignedLane = l;
            laneEndPositions[l] = item.rightPx;
            break;
          }
        }
        if (assignedLane === -1) {
          assignedLane = laneEndPositions.length;
          laneEndPositions.push(item.rightPx);
        }
        item.lane = assignedLane;
        if (assignedLane > maxLane) maxLane = assignedLane;
      });

      trackSe.style.minHeight = `${Math.max(34, (maxLane + 1) * 30 + 8)}px`;

      seClipsData.forEach(item => {
        const se = item.se;
        const realStIdx = item.realStIdx;
        const realEndIdx = item.realEndIdx;

        const seClip = document.createElement("div");
        seClip.className = "tl-clip se-clip";
        seClip.style.position = "absolute";
        seClip.style.left = `${item.leftPx}px`;
        seClip.style.top = `${item.lane * 30 + 4}px`;
        seClip.style.width = `${item.widthPx}px`;
        seClip.style.height = "26px";
        seClip.style.boxSizing = "border-box";
        seClip.title = `🔔 効果音: ${se.name || "SE"} (Slide ${item.stSlide}〜${item.endSlide}) - ドラッグで伸縮・移動 / クリックで設定`;

        const isRevBadge = se.reverse ? '<span style="background: #e74c3c; color: #fff; padding: 1px 4px; border-radius: 3px; font-size: 9px; margin-left: 4px;">🔄 逆</span>' : '';
        const loopBadge = se.loop ? '<span style="background: #3498db; color: #fff; padding: 1px 4px; border-radius: 3px; font-size: 9px; margin-left: 4px;">🔁 ループ</span>' : '';

        seClip.innerHTML = `
          <span class="tl-clip-title" style="font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 10px;">🔔 ${se.name || "連続SE"} (Slide ${item.stSlide}〜${item.endSlide})${isRevBadge}${loopBadge}</span>
          <span class="tl-clip-dur" style="font-size: 9px;">${Math.round((se.volume !== undefined ? se.volume : 1.0) * 100)}% | ${(se.speed || 1.0).toFixed(1)}x</span>
        `;

        // 左端リサイズハンドル (開始スライド伸縮)
        const lHandle = document.createElement("div");
        lHandle.className = "se-resize-handle se-resize-handle-left";
        lHandle.title = "ドラッグして開始スライドを変更";
        seClip.appendChild(lHandle);

        // 右端リサイズハンドル (終了スライド伸縮)
        const rHandle = document.createElement("div");
        rHandle.className = "se-resize-handle se-resize-handle-right";
        rHandle.title = "ドラッグして終了スライドを変更";
        seClip.appendChild(rHandle);

        // SEクリップのドラッグ＆リサイズ
        seClip.onmousedown = (e) => {
          e.stopPropagation();
          const isLeftHandle = e.target.classList.contains("se-resize-handle-left");
          const isRightHandle = e.target.classList.contains("se-resize-handle-right");
          const isBodyMove = !isLeftHandle && !isRightHandle;

          const origStIdx = realStIdx;
          const origEndIdx = realEndIdx;
          let curStIdx = origStIdx;
          let curEndIdx = origEndIdx;

          const startX = e.clientX;
          let hasMoved = false;

          const getSceneIdxAtX = (clientX) => {
            const timeInfo = this.getTimeInfoFromTimelineX(clientX);
            return timeInfo ? timeInfo.sceneIndex : 0;
          };

          const initialGrabIdx = getSceneIdxAtX(startX);
          seClip.classList.add("is-dragging");

          const onMouseMove = (ev) => {
            const dx = Math.abs(ev.clientX - startX);
            if (dx > 4) hasMoved = true;
            if (!hasMoved) return;

            const hoverIdx = getSceneIdxAtX(ev.clientX);

            if (isLeftHandle) {
              curStIdx = Math.max(0, Math.min(curEndIdx, hoverIdx));
            } else if (isRightHandle) {
              curEndIdx = Math.min(scenes.length - 1, Math.max(curStIdx, hoverIdx));
            } else if (isBodyMove) {
              const deltaIdx = hoverIdx - initialGrabIdx;
              const spanLen = origEndIdx - origStIdx;
              curStIdx = Math.max(0, Math.min(scenes.length - 1 - spanLen, origStIdx + deltaIdx));
              curEndIdx = curStIdx + spanLen;
            }

            // プレビュー位置更新
            const stEl = vClips[curStIdx];
            const endEl = vClips[curEndIdx];
            if (stEl && endEl) {
              seClip.style.left = `${stEl.offsetLeft}px`;
              seClip.style.width = `${Math.max(30, (endEl.offsetLeft + endEl.offsetWidth) - stEl.offsetLeft)}px`;
            }

            const stSlideNum = scenes[curStIdx] ? (scenes[curStIdx].slide_index || curStIdx + 1) : curStIdx + 1;
            const endSlideNum = scenes[curEndIdx] ? (scenes[curEndIdx].slide_index || curEndIdx + 1) : curEndIdx + 1;
            this.showTimelineTooltip(`🔔 ${se.name || '効果音'}: Slide ${stSlideNum} 〜 Slide ${endSlideNum}`, ev.clientX, ev.clientY);
          };

          const onMouseUp = (ev) => {
            seClip.classList.remove("is-dragging");
            this.hideTimelineTooltip();
            window.removeEventListener("mousemove", onMouseMove);
            window.removeEventListener("mouseup", onMouseUp);

            if (hasMoved) {
              if (curStIdx !== origStIdx || curEndIdx !== origEndIdx) {
                this.pushUndoState();
                se.start_scene_index = scenes[curStIdx] ? (scenes[curStIdx].slide_index || curStIdx + 1) : curStIdx + 1;
                se.end_scene_index = scenes[curEndIdx] ? (scenes[curEndIdx].slide_index || curEndIdx + 1) : curEndIdx + 1;
                this.renderTimeline();
              }
            } else {
              // 移動しなかったクリックの場合は設定モーダルを開く
              this.openEditSpanSeModal(se.id);
            }
          };

          window.addEventListener("mousemove", onMouseMove);
          window.addEventListener("mouseup", onMouseUp);
        };

        trackSe.appendChild(seClip);
      });
    }

    // タイムライン上の BGM トラックの描画
    if (trackBgm) {
      if (this.project.timeline && this.project.timeline.bgm && this.project.timeline.bgm.audio_path) {
        const bgm = this.project.timeline.bgm;
        const bgmClip = document.createElement("div");
        bgmClip.className = "tl-clip bgm-clip";
        bgmClip.style.left = `${paddingLeftPx}px`;
        bgmClip.style.width = `${Math.max(100, (currentLeftPx - gapPx) - paddingLeftPx)}px`;
        bgmClip.title = `🎵 BGM: ${bgm.name || bgm.audio_path.split("/").pop()} - クリックで設定`;

        bgmClip.innerHTML = `
          <span class="tl-clip-title" style="font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">🎵 BGM: ${bgm.name || bgm.audio_path.split("/").pop()}</span>
          <span class="tl-clip-dur">音量 ${Math.round((bgm.volume || 0.25) * 100)}% (全体)</span>
        `;
        bgmClip.onclick = () => this.openBgmModal();
        trackBgm.appendChild(bgmClip);
      } else {
        const emptyBgm = document.createElement("div");
        emptyBgm.style.padding = "8px 12px";
        emptyBgm.style.color = "#888";
        emptyBgm.style.fontSize = "11px";
        emptyBgm.style.cursor = "pointer";
        emptyBgm.innerHTML = "➕ ここをクリックしてタイムラインにBGMを設定";
        emptyBgm.onclick = () => this.openBgmModal();
        trackBgm.appendChild(emptyBgm);
      }
    }

    this.sceneOffsetsCache = sceneOffsets;
    this.totalDuration = calcTotalTime;

    // ルーラー目盛りの描画
    const ruler = document.getElementById("timeline-ruler");
    if (ruler) {
      ruler.innerHTML = "";
      ruler.style.position = "relative";
      ruler.style.minWidth = `${currentLeftPx + 120}px`;

      let accRulerTime = 0.0;
      sceneOffsets.forEach((off) => {
        const mark = document.createElement("div");
        mark.className = "tl-ruler-mark";
        mark.style.position = "absolute";
        mark.style.left = `${120 + off.leftPx}px`;
        mark.style.top = "0";
        mark.style.bottom = "0";
        mark.style.display = "flex";
        mark.style.alignItems = "center";
        mark.style.gap = "3px";
        mark.style.pointerEvents = "none";
        mark.style.userSelect = "none";
        mark.innerHTML = `<span style="border-left: 1px solid #555; height: 100%; display: inline-block;"></span><span style="color: #888; font-size: 9px; white-space: nowrap;">S${off.slide_index} (${this.formatTime(accRulerTime)})</span>`;
        ruler.appendChild(mark);
        accRulerTime += off.duration;
      });
    }

    document.getElementById("timeline-summary-text").innerText = 
      `全 ${scenes.length} シーン | 総再生時間: ${this.formatTime(this.totalDuration)}`;
    this.renderMarkerRange();
    this.updatePlayheadDisplay();
  },

  selectScene(index, syncPlayhead = true, offsetSec = 0.0, deferPreviewUpdate = false) {
    const scenes = this.project.scenes || [];
    if (index < 0 || index >= scenes.length) return;

    const isCurrentlyPlaying = this.isPlaying;

    if (!isCurrentlyPlaying) {
      this.stopAllAudioAndTimers(false);
    } else {
      this.stopAllAudioAndTimers(true);
    }

    this.currentSceneIndex = index;
    const scene = scenes[index];

    // 同期指定がある場合、タイムライン上の赤線位置をこのシーンの開始位置+オフセットに合わせる
    if (syncPlayhead && !deferPreviewUpdate) {
      this.playheadTime = this.getSceneStartTime(index) + Math.max(0.0, offsetSec || 0.0);
      this.updatePlayheadDisplay(true);
    }

    // インスペクタフォーム更新
    document.getElementById("inspector-empty").style.display = "none";
    document.getElementById("inspector-form").style.display = "flex";

    const isNoVoice = (scene.no_voice === true || scene.is_skipped === true || scene.is_enabled === false);
    document.getElementById("insp-scene-idx").innerText = `Scene ${scene.slide_index || (index + 1)}`;
    
    // テンプレートバッジの更新
    const tmplBadge = document.getElementById("insp-template-badge");
    if (tmplBadge) {
      const tName = scene.template_name || (scene.template_info ? scene.template_info.layout_name : "標準");
      const isSec = scene.template_info ? scene.template_info.is_section_header : (tName.includes("セクション") || tName.includes("見出し") || tName.includes("タイトル"));
      tmplBadge.innerText = `📋 テンプレート: ${tName}${isSec ? ' (見出し)' : ''}`;
      tmplBadge.style.display = "inline-block";
    }

    document.getElementById("insp-skip-checkbox").checked = isNoVoice;
    document.getElementById("insp-character-select").value = scene.character || "操夢";
    document.getElementById("insp-text").value = scene.text || "";
    document.getElementById("insp-phonemes").value = scene.phonemes || "";
    document.getElementById("insp-voice-type").value = scene.voice || "f1";

    const spd = scene.speed || 100;
    document.getElementById("insp-speed").value = spd;
    document.getElementById("insp-speed-val").innerText = `${spd}%`;

    const ptc = scene.pitch || 100;
    document.getElementById("insp-pitch").value = ptc;
    document.getElementById("insp-pitch-val").innerText = `${ptc}%`;

    document.getElementById("insp-duration-val").innerText = isNoVoice ? "0.00 秒 (音声不要)" : `${(scene.audio_duration || 0).toFixed(2)} 秒`;
    document.getElementById("insp-extra-delay").value = scene.extra_delay !== undefined ? scene.extra_delay : 0.0;

    // 効果 (エフェクト) と 音質改善
    const effectSel = document.getElementById("insp-effect-select");
    if (effectSel) effectSel.value = scene.effect || "none";

    const qualitySel = document.getElementById("insp-quality-select");
    if (qualitySel) qualitySel.value = scene.quality_enhance === false ? "0" : "1";

    // 複数効果音スタックリストの描画
    this.renderInspectorSeList(scene);

    // 全オブジェクト アニメーション検出詳細の描画 (Keynoteインスペクターと完全連動)
    const animDetailBox = document.getElementById("insp-anim-details");
    if (animDetailBox) {
      const animObjs = scene.animated_objects || [];
      const animDetails = scene.animation_details || {};
      const buildsList = scene.builds || [];
      const hasAutoTrans = Boolean(scene.transition_automatic && parseFloat(scene.transition_delay || 0.0) > 0);
      const hasTransEff = Boolean(scene.transition_effect && scene.transition_effect !== "no transition effect");
      const isAnimInstructed = this.hasAnimationInstruction(scene.notes, scene.text, buildsList, hasAutoTrans);
      const hasAnim = Boolean(scene.has_animation || isAnimInstructed || buildsList.length > 0 || hasAutoTrans || hasTransEff);
      const hasVid = Boolean(scene.video_clip_path || scene.animation_path);

      if (hasAnim) {
        let detailsHtml = '<div style="font-size: 11px; font-weight: 700; color: #a5d8ff; margin-bottom: 6px; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #333; padding-bottom: 4px;">';
        detailsHtml += `<span>🎬 Keynote アニメーション確認</span>`;
        detailsHtml += `<span style="font-size: 9px; background: ${hasVid ? '#2980b9' : '#16a085'}; color: #fff; padding: 1px 5px; border-radius: 3px;">${hasVid ? '動画クリップ同期済' : '検出済'}</span>`;
        detailsHtml += '</div>';

        detailsHtml += '<div style="font-size: 10px; color: #ddd; line-height: 1.6; display: flex; flex-direction: column; gap: 4px;">';

        // 1. ビルドアニメーション (イン・アクション・アウト)
        if (buildsList && buildsList.length > 0) {
          buildsList.forEach((b, bIdx) => {
            const bType = b.type || "In";
            const bTypeJa = b.type_ja || (bType === "In" ? "イン" : (bType === "Out" ? "アウト" : "アクション"));
            const bEff = b.effect_name || b.effect || "";
            const bDur = b.duration ? `${b.duration}秒` : "1.0秒";
            const bDir = b.direction ? ` (${b.direction})` : "";
            const bDeliv = b.delivery || "一括";

            const tagBg = (bType === "In") ? "#1b4f72" : ((bType === "Out") ? "#512e5f" : "#7d6608");
            const tagBorder = (bType === "In") ? "#2874a6" : ((bType === "Out") ? "#76448a" : "#b7950b");
            const tagColor = (bType === "In") ? "#85c1e9" : ((bType === "Out") ? "#d7bde2" : "#f9e79f");
            const icon = (bType === "In") ? "💫" : ((bType === "Out") ? "💨" : "⚡");

            detailsHtml += `
              <div style="background: rgba(255,255,255,0.04); border-left: 3px solid ${tagBorder}; padding: 4px 6px; border-radius: 0 4px 4px 0;">
                <div style="display: flex; align-items: center; gap: 4px; margin-bottom: 2px;">
                  <span style="background: ${tagBg}; color: ${tagColor}; font-weight: 700; font-size: 9px; padding: 1px 4px; border-radius: 2px;">${icon} ${bTypeJa}</span>
                  <span style="color: #fff; font-weight: 700;">${bEff}</span>
                </div>
                <div style="color: #aaa; font-size: 9.5px; padding-left: 2px;">
                  継続時間: <span style="color: #64ffda;">${bDur}</span>${bDir ? ` | 方向: <span style="color: #ffeaa7;">${bDir}</span>` : ''} | 順番: 1 | 表示方式: <span>${bDeliv}</span>
                </div>
              </div>
            `;
          });
        }

        // 2. トランジション設定
        if (hasAutoTrans || hasTransEff || (scene.transition_delay && parseFloat(scene.transition_delay) > 0)) {
          const tEff = scene.transition_effect || "エフェクトなし";
          const tAuto = scene.transition_automatic ? "自動" : "クリック時";
          const tDelay = scene.transition_delay ? `${parseFloat(scene.transition_delay).toFixed(2)}秒` : "0.00秒";
          const tDur = scene.transition_duration ? `${parseFloat(scene.transition_duration).toFixed(2)}秒` : "0.00秒";

          detailsHtml += `
            <div style="background: rgba(255,255,255,0.04); border-left: 3px solid #148f77; padding: 4px 6px; border-radius: 0 4px 4px 0;">
              <div style="display: flex; align-items: center; gap: 4px; margin-bottom: 2px;">
                <span style="background: #0e6251; color: #a3e4d7; font-weight: 700; font-size: 9px; padding: 1px 4px; border-radius: 2px;">🔄 トランジション</span>
                <span style="color: #fff; font-weight: 700;">${tEff}</span>
              </div>
              <div style="color: #aaa; font-size: 9.5px; padding-left: 2px;">
                開始: <span style="color: ${scene.transition_automatic ? '#64ffda' : '#ccc'}; font-weight: 700;">${tAuto}</span> | 遅れ: <span style="color: #ffeaa7;">${tDelay}</span> | 時間: <span>${tDur}</span>
              </div>
            </div>
          `;
        }

        // 3. 発表者ノート指示
        const noteItems = animDetails.presenter_notes || [];
        if (noteItems.length > 0) {
          detailsHtml += `
            <div style="background: rgba(255,255,255,0.04); border-left: 3px solid #7d3c98; padding: 4px 6px; border-radius: 0 4px 4px 0;">
              <div style="display: flex; align-items: center; gap: 4px; margin-bottom: 2px;">
                <span style="background: #4a235a; color: #fd79a8; font-weight: 700; font-size: 9px; padding: 1px 4px; border-radius: 2px;">📋 ノート指示</span>
              </div>
              <div style="color: #ddd; font-size: 9.5px; padding-left: 2px;">
                ${noteItems.join(" / ")}
              </div>
            </div>
          `;
        } else if (scene.notes && isAnimInstructed) {
          detailsHtml += `
            <div style="background: rgba(255,255,255,0.04); border-left: 3px solid #7d3c98; padding: 4px 6px; border-radius: 0 4px 4px 0;">
              <div style="display: flex; align-items: center; gap: 4px; margin-bottom: 2px;">
                <span style="background: #4a235a; color: #fd79a8; font-weight: 700; font-size: 9px; padding: 1px 4px; border-radius: 2px;">📋 ノート指示</span>
              </div>
              <div style="color: #ddd; font-size: 9.5px; padding-left: 2px;">
                ${scene.notes}
              </div>
            </div>
          `;
        }

        detailsHtml += '</div>';

        animDetailBox.innerHTML = detailsHtml;
        animDetailBox.style.display = "block";
      } else {
        animDetailBox.style.display = "none";
      }
    }

    // スライド走査オブジェクト & キャラクターステータス パネルの描画
    const objPanel = document.getElementById("insp-scanned-objects-panel");
    const objBody = document.getElementById("insp-scanned-objects-body");
    const objPriorityTag = document.getElementById("insp-obj-priority-tag");

    if (objPanel && objBody) {
      const slideObjs = scene.slide_objects || {};
      const prioInfo = scene.duration_priority_info || {};
      const chars = slideObjs.characters || [];
      const telop = slideObjs.telop || {};
      const texts = slideObjs.texts || [];
      const shapes = slideObjs.shapes || [];
      const tmpl = slideObjs.template || { layout_name: scene.template_name || "標準" };

      if (chars.length > 0 || telop.detected || texts.length > 0 || shapes.length > 0 || (tmpl.layout_name && tmpl.layout_name !== "標準") || prioInfo.reason) {
        objPanel.style.display = "block";
        let html = "";

        // 1. テンプレート情報
        const tmplLabel = tmpl.layout_name || scene.template_name || "標準";
        html += `
          <div style="background: rgba(255,255,255,0.03); border-left: 3px solid #38bdf8; padding: 4px 6px; border-radius: 0 4px 4px 0;">
            <div style="font-weight: 700; color: #bae6fd; font-size: 10px; margin-bottom: 2px;">📑 テンプレート情報</div>
            <div style="font-size: 9.5px; color: #e0f2fe;">レイアウト: <b>${tmplLabel}</b> ${tmpl.is_section_header ? '<span style="background: #0369a1; color: #fff; padding: 0 4px; border-radius: 2px; font-size: 8.5px;">セクション見出し</span>' : ''}</div>
          </div>
        `;

        // 2. キャラクター情報 & アニメーション動作状態
        if (chars.length > 0) {
          html += `
            <div style="background: rgba(255,255,255,0.03); border-left: 3px solid #fb923c; padding: 4px 6px; border-radius: 0 4px 4px 0;">
              <div style="font-weight: 700; color: #fed7aa; font-size: 10px; margin-bottom: 2px;">👤 スライド上のキャラクター (${chars.length}名)</div>
          `;
          chars.forEach(c => {
            const moveTag = c.has_movement ? `<span style="background: #9a3412; color: #ffedd5; padding: 0 4px; border-radius: 2px; font-size: 8.5px;">💫 動作あり (${c.duration}秒)</span>` : '<span style="background: #374151; color: #9ca3af; padding: 0 4px; border-radius: 2px; font-size: 8.5px;">静止画</span>';
            html += `
              <div style="font-size: 9.5px; color: #fef08a; display: flex; align-items: center; justify-content: space-between; margin-top: 2px;">
                <span><b>${c.name}</b> (${c.image_name || '立ち絵'})</span>
                ${moveTag}
              </div>
              <div style="font-size: 9px; color: #d1d5db; padding-left: 6px;">状態: ${c.status}</div>
            `;
          });
          html += `</div>`;
        }

        // 3. テロップ & テキスト
        if (telop.detected || texts.length > 0) {
          html += `
            <div style="background: rgba(255,255,255,0.03); border-left: 3px solid #4ade80; padding: 4px 6px; border-radius: 0 4px 4px 0;">
              <div style="font-weight: 700; color: #bbf7d0; font-size: 10px; margin-bottom: 2px;">🏷️ テロップ & テキスト</div>
              ${telop.detected ? `<div style="font-size: 9.5px; color: #dcfce7;">テロップ枠: 検出済 ${(telop.animations && telop.animations.length > 0) ? `[${telop.animations.map(a => a.effect_name || a.effect).join(", ")}]` : ''}</div>` : ''}
              ${texts.map(t => `<div style="font-size: 9.5px; color: #f0fdf4;">📝 ${t.text ? t.text.substring(0, 30) : ''}</div>`).join('')}
            </div>
          `;
        }

        // 4. 図形
        if (shapes.length > 0) {
          html += `
            <div style="background: rgba(255,255,255,0.03); border-left: 3px solid #a78bfa; padding: 4px 6px; border-radius: 0 4px 4px 0;">
              <div style="font-weight: 700; color: #ddd6fe; font-size: 10px; margin-bottom: 2px;">🔷 図形オブジェクト (${shapes.length}個)</div>
              ${shapes.map(s => `<div style="font-size: 9.5px; color: #ede9fe;">🔹 ${s.name || '図形'}</div>`).join('')}
            </div>
          `;
        }

        // 5. 尺判定・時間優先適用理由
        if (prioInfo.reason) {
          if (objPriorityTag) {
            objPriorityTag.innerText = prioInfo.applied_mode === 'sync' ? '連動同期' : (prioInfo.applied_mode === 'longer_priority' ? '最長優先' : '自動適用');
          }
          html += `
            <div style="background: #0f172a; border-left: 3px solid #f59e0b; padding: 5px 7px; border-radius: 0 4px 4px 0; margin-top: 2px;">
              <div style="font-weight: 700; color: #fde68a; font-size: 10px;">⏱️ 表示時間・待機時間の決定ルール</div>
              <div style="font-size: 9.5px; color: #fff; line-height: 1.4; margin-top: 2px;">${prioInfo.reason}</div>
            </div>
          `;
        }

        objBody.innerHTML = html;
      } else {
        objPanel.style.display = "none";
      }
    }

    const tmplSelect = document.getElementById("insp-template-select");
    if (tmplSelect) tmplSelect.value = "";

    if (!deferPreviewUpdate) {
      // プレビュー画面の更新 (オフセット秒数つき)
      this.updatePreviewForScene(scene, offsetSec);
      // タイムラインとメディアグリッドのアクティブハイライト更新 (軽量クラス切り替え)
      this.updateActiveSceneHighlight();
    }

    if (isCurrentlyPlaying) {
      this.play(deferPreviewUpdate);
    }
  },

  // ==========================================
  // インスペクタ: 複数効果音 (SE) スタック管理
  // ==========================================
  getSceneSeList(scene) {
    if (!scene) return [];
    if (!scene.sound_effects || !Array.isArray(scene.sound_effects)) {
      if (scene.sound_effect) {
        scene.sound_effects = [{
          id: "se_item_1",
          sound_effect: scene.sound_effect,
          se_offset: scene.se_offset || 0.0,
          volume: scene.se_volume !== undefined ? scene.se_volume : 1.0,
          speed: scene.se_speed !== undefined ? scene.se_speed : 1.0,
          se_reverse: scene.se_reverse === true
        }];
      } else {
        scene.sound_effects = [];
      }
    }
    return scene.sound_effects;
  },

  renderInspectorSeList(scene) {
    const container = document.getElementById("insp-se-list-container");
    if (!container) return;
    container.innerHTML = "";

    const list = this.getSceneSeList(scene);
    if (list.length === 0) {
      container.innerHTML = `
        <div style="font-size: 11px; color: #888; background: #252830; padding: 8px 10px; border-radius: 6px; text-align: center; border: 1px dashed #444;">
          効果音は設定されていません。「➕ 効果音を追加」で重ねがけ可能です
        </div>
      `;
      return;
    }

    list.forEach((item, idx) => {
      const card = document.createElement("div");
      card.style.cssText = "background: #252830; border: 1px solid #3d4251; border-radius: 6px; padding: 8px; font-size: 12px;";

      // SE選択肢オプションの構築
      let seOptions = '<option value="">(効果音を選択)</option>';
      if (this.soundEffectsList && this.soundEffectsList.length > 0) {
        this.soundEffectsList.forEach(se => {
          const isSel = (se.path === item.sound_effect || (item.sound_effect && se.name === item.sound_effect));
          seOptions += `<option value="${se.path}" ${isSel ? "selected" : ""}>${se.name}</option>`;
        });
      }

      card.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
          <span style="font-weight: 700; color: #a5d8ff; font-size: 11px;">🔔 効果音 ${idx + 1}</span>
          <div style="display: flex; gap: 4px;">
            <button type="button" class="btn-sm" onclick="App.previewSceneSeItem(${idx})" style="padding: 2px 6px; font-size: 10px;" title="このSEを試聴">🔊 試聴</button>
            <button type="button" class="btn-sm btn-danger" onclick="App.removeSceneSeItem(${idx})" style="padding: 2px 6px; font-size: 10px;" title="削除">🗑️</button>
          </div>
        </div>
        <div style="margin-bottom: 6px;">
          <select class="form-control" style="font-size: 11px; padding: 4px;" onchange="App.updateSceneSeItem(${idx}, 'sound_effect', this.value)">
            ${seOptions}
          </select>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-bottom: 6px;">
          <div>
            <label style="font-size: 10px; color: #aaa; margin: 0 0 2px 0;">⏱️ 開始遅延 (秒)</label>
            <input type="number" class="form-control" style="font-size: 11px; padding: 3px;" min="0" max="30" step="0.1" value="${item.se_offset || 0.0}" onchange="App.updateSceneSeItem(${idx}, 'se_offset', parseFloat(this.value))">
          </div>
          <div>
            <label style="font-size: 10px; color: #aaa; margin: 0 0 2px 0;">🔊 音量 (${Math.round((item.volume !== undefined ? item.volume : 1.0) * 100)}%)</label>
            <input type="range" min="0" max="200" value="${Math.round((item.volume !== undefined ? item.volume : 1.0) * 100)}" class="range-slider" style="height: 4px;" oninput="this.previousElementSibling.innerText = '🔊 音量 (' + this.value + '%)'; App.updateSceneSeItem(${idx}, 'volume', this.value / 100.0)">
          </div>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 4px;">
          <label class="switch-inline" style="font-size: 10px;">
            <input type="checkbox" ${item.se_reverse === true ? "checked" : ""} onchange="App.updateSceneSeItem(${idx}, 'se_reverse', this.checked)">
            <span>🔄 逆再生</span>
          </label>
          <div style="font-size: 10px; color: #888;">
            速度: <input type="number" min="0.5" max="2.0" step="0.1" value="${item.speed || 1.0}" style="width: 45px; font-size: 10px; background: #1a1c23; border: 1px solid #444; color: #eee; padding: 2px 4px; border-radius: 4px;" onchange="App.updateSceneSeItem(${idx}, 'speed', parseFloat(this.value))">x
          </div>
        </div>
      `;
      container.appendChild(card);
    });
  },

  addSceneSeItem() {
    if (!this.project || !this.project.scenes) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;
    this.pushUndoState();
    const list = this.getSceneSeList(scene);
    list.push({
      id: "se_" + Date.now(),
      sound_effect: (this.soundEffectsList && this.soundEffectsList[0]) ? this.soundEffectsList[0].path : "",
      se_offset: 0.0,
      volume: 1.0,
      speed: 1.0,
      se_reverse: false
    });
    scene.sound_effects = list;
    // 下位互換更新
    scene.sound_effect = list[0] ? list[0].sound_effect : "";
    scene.se_offset = list[0] ? list[0].se_offset : 0.0;
    scene.se_reverse = list[0] ? list[0].se_reverse : false;

    this.renderInspectorSeList(scene);
    this.renderTimeline();
  },

  updateSceneSeItem(idx, field, val) {
    if (!this.project || !this.project.scenes) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;
    const list = this.getSceneSeList(scene);
    if (list[idx]) {
      list[idx][field] = val;
      // 下位互換更新
      if (idx === 0) {
        if (field === "sound_effect") scene.sound_effect = val;
        if (field === "se_offset") scene.se_offset = val;
        if (field === "se_reverse") scene.se_reverse = val;
      }
      this.renderTimeline();
    }
  },

  removeSceneSeItem(idx) {
    if (!this.project || !this.project.scenes) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;
    this.pushUndoState();
    const list = this.getSceneSeList(scene);
    list.splice(idx, 1);
    scene.sound_effects = list;
    scene.sound_effect = list[0] ? list[0].sound_effect : "";
    scene.se_offset = list[0] ? list[0].se_offset : 0.0;
    scene.se_reverse = list[0] ? list[0].se_reverse : false;

    this.renderInspectorSeList(scene);
    this.renderTimeline();
  },

  previewSceneSeItem(idx) {
    if (!this.project || !this.project.scenes) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;
    const list = this.getSceneSeList(scene);
    const item = list[idx];
    if (!item || !item.sound_effect) {
      alert("効果音を選択してください。");
      return;
    }
    const seUrl = `/media/${encodeURIComponent(item.sound_effect)}`;
    this.playCustomAudio(seUrl, {
      volume: Math.min(1.0, item.volume !== undefined ? item.volume : 1.0),
      playbackRate: item.speed || 1.0,
      reverse: item.se_reverse === true
    }).catch(e => alert("試聴エラー: " + e));
  },

  insertSeMarkerAtCursor(textareaId) {
    const el = document.getElementById(textareaId);
    if (!el) return;

    const startPos = el.selectionStart !== undefined ? el.selectionStart : el.value.length;
    const endPos = el.selectionEnd !== undefined ? el.selectionEnd : el.value.length;
    const oldText = el.value;

    const newText = oldText.substring(0, startPos) + "[SE]" + oldText.substring(endPos);
    el.value = newText;
    el.focus();
    el.selectionStart = el.selectionEnd = startPos + 4;

    if (textareaId === "insp-text") {
      this.onTextFieldChange(newText);
    }
  },

  onTemplateSelect(idxStr) {
    if (!idxStr) return;
    const idx = parseInt(idxStr);
    const tmpl = VOICE_TEMPLATES[idx];
    if (!tmpl) return;

    const scene = this.project.scenes[this.currentSceneIndex];
    if (scene) {
      scene.voice = tmpl.voice;
      scene.speed = tmpl.speed;
      scene.pitch = tmpl.pitch;

      document.getElementById("insp-voice-type").value = tmpl.voice;
      document.getElementById("insp-speed").value = tmpl.speed;
      document.getElementById("insp-speed-val").innerText = `${tmpl.speed}%`;
      document.getElementById("insp-pitch").value = tmpl.pitch;
      document.getElementById("insp-pitch-val").innerText = `${tmpl.pitch}%`;

      this.renderTimeline();
    }
  },

  onToggleCurrentSceneSkip(isNoVoice) {
    if (!this.project || !this.project.scenes) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (scene) {
      scene.no_voice = isNoVoice;
      scene.is_skipped = isNoVoice;
      scene.is_enabled = !isNoVoice;
      this.renderScenesList();
      this.renderTimeline();
    }
  },

  updatePreviewForScene(scene, offsetSec = 0.0, shouldPlayVideo = false) {
    if (!scene) return;

    const telop = document.getElementById("preview-telop-text");
    if (telop) telop.innerText = scene.text || "(無音スライド)";

    const overlay = document.getElementById("preview-telop-overlay");
    if (overlay) {
      overlay.style.display = this.showTelopOverlay ? "block" : "none";
    }

    const scenes = this.project && this.project.scenes ? this.project.scenes : [];
    const sceneIdx = scenes.indexOf(scene);
    const isPreloadedCandidate = (sceneIdx !== -1 && sceneIdx === this._preloadedSceneIndex && offsetSec < 0.05);

    if (isPreloadedCandidate) {
      // 0秒シームレススワップ: 裏バッファを瞬時にアクティブ化
      this._activeMediaChannel = (this._activeMediaChannel === 'a') ? 'b' : 'a';
    }

    const active = this.getActiveMediaElements();
    const inactive = this.getInactiveMediaElements();
    const comp = this.getSceneMediaComparison(scene);

    // 1. スライド画像は常にベースポスターとして下層（zIndex: 2）に即時表示（黒画面を完全防止）
    if (comp.imgPath && active.img) {
      const imgUrl = `/media/${encodeURIComponent(comp.imgPath)}`;
      if (active.img.src !== window.location.origin + imgUrl && active.img.src !== imgUrl) {
        active.img.src = imgUrl;
      }
      active.img.style.display = "block";
      active.img.style.zIndex = "2";
    }

    if (comp.isVideoMode && comp.videoClip) {
      // 動画モード: syncPreviewVideo で安全にシーク・再生
      this.syncPreviewVideo(scene, offsetSec, shouldPlayVideo, comp);

      // 直前の裏バッファを隠蔽
      if (inactive.video && inactive.video !== active.video) {
        inactive.video.style.zIndex = "1";
        try { inactive.video.pause(); } catch(e) {}
        inactive.video.style.display = "none";
      }
      if (inactive.img && inactive.img !== active.img) {
        inactive.img.style.zIndex = "1";
        inactive.img.style.display = "none";
      }
    } else {
      // 静止画モード: スライド画像を前面表示し動画を確実に停止・非表示
      if (active.img) {
        active.img.style.display = "block";
        active.img.style.zIndex = "3";
      }
      if (active.video) {
        try { active.video.pause(); } catch(e) {}
        active.video.style.display = "none";
      }

      // 直前の裏バッファを隠蔽
      if (inactive.video) {
        inactive.video.style.zIndex = "1";
        try { inactive.video.pause(); } catch(e) {}
        inactive.video.style.display = "none";
      }
      if (inactive.img && inactive.img !== active.img) {
        inactive.img.style.zIndex = "1";
        inactive.img.style.display = "none";
      }
    }

    // 次のシーン (sceneIdx + 1) を直ちに裏バッファへ事前プリロード（0秒待機化）
    if (sceneIdx !== -1) {
      setTimeout(() => {
        this.preloadUpcomingMedia(sceneIdx + 1);
      }, 10);
    }
  },

  previewCurrentAnimation() {
    this.togglePlay();
  },

  stopAnimationPreview() {
    this.isAnimPreviewPlaying = false;
    ["preview-video", "preview-video-b"].forEach(id => {
      const el = document.getElementById(id);
      if (el) {
        try { el.pause(); } catch (e) {}
      }
    });
  },

  toggleTelopOverlay() {
    this.showTelopOverlay = !this.showTelopOverlay;
    const overlay = document.getElementById("preview-telop-overlay");
    const btn = document.getElementById("btn-toggle-telop");
    const fsBtn = document.getElementById("btn-fs-toggle-telop");

    if (overlay) overlay.style.display = this.showTelopOverlay ? "block" : "none";
    if (btn) {
      btn.style.opacity = this.showTelopOverlay ? "1.0" : "0.6";
      btn.style.background = this.showTelopOverlay ? "var(--accent-blue)" : "transparent";
    }
    if (fsBtn) {
      fsBtn.style.opacity = this.showTelopOverlay ? "1.0" : "0.6";
      fsBtn.style.background = this.showTelopOverlay ? "var(--accent-blue)" : "transparent";
    }

    // 字幕の表示処理の中にプレビュー画面を字幕が出ているシーンに合わせる処理
    if (this.project && this.project.scenes && this.project.scenes.length > 0) {
      let targetIdx = this.currentSceneIndex;
      if (targetIdx < 0 || targetIdx >= this.project.scenes.length) {
        targetIdx = 0;
      }
      const scene = this.project.scenes[targetIdx];
      if (scene) {
        let offsetSec = 0.0;
        const sceneStartTime = this.getSceneStartTime(targetIdx);
        if (this.playheadTime !== undefined && this.playheadTime >= sceneStartTime) {
          offsetSec = Math.max(0.0, this.playheadTime - sceneStartTime);
        }
        this.updatePreviewForScene(scene, offsetSec, this.isPlaying);
      }
    }
  },

  clearInspector() {
    document.getElementById("inspector-empty").style.display = "block";
    document.getElementById("inspector-form").style.display = "none";
  },

  onTextFieldChange(text) {
    if (!this.project || !this.project.scenes) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (scene) {
      scene.text = text;
      this.updatePreviewForScene(scene);
    }
  },

  onCurrentSceneFieldChange(field, value) {
    if (!this.project || !this.project.scenes) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (scene) {
      scene[field] = value;
      this.renderTimeline();
    }
  },

  onCharacterSelect(charName) {
    if (!this.project || !this.project.scenes) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (scene) {
      scene.character = charName;
      if (this.config && this.config.characters && this.config.characters[charName]) {
        const c = this.config.characters[charName];
        scene.voice = c.voice;
        scene.speed = c.speed;
        scene.pitch = c.pitch;

        document.getElementById("insp-voice-type").value = c.voice;
        document.getElementById("insp-speed").value = c.speed;
        document.getElementById("insp-speed-val").innerText = `${c.speed}%`;
        document.getElementById("insp-pitch").value = c.pitch;
        document.getElementById("insp-pitch-val").innerText = `${c.pitch}%`;
      }
      this.renderScenesList();
      this.renderTimeline();
    }
  },

  onSpeedChange(val) {
    document.getElementById("insp-speed-val").innerText = `${val}%`;
    this.onCurrentSceneFieldChange("speed", parseInt(val));
  },

  onPitchChange(val) {
    document.getElementById("insp-pitch-val").innerText = `${val}%`;
    this.onCurrentSceneFieldChange("pitch", parseInt(val));
  },

  async reconvertCurrentKanji2Koe(flat = false) {
    const text = document.getElementById("insp-text").value;
    if (!text) return;

    try {
      const res = await fetch("/api/kanji2koe", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text, flat })
      });
      const data = await res.json();
      if (data.success) {
        document.getElementById("insp-phonemes").value = data.phonemes;
        this.onCurrentSceneFieldChange("phonemes", data.phonemes);
      }
    } catch (e) {
      alert("記号列変換エラー: " + e);
    }
  },

  // ==========================================
  // 音声合成・試聴・再生成・保存
  // ==========================================
  async previewCurrentVoice() {
    this.stopAllAudioAndTimers(false);
    // ユーザー操作の同期コンテキストで AudioContext を即座にアンロック
    this.getAudioContext();

    const text = document.getElementById("insp-text") ? document.getElementById("insp-text").value.trim() : "";
    const phonemes = document.getElementById("insp-phonemes") ? document.getElementById("insp-phonemes").value.trim() : "";
    const voice = document.getElementById("insp-voice-type") ? document.getElementById("insp-voice-type").value : "f1";
    const speed = parseInt(document.getElementById("insp-speed") ? document.getElementById("insp-speed").value : "100");
    const pitch = parseInt(document.getElementById("insp-pitch") ? document.getElementById("insp-pitch").value : "100");
    const effect = document.getElementById("insp-effect-select") ? document.getElementById("insp-effect-select").value : "none";
    const quality_enhance = document.getElementById("insp-quality-select") ? (document.getElementById("insp-quality-select").value === "1") : true;
    const sound_effect = document.getElementById("insp-se-select") ? document.getElementById("insp-se-select").value : "";
    const se_offset = parseFloat(document.getElementById("insp-se-offset") ? document.getElementById("insp-se-offset").value : 0.0) || 0.0;

    if (!text && !phonemes) {
      alert("試聴するセリフまたは音声記号列を入力してください。");
      return;
    }

    try {
      const res = await fetch("/api/tts/preview", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: text,
          phonemes: phonemes,
          voice: voice,
          speed: speed,
          pitch: pitch,
          effect: effect,
          quality_enhance: quality_enhance,
          sound_effect: sound_effect || null,
          se_offset: se_offset
        })
      });
      const data = await res.json();
      if (data.success && (data.audio_data_url || data.preview_url)) {
        await this.playAudioSafely(data.audio_data_url || data.preview_url);
      } else {
        alert("試聴音声生成エラー: " + (data.error || "音声の生成に失敗しました"));
      }
    } catch (e) {
      alert("試聴通信エラー: " + e);
    }
  },

  async downloadCurrentVoice() {
    const text = document.getElementById("insp-text") ? document.getElementById("insp-text").value.trim() : "";
    const phonemes = document.getElementById("insp-phonemes") ? document.getElementById("insp-phonemes").value.trim() : "";
    const voice = document.getElementById("insp-voice-type") ? document.getElementById("insp-voice-type").value : "f1";
    const speed = parseInt(document.getElementById("insp-speed") ? document.getElementById("insp-speed").value : "100");
    const pitch = parseInt(document.getElementById("insp-pitch") ? document.getElementById("insp-pitch").value : "100");
    const effect = document.getElementById("insp-effect-select") ? document.getElementById("insp-effect-select").value : "none";
    const quality_enhance = document.getElementById("insp-quality-select") ? (document.getElementById("insp-quality-select").value === "1") : true;
    const sound_effect = document.getElementById("insp-se-select") ? document.getElementById("insp-se-select").value : "";
    const se_offset = parseFloat(document.getElementById("insp-se-offset") ? document.getElementById("insp-se-offset").value : 0.0) || 0.0;

    try {
      const res = await fetch("/api/tts/preview", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: text,
          phonemes: phonemes,
          voice: voice,
          speed: speed,
          pitch: pitch,
          effect: effect,
          quality_enhance: quality_enhance,
          sound_effect: sound_effect || null,
          se_offset: se_offset
        })
      });
      const data = await res.json();
      if (data.success && data.audio_data_url) {
        const scene = this.project ? this.project.scenes[this.currentSceneIndex] : null;
        const link = document.createElement("a");
        link.href = data.audio_data_url;
        link.download = `scene_${scene ? (scene.slide_index || (this.currentSceneIndex + 1)) : 1}_${voice}.wav`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      } else {
        alert("音声のダウンロードに失敗しました。");
      }
    } catch (e) {
      alert("ダウンロードエラー: " + e);
    }
  },

  async regenerateCurrentVoice() {
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;

    // インスペクタの最新値を反映
    if (document.getElementById("insp-text")) scene.text = document.getElementById("insp-text").value;
    if (document.getElementById("insp-phonemes")) scene.phonemes = document.getElementById("insp-phonemes").value;
    if (document.getElementById("insp-voice-type")) scene.voice = document.getElementById("insp-voice-type").value;
    if (document.getElementById("insp-speed")) scene.speed = parseInt(document.getElementById("insp-speed").value);
    if (document.getElementById("insp-pitch")) scene.pitch = parseInt(document.getElementById("insp-pitch").value);
    if (document.getElementById("insp-effect-select")) scene.effect = document.getElementById("insp-effect-select").value;
    if (document.getElementById("insp-quality-select")) scene.quality_enhance = document.getElementById("insp-quality-select").value === "1";
    if (document.getElementById("insp-se-select")) scene.sound_effect = document.getElementById("insp-se-select").value || null;
    if (document.getElementById("insp-se-offset")) scene.se_offset = parseFloat(document.getElementById("insp-se-offset").value) || 0.0;

    try {
      const res = await fetch("/api/tts/generate_single", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          scene: scene,
          project_name: this.project.project_name || "default"
        })
      });
      const data = await res.json();
      if (data.success && data.scene) {
        data.scene._cacheBuster = Date.now();
        const isAnim = this.hasAnimationInstruction(data.scene.notes, data.scene.text);
        if (!isAnim) {
          data.scene.extra_delay = 0.0;
          data.scene.has_animation = false;
          data.scene.video_clip_path = null;
          data.scene.video_duration = null;
          data.scene.animation_duration = null;
          data.scene.target_duration = null;
          const delayInp = document.getElementById("insp-extra-delay");
          if (delayInp) delayInp.value = 0.0;
        }
        this.project.scenes[this.currentSceneIndex] = data.scene;
        this.renderScenesList();
        this.renderTimeline();
        this.selectScene(this.currentSceneIndex);
        alert("音声の再生成が完了しました！");
      } else {
        alert("音声生成エラー: " + (data.error || ""));
      }
    } catch (e) {
      alert("通信エラー: " + e);
    }
  },

  async regenerateSelectedVoices() {
    const selIndices = Array.from(this.selectedSceneIndices);
    if (selIndices.length === 0) {
      alert("再生成したいシーンのチェックボックス（左上の四角）にチェックを入れてください。");
      return;
    }

    if (!confirm(`チェックを入れた ${selIndices.length} 件のシーンの音声を再生成しますか？\n（セリフと音声が一致するまで自動検証・リトライされます）`)) {
      return;
    }

    const targetScenes = selIndices.map(idx => this.project.scenes[idx]);
    this.showTaskProgress("⚡ 選択音声の再生成", `[0/${selIndices.length}] 音声合成を開始しています...`, 10, "ゆっくりボイス音声を生成中...");

    let pVal = 15;
    const voiceTimer = setInterval(() => {
      if (pVal < 90) {
        pVal += Math.max(5, Math.round(75 / selIndices.length));
        this.showTaskProgress("⚡ 選択音声の再生成", `[進行中] 音声を高品質に合成中...`, Math.min(90, pVal), `${selIndices.length} 件のシーンを処理しています`);
      }
    }, 800);
    
    try {
      const res = await fetch("/api/tts/generate_all", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          scenes: targetScenes,
          project_name: this.project.project_name || "default"
        })
      });
      clearInterval(voiceTimer);
      const data = await res.json();
      if (data.success && data.scenes) {
        // 更新されたシーンを元の配列に反映
        const now = Date.now();
        data.scenes.forEach((updatedScene, i) => {
          updatedScene._cacheBuster = now;
          const isAnim = this.hasAnimationInstruction(updatedScene.notes, updatedScene.text);
          if (!isAnim) {
            updatedScene.extra_delay = 0.0;
            updatedScene.has_animation = false;
            updatedScene.video_clip_path = null;
            updatedScene.video_duration = null;
            updatedScene.animation_duration = null;
            updatedScene.target_duration = null;
          }
          const originalIdx = selIndices[i];
          this.project.scenes[originalIdx] = updatedScene;
        });

        this.renderScenesList();
        this.renderTimeline();
        this.selectScene(this.currentSceneIndex);
        this.showTaskProgress("✅ 音声再生成完了", `選択した ${selIndices.length} 件の音声再生成が完了しました！`, 100, "タイムラインに反映されました");
      } else {
        this.closeTaskProgressModal();
        alert("選択音声の再生成エラー: " + (data.error || ""));
      }
    } catch (e) {
      clearInterval(voiceTimer);
      this.closeTaskProgressModal();
      alert("通信エラー: " + e);
    }
  },

  async generateAllVoices() {
    if (!confirm("タイムライン上の全シーンの音声をまとめて一括再生成しますか？")) return;

    const totalCount = this.project.scenes ? this.project.scenes.length : 0;
    this.showTaskProgress("🗣️ 全シーン音声一括生成", `[0/${totalCount}] 全シーンの音声を合成中...`, 10, "ゆっくりボイス音声を一括生成しています...");

    let pVal = 10;
    const allVoiceTimer = setInterval(() => {
      if (pVal < 92) {
        pVal += 8;
        this.showTaskProgress("🗣️ 全シーン音声一括生成", `[進行中] 全 ${totalCount} シーンの音声を合成中...`, pVal, "音質改善・エフェクトを適用中...");
      }
    }, 1200);

    try {
      const res = await fetch("/api/tts/generate_all", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          scenes: this.project.scenes,
          project_name: this.project.project_name || "default"
        })
      });
      clearInterval(allVoiceTimer);
      const data = await res.json();
      if (data.success && data.scenes) {
        const now = Date.now();
        data.scenes.forEach(s => {
          s._cacheBuster = now;
          const isAnim = this.hasAnimationInstruction(s.notes, s.text);
          if (!isAnim) {
            s.extra_delay = 0.0;
            s.has_animation = false;
            s.video_clip_path = null;
            s.video_duration = null;
            s.animation_duration = null;
            s.target_duration = null;
          }
        });
        this.project.scenes = data.scenes;
        this.renderScenesList();
        this.renderTimeline();
        this.selectScene(this.currentSceneIndex);
        this.showTaskProgress("✅ 一括生成完了", `全 ${totalCount} シーンの音声一括生成が完了しました！`, 100, "プロジェクトを自動保存しました");
      } else {
        this.closeTaskProgressModal();
        alert("一括生成エラー: " + data.error);
      }
    } catch (e) {
      clearInterval(allVoiceTimer);
      this.closeTaskProgressModal();
      alert("一括生成通信エラー: " + e);
    }
  },

  async regenerateAllMedia() {
    if (!this.project || !this.project.scenes) {
      alert("プロジェクトが開かれていません。");
      return;
    }
    if (!confirm("【3素材の一括再生成】\n既存のセリフ本文・音声記号列・ボイス設定・SE/BGMを完全に保持したまま、\n1. スライド画像の最新化\n2. アニメーション動画の再切り出し\n3. 全音声の再生成\n4. タイムラインのズレ完全修正\nを順次自動実行します。よろしいですか？")) return;

    // 1. 画像・動画更新
    this.showTaskProgress("✨ 3素材一括再生成", "Step 1/4: スライド画像および動画クリップを最新化しています...", 25, "Keynoteスライドを走査中...");
    
    try {
      const res1 = await fetch("/api/project/refresh_media", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ project: this.project })
      });
      const data1 = await res1.json();
      if (data1.success) {
        if (data1.project) this.project = data1.project;
        else if (data1.scenes) this.project.scenes = data1.scenes;
      } else {
        throw new Error("画像・動画の更新に失敗しました: " + data1.error);
      }

      // 2. 音声一括再生成
      this.showTaskProgress("✨ 3素材一括再生成", "Step 2/4: 既存のボイス設定を保持したまま全音声を合成しています...", 50, "ゆっくり音声を生成中...");
      
      const res2 = await fetch("/api/tts/generate_all", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          scenes: this.project.scenes,
          project_name: this.project.project_name || "default"
        })
      });
      const data2 = await res2.json();
      if (data2.success && data2.scenes) {
        const now = Date.now();
        data2.scenes.forEach(s => s._cacheBuster = now);
        this.project.scenes = data2.scenes;
      } else {
        throw new Error("音声の再生成に失敗しました: " + data2.error);
      }
      
      // 3. ディスク上の実ファイルから尺を完全同期
      this.showTaskProgress("✨ 3素材一括再生成", "Step 3/4: 生成された実ファイルから正確な再生時間を再計算しています...", 75, "ディスクのWAV/MP4ファイルを走査中...");
      
      const res3 = await fetch("/api/project/sync_durations", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ scenes: this.project.scenes })
      });
      const data3 = await res3.json();
      if (data3.success && data3.scenes) {
        this.project.scenes = data3.scenes;
      }

      // アニメーション指示のないシーンの余白を確実に0.0に整流
      if (this.project && this.project.scenes) {
        this.project.scenes.forEach(s => {
          if (!this.hasAnimationInstruction(s.notes, s.text)) {
            s.extra_delay = 0.0;
            s.has_animation = false;
            s.video_clip_path = null;
            s.video_duration = null;
            s.animation_duration = null;
            s.target_duration = null;
          }
        });
      }
      
      // 4. UI更新
      this.showTaskProgress("✨ 3素材一括再生成", "Step 4/4: タイムラインとプレビューを完全同期中...", 90, "UIを再描画中...");
      
      this.renderScenesList();
      this.renderTimeline();
      this.selectScene(this.currentSceneIndex);
      
      this.showTaskProgress("✅ 一括再生成と全同期完了", `画像・動画・音声の再生成、およびタイムラインのズレ完全修正が完了しました！`, 100, "セリフやボイス設定はすべて完全に維持されています");
      
    } catch (e) {
      this.closeTaskProgressModal();
      alert("エラーが発生しました: " + e.message);
    }
  },

  async regenerateVideosOnly() {
    if (!this.project || !this.project.scenes) return;
    if (!confirm("【動画のみ再生成】\n既存のセリフや音声・設定は変更せず、最新のアニメーション動画のみを再切り出ししますか？")) return;
    
    this.showTaskProgress("🎬 動画再生成", "アニメーション動画クリップを再取得・切り出し中...", 50, "処理中です...");
    try {
      const res = await fetch("/api/project/refresh_media", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ project: this.project })
      });
      const data = await res.json();
      if (data.success) {
        if (data.project) this.project = data.project;
        else if (data.scenes) this.project.scenes = data.scenes;
        
        await fetch("/api/project/sync_durations", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ scenes: this.project.scenes })
        });

        // アニメーション指示のないシーンの余白を確実に0.0に整流
        if (this.project && this.project.scenes) {
          this.project.scenes.forEach(s => {
            if (!this.hasAnimationInstruction(s.notes, s.text)) {
              s.extra_delay = 0.0;
              s.has_animation = false;
              s.video_clip_path = null;
              s.video_duration = null;
              s.animation_duration = null;
              s.target_duration = null;
            }
          });
        }
        
        this.renderScenesList();
        this.renderTimeline();
        this.selectScene(this.currentSceneIndex);
        this.showTaskProgress("✅ 動画再生成完了", `アニメーション動画の再生成が完了しました！`, 100, "タイムラインを同期しました");
      } else {
        throw new Error(data.error);
      }
    } catch (e) {
      this.closeTaskProgressModal();
      alert("エラー: " + e.message);
    }
  },

  async refreshSlideImagesOnly() {
    if (!this.project || !this.project.scenes) return;
    if (!confirm("【画像のみ再生成】\n既存のセリフや音声・設定は変更せず、最新のスライド画像のみを再取得しますか？")) return;
    
    this.showTaskProgress("🖼️ 画像再生成", "スライド画像を再取得中...", 50, "処理中です...");
    try {
      const res = await fetch("/api/project/refresh_media", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ project: this.project })
      });
      const data = await res.json();
      if (data.success) {
        if (data.project) this.project = data.project;
        else if (data.scenes) this.project.scenes = data.scenes;

        // アニメーション指示のないシーンの余白を確実に0.0に整流
        if (this.project && this.project.scenes) {
          this.project.scenes.forEach(s => {
            if (!this.hasAnimationInstruction(s.notes, s.text)) {
              s.extra_delay = 0.0;
              s.has_animation = false;
              s.video_clip_path = null;
              s.video_duration = null;
              s.animation_duration = null;
              s.target_duration = null;
            }
          });
        }
        
        this.renderScenesList();
        this.renderTimeline();
        this.selectScene(this.currentSceneIndex);
        this.showTaskProgress("✅ 画像再生成完了", `スライド画像の再取得が完了しました！`, 100, "タイムラインを同期しました");
      } else {
        throw new Error(data.error);
      }
    } catch (e) {
      this.closeTaskProgressModal();
      alert("エラー: " + e.message);
    }
  },

  async fixTimelinePreviewSync() {
    if (!this.project || !this.project.scenes) return;

    this.showTaskProgress("🔧 ズレ修正・全同期", "ステップ1: サーバーで音声・動画実測尺を取得中...", 5, "WAV/MP4ファイルをffprobeで計測しています...");

    // --- Step 1: サーバーAPIで実測尺を同期（可能な場合）---
    let serverUpdated = 0;
    try {
      const res = await fetch("/api/project/sync_durations", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          scenes: this.project.scenes,
          project_name: this.project.project_name || ""
        })
      });
      const data = await res.json();
      if (data.success && data.scenes) {
        this.project.scenes = data.scenes;
        serverUpdated = data.updated_count || 0;
      }
    } catch (e) {
      console.warn("[Sync] サーバーAPI失敗、ブラウザ計測にフォールバック:", e.message);
    }

    // --- Step 2: ブラウザのVideoElementで全シーンのMP4実尺を直接計測・補正 ---
    this.showTaskProgress("🔧 ズレ修正・全同期", "ステップ2: ブラウザでMP4実尺を直接計測中...", 20, `${this.project.scenes.length}シーンのMP4を順次計測しています...`);

    const scenes = this.project.scenes;
    const pName = (this.project && this.project.project_name) ? this.project.project_name : "";
    const sName = (this.project && this.project.series_name) ? this.project.series_name : "交換夫婦";
    let browserUpdated = 0;

    // 並列計測のヘルパー（VideoElement で duration を取得）
    const measureVideoDuration = (videoUrl) => new Promise((resolve) => {
      const vid = document.createElement("video");
      vid.preload = "metadata";
      const timer = setTimeout(() => { resolve(null); }, 8000); // 8秒タイムアウト
      vid.onloadedmetadata = () => {
        clearTimeout(timer);
        const dur = (!isNaN(vid.duration) && vid.duration > 0) ? vid.duration : null;
        vid.src = "";
        resolve(dur);
      };
      vid.onerror = () => { clearTimeout(timer); resolve(null); };
      vid.src = videoUrl;
    });

    // シーンを8件ずつバッチ処理
    const BATCH = 8;
    for (let batchStart = 0; batchStart < scenes.length; batchStart += BATCH) {
      const batchEnd = Math.min(batchStart + BATCH, scenes.length);
      const progress = Math.round(20 + 75 * (batchStart / scenes.length));
      this.showTaskProgress(
        "🔧 ズレ修正・全同期",
        `ステップ2: MP4実尺計測中... (${batchStart}/${scenes.length})`,
        progress,
        `Slide ${batchStart + 1}〜${batchEnd} を計測中`
      );

      await Promise.all(scenes.slice(batchStart, batchEnd).map(async (s, localIdx) => {
        if (!s) return;
        const idx = batchStart + localIdx;
        const sIdx = s.slide_index || (idx + 1);
        const sNum = sIdx < 10 ? `00${sIdx}` : (sIdx < 100 ? `0${sIdx}` : `${sIdx}`);

        // ノート/テキストのアニメーション指示タグ判定
        const isAnim = this.hasAnimationInstruction(s.notes, s.text);
        if (!isAnim) {
          s.has_animation = false;
          s.video_duration = null;
          s.animation_duration = null;
          s.video_clip_path = null;
          s.animation_path = null;
          s.target_duration = null;
          s.extra_delay = 0;
          return;
        }

        // MP4パス解決（has_animation が true かつアニメーション指示があるシーンのみ動画尺を計測）
        if (!s.has_animation && !s.video_clip_path && !s.animation_path) {
          s.has_animation = false;
          s.video_duration = null;
          s.animation_duration = null;
          s.video_clip_path = null;
          s.animation_path = null;
          s.target_duration = null;
          s.extra_delay = 0;
          return;
        }
        let videoPath = s.video_clip_path || s.animation_path;
        if (!videoPath) return;

        const videoUrl = `/media/${encodeURIComponent(videoPath)}`;
        const actualDur = await measureVideoDuration(videoUrl);
        if (actualDur === null) return;

        const oldDur = parseFloat(s.video_duration || s.animation_duration || 0);
        if (Math.abs(oldDur - actualDur) > 0.05) {
          const audioDur = parseFloat(s.audio_duration || 0);
          if (actualDur > audioDur && audioDur > 0) {
            // 動画の方が長い → 動画モード・extra_delay 再計算
            s.video_duration = actualDur;
            s.animation_duration = actualDur;
            s.has_animation = true;
            s.extra_delay = parseFloat((actualDur - audioDur).toFixed(4));
          } else if (audioDur > 0 && actualDur <= audioDur) {
            // 音声の方が長い → 静止画モードに戻す
            s.video_duration = null;
            s.animation_duration = null;
            s.has_animation = false;
            s.extra_delay = 0;
          } else if (audioDur === 0) {
            // 音声なしスライド（タイトル等）: 動画尺をそのまま使用
            s.video_duration = actualDur;
            s.animation_duration = actualDur;
            s.has_animation = true;
            s.extra_delay = actualDur;
          }
          browserUpdated++;
        }
      }));
    }

    // --- Step 3: タイムライン・プレビューを再描画 ---
    const wasPlaying = this.isPlaying;
    if (wasPlaying) this.pause();

    this.sceneOffsetsCache = null;
    this._audioBufferCache && this._audioBufferCache.clear();

    this.renderScenesList();
    this.renderTimeline();
    this.selectScene(this.currentSceneIndex, true, 0.0);

    const total = serverUpdated + browserUpdated;
    this.showTaskProgress(
      "✅ 全同期完了",
      `サーバー補正: ${serverUpdated}件\nブラウザ直接計測補正: ${browserUpdated}件\n合計 ${total}件のクリップのズレを修正しました！`,
      100,
      "タイムラインとプレビューが再同期されました"
    );
  },

  // ==========================================
  // ポップアップ校正モーダル (要件3)
  // ==========================================
  openPopupEditor() {
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;

    document.getElementById("popup-editor-title").innerText = 
      `🔍 詳細校正ポップアップ [Scene ${scene.slide_index || (this.currentSceneIndex + 1)}]`;
    
    document.getElementById("popup-text").value = scene.text || "";
    document.getElementById("popup-phonemes").value = scene.phonemes || "";
    document.getElementById("popup-character").value = scene.character || "操夢";
    document.getElementById("popup-voice").value = scene.voice || "f1";
    document.getElementById("popup-speed").value = scene.speed || 100;
    document.getElementById("popup-speed-val").innerText = `${scene.speed || 100}%`;
    document.getElementById("popup-pitch").value = scene.pitch || 100;
    document.getElementById("popup-pitch-val").innerText = `${scene.pitch || 100}%`;

    // 効果 (エフェクト) と 音質改善
    const effSel = document.getElementById("popup-effect-select");
    if (effSel) effSel.value = scene.effect || "none";

    const qualSel = document.getElementById("popup-quality-select");
    if (qualSel) qualSel.value = scene.quality_enhance === false ? "0" : "1";

    const tmplSel = document.getElementById("popup-template-select");
    if (tmplSel) tmplSel.value = "";

    document.getElementById("popup-nav-counter").innerText = 
      `${this.currentSceneIndex + 1} / ${this.project.scenes.length}`;

    const isNoVoice = (scene.no_voice === true || scene.is_skipped === true || scene.is_enabled === false);
    const skipChk = document.getElementById("popup-skip-checkbox");
    if (skipChk) skipChk.checked = isNoVoice;

    // アニメーション待機時間 & 効果音 & SEタイミング
    const delayInp = document.getElementById("popup-extra-delay");
    if (delayInp) delayInp.value = scene.extra_delay !== undefined ? scene.extra_delay : 0.0;

    const seSelect = document.getElementById("popup-se-select");
    if (seSelect) seSelect.value = scene.sound_effect || "";

    const seOffsetInp = document.getElementById("popup-se-offset");
    if (seOffsetInp) seOffsetInp.value = scene.se_offset !== undefined ? scene.se_offset : 0.0;

    // スライド画像のプレビュー表示
    const popupImg = document.getElementById("popup-slide-img");
    const popupNoImg = document.getElementById("popup-slide-noimg");
    if (popupImg && popupNoImg) {
      if (scene.image_path) {
        popupImg.src = `/media/${encodeURIComponent(scene.image_path)}`;
        popupImg.style.display = "block";
        popupNoImg.style.display = "none";
      } else {
        popupImg.style.display = "none";
        popupNoImg.style.display = "block";
      }
    }

    document.getElementById("modal-popup-editor").classList.add("active");
  },

  popupOnTemplateSelect(idxStr) {
    if (!idxStr) return;
    const idx = parseInt(idxStr);
    const tmpl = VOICE_TEMPLATES[idx];
    if (!tmpl) return;

    document.getElementById("popup-voice").value = tmpl.voice;
    document.getElementById("popup-speed").value = tmpl.speed;
    document.getElementById("popup-speed-val").innerText = `${tmpl.speed}%`;
    document.getElementById("popup-pitch").value = tmpl.pitch;
    document.getElementById("popup-pitch-val").innerText = `${tmpl.pitch}%`;
  },

  onPopupToggleSkip(isNoVoice) {
    const scene = this.project.scenes[this.currentSceneIndex];
    if (scene) {
      scene.no_voice = isNoVoice;
      scene.is_skipped = isNoVoice;
      scene.is_enabled = !isNoVoice;
      this.renderScenesList();
      this.renderTimeline();
    }
  },

  closePopupEditor() {
    this.savePopupFieldsToCurrentScene();
    document.getElementById("modal-popup-editor").classList.remove("active");
    this.selectScene(this.currentSceneIndex);
  },

  savePopupFieldsToCurrentScene() {
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;

    scene.text = document.getElementById("popup-text").value;
    scene.phonemes = document.getElementById("popup-phonemes").value;
    scene.character = document.getElementById("popup-character").value;
    scene.voice = document.getElementById("popup-voice").value;
    scene.speed = parseInt(document.getElementById("popup-speed").value);
    scene.pitch = parseInt(document.getElementById("popup-pitch").value);

    const effSel = document.getElementById("popup-effect-select");
    if (effSel) scene.effect = effSel.value;

    const qualSel = document.getElementById("popup-quality-select");
    if (qualSel) scene.quality_enhance = qualSel.value === "1";

    const delayInp = document.getElementById("popup-extra-delay");
    if (delayInp) scene.extra_delay = parseFloat(delayInp.value) || 0.0;

    const seSelect = document.getElementById("popup-se-select");
    if (seSelect) scene.sound_effect = seSelect.value || null;

    const seOffsetInp = document.getElementById("popup-se-offset");
    if (seOffsetInp) scene.se_offset = parseFloat(seOffsetInp.value) || 0.0;

    const skipChk = document.getElementById("popup-skip-checkbox");
    if (skipChk) {
      scene.no_voice = skipChk.checked;
      scene.is_skipped = skipChk.checked;
      scene.is_enabled = !skipChk.checked;
    }
  },

  async popupReconvertKanji2Koe(flat = false) {
    const text = document.getElementById("popup-text").value;
    if (!text) return;
    try {
      const res = await fetch("/api/kanji2koe", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text, flat })
      });
      const data = await res.json();
      if (data.success) {
        document.getElementById("popup-phonemes").value = data.phonemes;
      }
    } catch (e) {
      alert("変換エラー: " + e);
    }
  },

  popupOnCharacterChange(charName) {
    if (this.config && this.config.characters && this.config.characters[charName]) {
      const c = this.config.characters[charName];
      document.getElementById("popup-voice").value = c.voice;
      document.getElementById("popup-speed").value = c.speed;
      document.getElementById("popup-speed-val").innerText = `${c.speed}%`;
      document.getElementById("popup-pitch").value = c.pitch;
      document.getElementById("popup-pitch-val").innerText = `${c.pitch}%`;
    }
  },

  async popupPreviewVoice() {
    // ユーザー操作の同期コンテキストで AudioContext を即座にアンロック
    this.getAudioContext();

    this.savePopupFieldsToCurrentScene();
    const text = document.getElementById("popup-text") ? document.getElementById("popup-text").value.trim() : "";
    const phonemes = document.getElementById("popup-phonemes") ? document.getElementById("popup-phonemes").value.trim() : "";
    const voice = document.getElementById("popup-voice") ? document.getElementById("popup-voice").value : "f1";
    const speed = parseInt(document.getElementById("popup-speed") ? document.getElementById("popup-speed").value : "100");
    const pitch = parseInt(document.getElementById("popup-pitch") ? document.getElementById("popup-pitch").value : "100");
    const effect = document.getElementById("popup-effect-select") ? document.getElementById("popup-effect-select").value : "none";
    const quality_enhance = document.getElementById("popup-quality-select") ? (document.getElementById("popup-quality-select").value === "1") : true;
    const sound_effect = document.getElementById("popup-se-select") ? document.getElementById("popup-se-select").value : "";
    const se_offset = parseFloat(document.getElementById("popup-se-offset") ? document.getElementById("popup-se-offset").value : 0.0) || 0.0;

    if (!text && !phonemes) {
      alert("試聴するセリフまたは音声記号列を入力してください。");
      return;
    }

    try {
      const res = await fetch("/api/tts/preview", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text,
          phonemes,
          voice,
          speed,
          pitch,
          effect,
          quality_enhance,
          sound_effect: sound_effect || null,
          se_offset: se_offset
        })
      });
      const data = await res.json();
      if (data.success && (data.audio_data_url || data.preview_url)) {
        await this.playAudioSafely(data.audio_data_url || data.preview_url);
      } else {
        alert("試聴音声生成エラー: " + (data.error || "音声の生成に失敗しました"));
      }
    } catch (e) {
      alert("試聴通信エラー: " + e);
    }
  },

  async popupApplyAndRegenerate() {
    this.savePopupFieldsToCurrentScene();
    await this.regenerateCurrentVoice();
  },

  async popupDownloadVoice() {
    this.savePopupFieldsToCurrentScene();
    await this.downloadCurrentVoice();
  },

  popupJumpScene(delta) {
    this.savePopupFieldsToCurrentScene();
    const nextIdx = this.currentSceneIndex + delta;
    if (nextIdx >= 0 && nextIdx < this.project.scenes.length) {
      this.currentSceneIndex = nextIdx;
      this.openPopupEditor();
    }
  },

  // ==========================================
  // プレビューコントロール (動画・アニメーション・音声 完全同期再生)
  // ==========================================
  togglePlay() {
    // ユーザー操作の同期コンテキストで AudioContext を即座にアンロック
    this.getAudioContext();

    if (this.isPlaying) {
      this.pause();
    } else {
      this.play();
    }
  },

  async play(deferPreviewUpdate = false) {
    const sessionId = ++this._playSessionId;
    this.isPlaying = true;
    this.isFetchingAudio = true;

    const btn = document.getElementById("btn-play-pause");
    if (btn) btn.innerText = "⏸";
    const btnFs = document.getElementById("btn-fs-play-pause");
    if (btnFs) btnFs.innerText = "⏸";

    // 前の再生・タイマー・ノードを完全にクリーンアップ
    this.stopAllAudioAndTimers(false);

    const scenes = this.project && this.project.scenes ? this.project.scenes : [];
    const scene = scenes[this.currentSceneIndex];
    if (!scene) {
      this.isFetchingAudio = false;
      this.pause();
      return;
    }

    // シーンの開始時間と現在のタイムライン再生ヘッド位置から、シーン内経過秒数を算出
    const sceneStartTime = this.getSceneStartTime(this.currentSceneIndex);
    const sceneDur = this.getSceneDuration(scene);
    let offsetSec = Math.max(0.0, (this.playheadTime || 0.0) - sceneStartTime);
    if (offsetSec >= sceneDur - 0.05) {
      offsetSec = 0.0;
      this.playheadTime = sceneStartTime;
    }

    if (!deferPreviewUpdate) {
      // プレビュー画面のUI更新（画像/動画切り替え、オフセット秒数反映 - 音声準備完了まで動画は再生しない）
      this.updatePreviewForScene(scene, offsetSec, false);
    }

    const isNoVoice = (scene.no_voice === true || scene.is_skipped === true || scene.is_enabled === false);

    // ==========================================
    // 音声・動画・SE・タイマーの完全同期スタート用ヘルパー
    // ==========================================
    let isPlaybackLaunched = false;
    const launchSynchronizedPlayback = (actualAudioDur = null) => {
      if (isPlaybackLaunched) return;
      if (this._playSessionId !== sessionId || !this.isPlaying) return;
      isPlaybackLaunched = true;
      this.isFetchingAudio = false;

      if (deferPreviewUpdate) {
        this.playheadTime = sceneStartTime + Math.max(0.0, offsetSec || 0.0);
        this.updatePlayheadDisplay(true);
        this.updatePreviewForScene(scene, offsetSec, false);
        this.updateActiveSceneHighlight();
      }

      if (actualAudioDur !== null && actualAudioDur > 0) {
        scene.audio_duration = actualAudioDur;
      }

      const comp = this.getSceneMediaComparison(scene);
      const exactSceneDur = comp.sceneDuration;
      const audioDurVal = comp.audioDur;
      const isAnimInstructed = this.hasAnimationInstruction(scene.notes, scene.text);
      const hasExplicitAnimWait = Boolean(
        isNoVoice ||
        (isAnimInstructed && (
          comp.isVideoMode ||
          (scene.target_duration && parseFloat(scene.target_duration) > (audioDurVal + 0.1)) ||
          (scene.animation_duration && parseFloat(scene.animation_duration) > (audioDurVal + 0.1)) ||
          (scene.extra_delay && parseFloat(scene.extra_delay) > 0.05) ||
          scene.is_animation_sync
        ))
      );

      // 1. 基準時刻確定 (再生ヘッド・タイムライン追従用)
      this._scenePlayStartTime = performance.now() - (offsetSec * 1000);

      // 2. プレビュー動画の再生開始 (動画クリップが存在する場合)
      this.syncPreviewVideo(scene, offsetSec, true);

      // 3. 独立 BGM の再生制御
      if (this.project.timeline && this.project.timeline.bgm && this.project.timeline.bgm.audio_path) {
        const bgm = this.project.timeline.bgm;
        const bgmUrl = `/media/${encodeURIComponent(bgm.audio_path)}`;
        if (this.bgmElement.src !== window.location.origin + bgmUrl && this.bgmElement.src !== bgmUrl) {
          this.bgmElement.src = bgmUrl;
        }
        this.bgmElement.volume = Math.min(1.0, bgm.volume !== undefined ? bgm.volume : 0.25);
        this.bgmElement.playbackRate = bgm.speed || 1.0;
        this.bgmElement.loop = bgm.loop !== false;
        if (this.bgmElement.paused) {
          this.bgmElement.play().catch(() => {});
        }
      } else {
        try { this.bgmElement.pause(); } catch(e) {}
      }

      // 4. 独立 複数効果音 (SE) の完全同時オーバーレイ再生制御
      if (!this._activeSpanSeMap) {
        this._activeSpanSeMap = new Map();
      }
      if (!this._activeSceneSeNodes) {
        this._activeSceneSeNodes = [];
      }

      const resolveSceneIndex = (num) => {
        if (num === undefined || num === null) return 0;
        const targetNum = parseInt(num);
        let idx = scenes.findIndex(s => parseInt(s.slide_index) === targetNum);
        if (idx !== -1) return idx;
        if (targetNum >= 1 && targetNum <= scenes.length) return targetNum - 1;
        if (targetNum >= 0 && targetNum < scenes.length) return targetNum;
        return Math.max(0, Math.min(scenes.length - 1, targetNum - 1));
      };

      let activeSpanSes = [];
      if (this.project.timeline && this.project.timeline.sound_effects) {
        activeSpanSes = this.project.timeline.sound_effects.filter(se => {
          const st = resolveSceneIndex(se.start_scene_index);
          const ed = resolveSceneIndex(se.end_scene_index || se.start_scene_index);
          const minIdx = Math.min(st, ed);
          const maxIdx = Math.max(st, ed);
          return (this.currentSceneIndex >= minIdx && this.currentSceneIndex <= maxIdx);
        });
      }

      const activeSpanSeIds = new Set(activeSpanSes.map(se => se.id));
      for (const [id, handle] of this._activeSpanSeMap.entries()) {
        if (!activeSpanSeIds.has(id)) {
          try { handle.stop(); } catch(e) {}
          this._activeSpanSeMap.delete(id);
        }
      }

      for (const se of activeSpanSes) {
        const stIdx = resolveSceneIndex(se.start_scene_index);
        const isStartScene = (this.currentSceneIndex === stIdx);
        const seUrl = `/media/${encodeURIComponent(se.audio_path)}`;
        const seVol = Math.min(1.0, se.volume !== undefined ? se.volume : 1.0);
        const seSpd = se.speed || 1.0;
        const isRev = se.reverse === true;

        if (isStartScene || !this._activeSpanSeMap.has(se.id)) {
          if (this._activeSpanSeMap.has(se.id)) {
            try { this._activeSpanSeMap.get(se.id).stop(); } catch(e) {}
          }
          this.playCustomAudio(seUrl, {
            volume: seVol,
            playbackRate: seSpd,
            reverse: isRev,
            loop: se.loop === true
          }).then(handle => {
            if (this.isPlaying && this._playSessionId === sessionId) {
              this._activeSpanSeMap.set(se.id, handle);
            } else {
              try { handle.stop(); } catch(e) {}
            }
          }).catch(err => console.warn("[Preview] Multi-SE play error:", err));
        }
      }

      // シーン固有の個別効果音
      const sceneSeList = [];
      if (scene.sound_effects && Array.isArray(scene.sound_effects)) {
        scene.sound_effects.forEach(s => sceneSeList.push(s));
      } else if (scene.sound_effect) {
        sceneSeList.push({
          sound_effect: scene.sound_effect,
          se_offset: scene.se_offset || 0.0,
          volume: scene.se_volume !== undefined ? scene.se_volume : 1.0,
          speed: scene.se_speed !== undefined ? scene.se_speed : 1.0,
          se_reverse: scene.se_reverse === true
        });
      }

      sceneSeList.forEach(seItem => {
        const sePath = seItem.sound_effect || seItem.audio_path;
        if (!sePath) return;
        const seUrl = `/media/${encodeURIComponent(sePath)}`;
        const rawSeOff = Math.max(0.0, parseFloat(seItem.se_offset || 0.0));
        const seVol = Math.min(1.0, parseFloat(seItem.volume !== undefined ? seItem.volume : 1.0));
        const seSpd = parseFloat(seItem.speed !== undefined ? seItem.speed : 1.0);
        const isRev = seItem.se_reverse === true;

        const delaySec = Math.max(0.0, rawSeOff - offsetSec);
        if (rawSeOff >= offsetSec || offsetSec < 0.5) {
          const timer = setTimeout(() => {
            if (!this.isPlaying || this._playSessionId !== sessionId) return;
            this.playCustomAudio(seUrl, {
              volume: seVol,
              playbackRate: seSpd,
              reverse: isRev,
              loop: false
            }).then(handle => {
              if (this.isPlaying && this._playSessionId === sessionId) {
                this._activeSceneSeNodes.push({ handle });
              } else {
                try { handle.stop(); } catch(e) {}
              }
            }).catch(err => console.warn("[Preview] Scene-SE play error:", err));
          }, delaySec * 1000);

          this._activeSceneSeNodes.push({ timer });
        }
      });

      // 5. シーン終了/次シーン遷移タイマー
      // セリフスライド（hasExplicitAnimWait === false）は音声 onended での遷移を基本とし、
      // ここでのタイマーは万一 onended が不発だった場合のセーフティガード（+0.3秒マージン）
      // アニメーション待機等がある場合は指定時間満了で遷移
      const remainingSceneTime = Math.max(0.1, exactSceneDur - offsetSec);
      const safetyDelay = hasExplicitAnimWait ? remainingSceneTime : (remainingSceneTime + 0.3);
      if (this._sceneTransitionTimer) clearTimeout(this._sceneTransitionTimer);
      this._sceneTransitionTimer = setTimeout(() => {
        if (this.isPlaying && this._playSessionId === sessionId) {
          this.jumpNextScene(true);
        }
      }, safetyDelay * 1000);
    };

    // 音声終了ハンドラー (音声終了 -> 次シーン遷移または追加待機)
    const handleVoiceEnded = () => {
      if (this._playSessionId !== sessionId || !this.isPlaying) return;
      const comp = this.getSceneMediaComparison(scene);
      const audioDurVal = comp.audioDur;
      const isAnimInstructed = this.hasAnimationInstruction(scene.notes, scene.text);
      const hasExplicitAnimWait = Boolean(
        isNoVoice ||
        (isAnimInstructed && (
          comp.isVideoMode ||
          (scene.target_duration && parseFloat(scene.target_duration) > (audioDurVal + 0.1)) ||
          (scene.animation_duration && parseFloat(scene.animation_duration) > (audioDurVal + 0.1)) ||
          (scene.extra_delay && parseFloat(scene.extra_delay) > 0.05) ||
          scene.is_animation_sync
        ))
      );

      if (!hasExplicitAnimWait) {
        // 余白ゼロで即座に次シーンへ切り替え
        this.jumpNextScene(true);
      } else {
        // スライド動画（アニメーション）または追加待機時間がある場合は、残り時間待機
        const exactSceneDur = comp.sceneDuration;
        const elapsed = this._scenePlayStartTime ? ((performance.now() - this._scenePlayStartTime) / 1000.0) : audioDurVal;
        const remainingAnimTime = Math.max(0.0, exactSceneDur - elapsed);
        if (remainingAnimTime > 0.05) {
          if (this._sceneTransitionTimer) clearTimeout(this._sceneTransitionTimer);
          this._sceneTransitionTimer = setTimeout(() => {
            if (this.isPlaying && this._playSessionId === sessionId) {
              this.jumpNextScene(true);
            }
          }, remainingAnimTime * 1000);
        } else {
          this.jumpNextScene(true);
        }
      }
    };

    // 音声不要スライドまたはセリフが空の場合は音声再生をスキップして即座に画面・タイマーを開始
    if (isNoVoice || (!scene.audio_path && !scene.text && !scene.phonemes)) {
      launchSynchronizedPlayback();
      return;
    }

    // 1. すでに音声ファイルが存在する場合 (Web Audio API によるゼロレイテンシ即時発声)
    if (scene.audio_path) {
      let audioUrl = `/media/${encodeURIComponent(scene.audio_path)}`;
      if (scene._cacheBuster) {
        audioUrl += `?t=${scene._cacheBuster}`;
      }
      const ctx = this.getAudioContext();

      // 先読み（後続シーンの音声キャッシュ）をバックグラウンド実行
      this.preloadSceneAudio(this.currentSceneIndex + 1, 4);

      try {
        const buffer = await this.getAudioBuffer(audioUrl);
        if (this._playSessionId !== sessionId || !this.isPlaying) return;

        if (buffer) {
          const source = ctx.createBufferSource();
          source.buffer = buffer;
          source.connect(ctx.destination);
          if (!this._activeAudioSourceNodes) this._activeAudioSourceNodes = [];
          this._activeAudioSourceNodes.push(source);
          source.onended = () => {
            const idx = this._activeAudioSourceNodes.indexOf(source);
            if (idx !== -1) this._activeAudioSourceNodes.splice(idx, 1);
            handleVoiceEnded();
          };
          source.start(0, Math.max(0, offsetSec));
          launchSynchronizedPlayback(buffer.duration);
          return;
        }
      } catch (bufErr) {
        console.warn("[Preview] Web Audio buffer play failed, fallback to Audio element:", bufErr);
      }

      if (this._playSessionId !== sessionId || !this.isPlaying) return;

      // フォールバック再生
      try {
        this.audioElement.src = audioUrl;
        this.audioElement.volume = 1.0;
        this.audioElement.onended = () => {
          handleVoiceEnded();
        };
        if (offsetSec > 0) {
          try {
            this.audioElement.currentTime = offsetSec;
          } catch(e) {}
        }
        await this.audioElement.play();
        launchSynchronizedPlayback(this.audioElement.duration || scene.audio_duration);
        return;
      } catch (audioErr) {
        if (this._playSessionId !== sessionId || !this.isPlaying) return;
        console.warn("[Preview] Direct Audio element play failed, trying fallback:", audioErr);
        try {
          await this.playAudioSafely(audioUrl, () => {
            handleVoiceEnded();
          });
          launchSynchronizedPlayback(scene.audio_duration);
          return;
        } catch (e) {
          console.error("[Preview] Fallback play failed:", e);
          launchSynchronizedPlayback();
        }
      }
    }

    // 2. 音声ファイルが未生成の場合、リアルタイムにプレビュー音声を合成して再生
    const text = (scene.text || "").trim();
    const phonemes = (scene.phonemes || "").trim();
    const voice = scene.voice || "f1";
    const speed = parseInt(scene.speed || 100);
    const pitch = parseInt(scene.pitch || 100);
    const effect = scene.effect || "none";
    const quality_enhance = scene.quality_enhance !== false;
    const sound_effect = scene.sound_effect || null;
    const se_offset = parseFloat(scene.se_offset || 0.0) || 0.0;

    try {
      this._currentTtsAbortController = new AbortController();
      const res = await fetch("/api/tts/preview", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        signal: this._currentTtsAbortController.signal,
        body: JSON.stringify({
          text: text,
          phonemes: phonemes,
          voice: voice,
          speed: speed,
          pitch: pitch,
          effect: effect,
          quality_enhance: quality_enhance,
          sound_effect: sound_effect,
          se_offset: se_offset
        })
      });
      const data = await res.json();

      // 世代チェック: リクエスト中にユーザーがシークや一時停止、別シーン選択を行った場合は再生しない
      if (this._playSessionId !== sessionId || !this.isPlaying) return;

      if (data.success && (data.audio_data_url || data.preview_url)) {
        const audioSrc = data.audio_data_url || data.preview_url;
        const dur = data.duration || null;
        if (dur) {
          scene.audio_duration = dur;
        }
        await this.playAudioSafely(audioSrc, () => {
          handleVoiceEnded();
        });
        launchSynchronizedPlayback(dur);
      } else {
        launchSynchronizedPlayback();
      }
    } catch (e) {
      if (e && e.name === "AbortError") return;
      if (this._playSessionId !== sessionId || !this.isPlaying) return;
      console.error("[Preview] Real-time TTS synthesis failed:", e);
      launchSynchronizedPlayback();
    }
  },

  // ==========================================
  // 逆再生・エフェクト対応 オーディオ再生ヘルパー
  // ==========================================
  async playCustomAudio(audioUrl, { volume = 1.0, playbackRate = 1.0, reverse = false, loop = false } = {}) {
    if (!reverse && !loop && playbackRate === 1.0) {
      const aud = new Audio(audioUrl);
      aud.volume = Math.min(1.0, Math.max(0.0, volume));
      aud.playbackRate = playbackRate;
      aud.loop = loop;
      await aud.play();
      return { stop: () => aud.pause(), audio: aud };
    }

    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (!this._audioCtx || this._audioCtx.state === "closed") {
        this._audioCtx = new AudioContextClass();
      }
      if (this._audioCtx.state === "suspended") {
        await this._audioCtx.resume();
      }

      const res = await fetch(audioUrl);
      const arrayBuf = await res.arrayBuffer();
      const audioBuf = await this._audioCtx.decodeAudioData(arrayBuf);

      let playBuf = audioBuf;
      if (reverse) {
        // 反転バッファの生成
        playBuf = this._audioCtx.createBuffer(audioBuf.numberOfChannels, audioBuf.length, audioBuf.sampleRate);
        for (let c = 0; c < audioBuf.numberOfChannels; c++) {
          const srcData = audioBuf.getChannelData(c);
          const dstData = playBuf.getChannelData(c);
          for (let i = 0; i < srcData.length; i++) {
            dstData[i] = srcData[srcData.length - 1 - i];
          }
        }
      }

      const source = this._audioCtx.createBufferSource();
      source.buffer = playBuf;
      source.playbackRate.value = playbackRate;
      source.loop = loop;

      const gainNode = this._audioCtx.createGain();
      gainNode.gain.value = Math.min(2.0, Math.max(0.0, volume));

      source.connect(gainNode);
      gainNode.connect(this._audioCtx.destination);

      source.start(0);
      return { stop: () => { try { source.stop(); } catch(e){} }, sourceNode: source };
    } catch (e) {
      console.warn("[App] playCustomAudio fallback:", e);
      const aud = new Audio(audioUrl);
      aud.volume = Math.min(1.0, Math.max(0.0, volume));
      aud.playbackRate = playbackRate;
      aud.loop = loop;
      await aud.play();
      return { stop: () => aud.pause(), audio: aud };
    }
  },

  pause() {
    this.isPlaying = false;
    this.isFetchingAudio = false;
    this.stopAllAudioAndTimers(true);

    const btn = document.getElementById("btn-play-pause");
    if (btn) btn.innerText = "▶";
    const btnFs = document.getElementById("btn-fs-play-pause");
    if (btnFs) btnFs.innerText = "▶";
  },

  jumpPrevScene() {
    this.stopAllAudioAndTimers(true);
    if (this.currentSceneIndex > 0) {
      this.selectScene(this.currentSceneIndex - 1, true, 0.0);
    }
  },

  jumpNextScene(auto = false) {
    this.stopAllAudioAndTimers(!this.isPlaying);
    const scenes = (this.project && this.project.scenes) || [];
    let nextIdx = this.currentSceneIndex + 1;

    if (nextIdx < scenes.length) {
      this.selectScene(nextIdx, true, 0.0, auto);
    } else {
      if (this.isLoop) {
        this.selectScene(0, true, 0.0, auto);
      } else {
        this.pause();
      }
    }
  },

  toggleLoop() {
    this.isLoop = !this.isLoop;
    const btn = document.getElementById("btn-loop");
    if (btn) {
      if (this.isLoop) {
        btn.classList.add("active");
        btn.style.color = "#3498db";
      } else {
        btn.classList.remove("active");
        btn.style.color = "";
      }
    }
  },

  // ==========================================
  // 再生ヘッド・シークバー・再生時間のアニメーション連動
  // ==========================================
  startPlayheadTimer() {
    if (this._playheadInterval) clearInterval(this._playheadInterval);
    if (this._playheadRaf) cancelAnimationFrame(this._playheadRaf);

    const loop = () => {
      this.updatePlayheadLoop();
      this._playheadRaf = requestAnimationFrame(loop);
    };
    this._playheadRaf = requestAnimationFrame(loop);

    // バックグラウンド・低負荷環境用フォールバック (~60fps / 16ms)
    this._playheadInterval = setInterval(() => {
      this.updatePlayheadLoop();
    }, 16);
  },

  updatePlayheadLoop() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;
    if (this.isFetchingAudio) return;

    if (this.isPlaying) {
      const scene = this.project.scenes[this.currentSceneIndex];
      const sceneStartTime = this.getSceneStartTime(this.currentSceneIndex);
      const sceneDur = this.getSceneDuration(scene);
      let curSceneProgress = 0.0;

      if (this._scenePlayStartTime) {
        curSceneProgress = (performance.now() - this._scenePlayStartTime) / 1000.0;
      } else if (this.audioElement && !this.audioElement.paused && this.audioElement.duration) {
        curSceneProgress = this.audioElement.currentTime;
      } else {
        curSceneProgress = Math.max(0.0, (this.playheadTime || 0.0) - sceneStartTime);
      }

      curSceneProgress = Math.max(0.0, Math.min(sceneDur, curSceneProgress));
      this.playheadTime = Math.min(this.totalDuration, sceneStartTime + curSceneProgress);
      this.updatePlayheadDisplay(true);

      // プレビュー画面で動画再生中にタイムライン再生位置を極めて厳密に監視・0秒同期（音声が実際に鳴り始めてから）
      const video = this.getActiveMediaElements().video;
      if (this._scenePlayStartTime && video && video.style.display !== "none" && video.readyState >= 1) {
        const expectedVideoTime = this.getVideoTargetTime(scene, curSceneProgress);
        const maxDur = (!isNaN(video.duration) && video.duration > 0) ? video.duration : Infinity;
        const targetVideoTime = Math.min(maxDur, Math.max(0.0, expectedVideoTime));

        // タイムライン位置とプレビュー動画位置の差分（秒）
        const diff = video.currentTime - targetVideoTime;
        const absDiff = Math.abs(diff);

        // 1. 微小ズレの動的マイクロ再生速度制御 (0.03s〜0.15sの段階で常にゼロ誤差へ収束)
        if (absDiff > 0.03 && absDiff <= 0.15) {
          if (diff < 0) {
            // 動画が少し遅れている場合は微小加速して0秒差へ追従
            video.playbackRate = 1.05;
          } else {
            // 動画が少し先行している場合は微小減速して0秒差へ追従
            video.playbackRate = 0.95;
          }
        } else if (absDiff <= 0.03) {
          if (video.playbackRate !== 1.0) {
            video.playbackRate = 1.0;
          }
        }

        // 2. 厳密なゼロ秒強制修正 (0.15秒以上のズレを即時強制同期)
        const STRICT_THRESHOLD = 0.15; // 150ミリ秒以上の差は強制シーク
        const now = performance.now();
        const lastSyncTime = video._lastSyncTime || 0;

        if (absDiff > STRICT_THRESHOLD) {
          // 直近シークから少し経過またはズレが大きい場合は即座に強制セット
          if (!video.seeking || (now - lastSyncTime > 100) || absDiff > 0.2) {
            video._lastSyncTime = now;
            try {
              video.currentTime = targetVideoTime;
            } catch(e) {}
          }
        }

        // 3. 再生中なのに動画が一時停止していたら即座に再開（音声開始後のみ）
        if (video.paused && this.isPlaying && this._scenePlayStartTime) {
          video.play().catch(() => {});
        }
      }
    }
  },

  updatePlayheadDisplay(autoScroll = false) {
    if (!this.project || this.totalDuration <= 0) return;

    const formattedCur = this.formatTime(this.playheadTime);
    const formattedTotal = this.formatTime(this.totalDuration);
    const timeStr = `${formattedCur} / ${formattedTotal}`;

    // 1. 時間表示 (通常 & 全画面)
    const timeDisp = document.getElementById("preview-time-display");
    if (timeDisp) timeDisp.innerText = timeStr;

    const fsTimeDisp = document.getElementById("fs-time-display");
    if (fsTimeDisp) fsTimeDisp.innerText = timeStr;

    // 2. シークバー (通常 & 全画面)
    const pct = (this.playheadTime / this.totalDuration) * 100;

    const seekbar = document.getElementById("preview-seekbar");
    if (seekbar && !seekbar._isDragging) {
      seekbar.value = pct;
    }

    const fsSeekbar = document.getElementById("fs-seekbar");
    if (fsSeekbar && !fsSeekbar._isDragging) {
      fsSeekbar.value = pct;
    }

    // 3. 再生ボタン表示同期 (通常 & 全画面)
    const playIcon = this.isPlaying ? "⏸" : "▶";
    const btnPlay = document.getElementById("btn-play-pause");
    if (btnPlay) btnPlay.innerText = playIcon;

    const btnFsPlay = document.getElementById("btn-fs-play-pause");
    if (btnFsPlay) btnFsPlay.innerText = playIcon;

    // 4. タイムライン再生ヘッド (Playhead 縦線: 物理DOMに完全追従)
    const playhead = document.getElementById("timeline-playhead");
    const scrollArea = document.getElementById("timeline-scroll-area");
    const trackVideo = document.getElementById("track-video-clips");

    if (playhead && this.sceneOffsetsCache && this.sceneOffsetsCache.length > 0) {
      playhead.style.display = "block";

      const vClips = trackVideo ? trackVideo.children : null;
      let accTime = 0.0;
      let targetLeftPx = 124;

      for (let i = 0; i < this.project.scenes.length; i++) {
        const offsetInfo = this.sceneOffsetsCache[i];
        const dur = offsetInfo ? offsetInfo.duration : 1.0;
        const vEl = (vClips && vClips[i]) ? vClips[i] : null;

        if (this.playheadTime >= accTime && this.playheadTime <= (accTime + dur + 0.001)) {
          const ratio = Math.max(0, Math.min(1.0, (this.playheadTime - accTime) / dur));
          if (vEl) {
            targetLeftPx = 120 + vEl.offsetLeft + (vEl.offsetWidth * ratio);
          } else if (offsetInfo) {
            targetLeftPx = 120 + offsetInfo.leftPx + (offsetInfo.widthPx * ratio);
          }
          break;
        }
        accTime += dur;
      }

      playhead.style.left = `${targetLeftPx}px`;

      // 自動スクロール
      if (autoScroll && scrollArea) {
        const viewLeft = scrollArea.scrollLeft;
        const viewWidth = scrollArea.clientWidth;
        if (targetLeftPx > viewLeft + viewWidth - 100 || targetLeftPx < viewLeft + 120) {
          scrollArea.scrollLeft = Math.max(0, targetLeftPx - 200);
        }
      }
    }
  },

  onSeekbarInput(val) {
    const seekbar = document.getElementById("preview-seekbar");
    const fsSeekbar = document.getElementById("fs-seekbar");
    if (seekbar) seekbar._isDragging = true;
    if (fsSeekbar) fsSeekbar._isDragging = true;

    // シーク中は前音声を即座に停止
    this.stopAllAudioAndTimers(true);

    const targetSec = (parseFloat(val) / 100.0) * this.totalDuration;
    this.playheadTime = targetSec;
    this.updatePlayheadDisplay(true);

    // シーク位置のシーンを特定してプレビュー表示を同期 (シーン内オフセット秒数つき)
    const foundIdx = this.getCurrentPlayheadSceneIndex();
    const sceneStartTime = this.getSceneStartTime(foundIdx);
    const offsetInScene = Math.max(0.0, targetSec - sceneStartTime);
    this.selectScene(foundIdx, false, offsetInScene);
  },

  onSeekbarChange(val) {
    const seekbar = document.getElementById("preview-seekbar");
    const fsSeekbar = document.getElementById("fs-seekbar");
    if (seekbar) seekbar._isDragging = false;
    if (fsSeekbar) fsSeekbar._isDragging = false;

    const targetSec = (parseFloat(val) / 100.0) * this.totalDuration;
    this.playheadTime = targetSec;

    const foundIdx = this.getCurrentPlayheadSceneIndex();
    const sceneStartTime = this.getSceneStartTime(foundIdx);
    const offsetInScene = Math.max(0.0, targetSec - sceneStartTime);
    this.selectScene(foundIdx, false, offsetInScene);
    this.updatePlayheadDisplay(true);

    if (this.isPlaying) {
      this.play();
    }
  },

  // ==========================================
  // 全画面プレビュー (Fullscreen Preview)
  // ==========================================
  _fsHideTimer: null,

  isFullscreen() {
    return Boolean(
      document.fullscreenElement ||
      document.webkitFullscreenElement ||
      document.mozFullScreenElement ||
      document.msFullscreenElement
    );
  },

  toggleFullscreenPreview() {
    const container = document.getElementById("preview-stage-container") || document.getElementById("preview-screen");
    if (!container) return;

    if (!this.isFullscreen()) {
      if (container.requestFullscreen) {
        container.requestFullscreen().catch(e => console.warn("Fullscreen request error:", e));
      } else if (container.webkitRequestFullscreen) {
        container.webkitRequestFullscreen();
      } else if (container.mozRequestFullScreen) {
        container.mozRequestFullScreen();
      } else if (container.msRequestFullscreen) {
        container.msRequestFullscreen();
      }
    } else {
      if (document.exitFullscreen) {
        document.exitFullscreen().catch(e => console.warn("Fullscreen exit error:", e));
      } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen();
      } else if (document.mozCancelFullScreen) {
        document.mozCancelFullScreen();
      } else if (document.msExitFullscreen) {
        document.msExitFullscreen();
      }
    }
  },

  setupFullscreenListeners() {
    const onFullscreenChange = () => {
      const isFs = this.isFullscreen();
      const fsControls = document.getElementById("fullscreen-controls");
      const btnFs = document.getElementById("btn-fullscreen");

      if (btnFs) {
        btnFs.innerHTML = isFs ? "✕ 全画面解除" : "⛶ 全画面";
        btnFs.title = isFs ? "全画面プレビューを解除 (Esc / F)" : "全画面プレビュー (F)";
      }

      if (isFs) {
        if (fsControls) {
          fsControls.classList.remove("fade-out");
        }
        this.resetFullscreenHideTimer();
      } else {
        if (this._fsHideTimer) {
          clearTimeout(this._fsHideTimer);
          this._fsHideTimer = null;
        }
        if (fsControls) {
          fsControls.classList.remove("fade-out");
        }
      }
    };

    document.addEventListener("fullscreenchange", onFullscreenChange);
    document.addEventListener("webkitfullscreenchange", onFullscreenChange);
    document.addEventListener("mozfullscreenchange", onFullscreenChange);
    document.addEventListener("MSFullscreenChange", onFullscreenChange);

    // 全画面中のマウス移動検知でコントロールバーをフェード表示/自動非表示
    const stageContainer = document.getElementById("preview-stage-container") || document.getElementById("preview-screen");
    if (stageContainer) {
      stageContainer.addEventListener("mousemove", () => {
        if (this.isFullscreen()) {
          const fsControls = document.getElementById("fullscreen-controls");
          if (fsControls) fsControls.classList.remove("fade-out");
          this.resetFullscreenHideTimer();
        }
      });
    }
  },

  resetFullscreenHideTimer() {
    if (this._fsHideTimer) {
      clearTimeout(this._fsHideTimer);
    }
    this._fsHideTimer = setTimeout(() => {
      if (this.isFullscreen()) {
        const fsControls = document.getElementById("fullscreen-controls");
        if (fsControls && !fsControls.matches(":hover")) {
          fsControls.classList.add("fade-out");
        }
      }
    }, 2500);
  },

  // ==========================================
  // マーカー機能 (In点 / Out点 / 連続SE)
  // ==========================================
  setMarkerIn() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;
    const slideIdx = scene.slide_index || (this.currentSceneIndex + 1);
    this.markerIn = slideIdx;
    if (this.markerOut && this.markerOut < this.markerIn) {
      this.markerOut = this.markerIn;
    }
    this.renderMarkerRange();
    alert(`📍 Scene ${slideIdx} を【In点 (開始)】としてマークしました！`);
  },

  setMarkerOut() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;
    const slideIdx = scene.slide_index || (this.currentSceneIndex + 1);
    this.markerOut = slideIdx;
    if (!this.markerIn || this.markerIn > this.markerOut) {
      this.markerIn = Math.max(1, this.markerOut - 1);
    }
    this.renderMarkerRange();
    alert(`📍 Scene ${slideIdx} を【Out点 (終了)】としてマークしました！`);
  },

  clearMarkers() {
    this.markerIn = null;
    this.markerOut = null;
    this.renderMarkerRange();
  },

  renderMarkerRange() {
    const rangeElem = document.getElementById("timeline-marker-range");
    if (!rangeElem) return;

    if (this.markerIn === null || this.markerOut === null || !this.sceneOffsetsCache || this.sceneOffsetsCache.length === 0) {
      rangeElem.style.display = "none";
      return;
    }

    const scenes = this.project.scenes || [];
    let stIdx = scenes.findIndex(s => s.slide_index === this.markerIn);
    if (stIdx === -1) stIdx = Math.max(0, Math.min(scenes.length - 1, this.markerIn - 1));

    let endIdx = scenes.findIndex(s => s.slide_index === this.markerOut);
    if (endIdx === -1) endIdx = Math.max(stIdx, Math.min(scenes.length - 1, this.markerOut - 1));

    const stOffset = this.sceneOffsetsCache[stIdx];
    const endOffset = this.sceneOffsetsCache[endIdx];

    if (stOffset && endOffset) {
      const leftPx = 120 + stOffset.leftPx;
      const widthPx = Math.max(20, (endOffset.leftPx + endOffset.widthPx) - stOffset.leftPx);

      rangeElem.style.display = "block";
      rangeElem.style.left = `${leftPx}px`;
      rangeElem.style.width = `${widthPx}px`;
    }
  },

  openAddSpanSeFromMarkers() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) {
      alert("先にプロジェクトを読み込んでください。");
      return;
    }
    this.openAddSpanSeModal();

    if (this.markerIn !== null) {
      document.getElementById("span-se-start-scene").value = this.markerIn;
    }
    if (this.markerOut !== null) {
      document.getElementById("span-se-end-scene").value = this.markerOut;
    }
  },

  onTimelineZoom(val) {
    this.timelineZoom = val / 100.0;
    this.renderTimeline();
  },

  // ==========================================
  // プロジェクト保存・バックアップ
  // ==========================================
  async saveCurrentProject() {
    if (!this.project) return;
    try {
      const res = await fetch("/api/project/save", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ project: this.project })
      });
      const data = await res.json();
      if (data.success) {
        alert("プロジェクトを安全に保存しました！\n" + data.path);
      } else {
        alert("保存エラー: " + data.error);
      }
    } catch (e) {
      alert("保存通信エラー: " + e);
    }
  },

  async saveProjectSilently() {
    if (!this.project) return;
    try {
      await fetch("/api/project/save", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ project: this.project })
      });
    } catch (e) {
      console.warn("[App] Silent project save failed:", e);
    }
  },



  async openCrashReportsModal() {
    try {
      const res = await fetch("/api/crash_reports");
      const data = await res.json();
      if (data.success) {
        if (data.reports.length === 0) {
          alert("クラッシュレポートはありません。正常に稼働しています。");
        } else {
          let msg = "最新のクラッシュレポート一覧:\n\n";
          data.reports.slice(0, 3).forEach(r => {
            msg += `• [${r.created_at}] ${r.title}\n  ファイル: ${r.filename}\n\n`;
          });
          alert(msg);
        }
      }
    } catch (e) {
      alert("クラッシュレポート取得エラー: " + e);
    }
  },

  // ==========================================
  // ライセンス認証 (要件18)
  // ==========================================
  openLicenseModal() {
    const lic = (this.project && this.project.license_info) || (this.config && this.config.license_info) || {};
    const usrId = lic.usr_license_id || lic.user_license_id || lic.license_id || "";
    const devId = lic.dev_license_id || lic.license_id || "";
    const usrKey = lic.user_key || lic.usr_key || "";
    const devKey = lic.dev_key || "";

    const userInp = document.getElementById("lic-input-user-id");
    const devInp = document.getElementById("lic-input-dev-id");
    const userKeyInp = document.getElementById("lic-input-user-key");
    const devKeyInp = document.getElementById("lic-input-dev-key");

    if (userInp) userInp.value = usrId;
    if (devInp) devInp.value = devId;
    if (userKeyInp) userKeyInp.value = usrKey;
    if (devKeyInp) devKeyInp.value = devKey;

    document.getElementById("modal-license").classList.add("active");
  },

  closeLicenseModal() {
    document.getElementById("modal-license").classList.remove("active");
  },

  async saveLicenseKeys() {
    const usrId = (document.getElementById("lic-input-user-id") || {}).value || "";
    const usrKey = (document.getElementById("lic-input-user-key") || {}).value || "";
    const devId = (document.getElementById("lic-input-dev-id") || {}).value || "";
    const devKey = (document.getElementById("lic-input-dev-key") || {}).value || "";

    try {
      const res = await fetch("/api/tts/license", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          usr_license_id: usrId,
          user_key: usrKey,
          dev_license_id: devId,
          dev_key: devKey
        })
      });
      const data = await res.json();
      if (data.success) {
        alert("使用ライセンス・開発ライセンスの認証情報を保存しました！");
        this.closeLicenseModal();
      }
    } catch (e) {
      alert("ライセンス保存エラー: " + e);
    }
  },

  // ==========================================
  // 書き出し & ステータス (要件4, 13, 16)
  // ==========================================
  openExportDialog() {
    document.getElementById("modal-export").classList.add("active");
  },

  closeExportDialog() {
    document.getElementById("modal-export").classList.remove("active");
  },

  async startExport(format) {
    this.closeExportDialog();

    if (format === "fcpxml") {
      try {
        const res = await fetch("/api/export/fcpxml", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            project_name: this.project.project_name || "untitled",
            scenes: this.project.scenes
          })
        });
        const data = await res.json();
        if (data.success) {
          alert("Final Cut Pro (FCPXML) の書き出しが完了しました！\n" + data.output_path);
        } else {
          alert("FCPXML書き出しエラー: " + data.error);
        }
      } catch (e) {
        alert("FCPXML通信エラー: " + e);
      }
      return;
    }

    // 動画書き出し (MP4 / MOV)
    try {
      const res = await fetch("/api/export/video", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          project_name: this.project.project_name || "untitled",
          format: format,
          scenes: this.project.scenes,
          timeline: this.project.timeline || {},
          video_source: this.project.video_source || null,
          padding_delay: (this.project.settings && this.project.settings.padding_delay) || 0.5
        })
      });
      const data = await res.json();
      if (data.success) {
        this.openExportStatusModal();
      } else {
        alert("書き出し開始エラー: " + data.error);
      }
    } catch (e) {
      alert("書き出し通信エラー: " + e);
    }
  },

  openExportStatusModal() {
    document.getElementById("modal-export-status").classList.add("active");
    this.pollExportStatus();
  },

  closeExportStatusModal() {
    document.getElementById("modal-export-status").classList.remove("active");
  },

  async pollExportStatus() {
    try {
      const res = await fetch("/api/export/status");
      const data = await res.json();
      if (data.success && data.status) {
        const st = data.status;
        document.getElementById("exp-status-stage").innerText = st.current_stage || "処理中...";
        document.getElementById("exp-status-bar").style.width = `${st.progress_percent || 0}%`;
        document.getElementById("exp-status-percent").innerText = `進捗: ${st.progress_percent || 0}%`;
        document.getElementById("exp-status-time").innerText = `残り時間: ${st.estimated_remain_sec || 0}秒`;

        const resBox = document.getElementById("exp-status-result");
        if (st.progress_percent >= 100) {
          resBox.style.display = "block";
          resBox.innerHTML = `✅ 書き出し完了！<br>出力先: <b>${st.output_file}</b>`;
        } else if (st.error) {
          resBox.style.display = "block";
          resBox.innerHTML = `❌ エラー: ${st.error}`;
        } else if (st.is_exporting) {
          setTimeout(() => this.pollExportStatus(), 1000);
        }
      }
    } catch (e) {
      console.warn("Export poll failed:", e);
    }
  },

  openYouTubeExportModal() {
    const token = prompt("YouTube Data API のアクセストークンを入力してください (未入力時は案内を表示):", "");
    const title = prompt("動画のタイトル:", this.project.project_name || "東方Project二次創作動画");
    if (!title) return;

    fetch("/api/export/youtube", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        video_path: `${this.project.series_name || "交換夫婦"}/完成動画/${this.project.project_name}_完成版.mp4`,
        title: title,
        auth_token: token
      })
    })
    .then(res => res.json())
    .then(data => {
      if (data.success) {
        alert(data.message);
      } else {
        alert("YouTube投稿エラー: " + data.error + (data.guide ? "\n\n" + data.guide : ""));
      }
    });
  },

  // ==========================================
  // ドキュメント & ヘルプ
  // ==========================================
  showHelpDoc(topic) {
    const modal = document.getElementById("modal-help-doc");
    const title = document.getElementById("help-modal-title");
    const content = document.getElementById("help-modal-content");

    const docs = {
      time: {
        title: "読み込みに想定よりも時間がかかる場合",
        body: `
          <h4>スライド枚数が多い場合の処理</h4>
          <p>KeynoteやPowerPoint内に大量のスライドや高解像度画像が含まれる場合、AppleScriptおよび画像抽出に数秒〜数十秒かかる場合があります。</p>
          <h4>対処法</h4>
          <ul>
            <li>不要な非表示スライドを削除してから読み込んでください。</li>
            <li>「読み込み終了時に、通知する」にチェックを入れてバックグラウンドでお待ちいただけます。</li>
          </ul>
        `
      },
      error: {
        title: "読み込みの際にエラーが出力された場合",
        body: `
          <h4>考えられる原因</h4>
          <p>Keynoteファイルが破損しているか、ファイルアクセス権限が制限されている可能性があります。</p>
          <h4>対処法</h4>
          <ul>
            <li>ファイルをKeynoteで一度開いて保存し直してください。</li>
            <li>外部SSDの接続状態を確認してください（自動バックアップから復元することも可能です）。</li>
          </ul>
        `
      },
      corrupt: {
        title: "データが正常に読み込まれない場合",
        body: `
          <h4>テロップ枠の認識について</h4>
          <p>本ソフトはスライド下部のテロップ枠（幅1700〜2100、高さ150〜300）から優先的にセリフを抽出します。</p>
          <h4>対処法</h4>
          <ul>
            <li>編集画面のインスペクタまたはポップアップ校正で直接セリフを修正できます。</li>
            <li>自動判定されたキャラクターやボイスはいつでも変更可能です。</li>
          </ul>
        `
      },
      manual: {
        title: "東方Projectムービーメーカー 操作マニュアル",
        body: `
          <h4>基本フロー</h4>
          <ol>
            <li><b>新規作成または開く:</b> Keynote, PPTX, YMM4 または既存プロジェクトを開きます。</li>
            <li><b>自動抽出:</b> スライド画像とテロップ文が自動抽出され、シーンとしてタイムラインに並びます。</li>
            <li><b>詳細校正:</b> 右側インスペクタまたは「ポップアップ校正」でセリフ・音声記号列・ボイスを確認・再生成します。</li>
            <li><b>プレビュー & 書き出し:</b> 中央で再生確認し、MP4 / MOV / Final Cut Pro 形式で書き出します。</li>
          </ol>
        `
      }
    };

    const doc = docs[topic] || docs.manual;
    title.innerText = doc.title;
    content.innerHTML = doc.body;
    modal.classList.add("active");
  },

  closeHelpModal() {
    document.getElementById("modal-help-doc").classList.remove("active");
  },

  switchLeftTab(tabId) {
    document.querySelectorAll(".pane-left .tab-btn").forEach(b => b.classList.remove("active"));
    document.querySelectorAll(".pane-left .tab-pane").forEach(p => p.classList.remove("active"));

    const btn = event.target;
    btn.classList.add("active");
    const target = document.getElementById(`tab-content-${tabId}`);
    if (target) target.classList.add("active");

    if (tabId === "browser") {
      this.browseDirectory(this.currentDirectory);
    }
  },

  // ==========================================
  // ユーティリティ & シーン追加・削除 (ズレ完全防止)
  // ==========================================
  addNewBlankScene(autoSelect = true) {
    if (!this.project) return;
    this.pushUndoState();
    if (!this.project.scenes) this.project.scenes = [];

    const insertIdx = (this.currentSceneIndex >= 0 && this.currentSceneIndex < this.project.scenes.length)
      ? this.currentSceneIndex + 1
      : this.project.scenes.length;

    const newScene = {
      slide_index: insertIdx + 1,
      text: "新しいセリフ",
      phonemes: "アタラシイセリフ",
      character: "操夢",
      voice: "imd1",
      speed: 100,
      pitch: 115,
      audio_duration: 1.5,
      extra_delay: 0.0,
      image_path: null,
      audio_path: null,
      is_enabled: true
    };

    this.project.scenes.splice(insertIdx, 0, newScene);
    // スライド番号を 1 から連番で再付番
    this.project.scenes.forEach((s, i) => s.slide_index = i + 1);

    this.selectedSceneIndices.clear();
    this.renderScenesList();
    this.renderTimeline();
    if (autoSelect) this.selectScene(insertIdx);
  },

  deleteSelectedScene() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;
    const targetIdx = this.currentSceneIndex;
    const s = this.project.scenes[targetIdx];
    const sIdx = s ? (s.slide_index || targetIdx + 1) : targetIdx + 1;

    if (!confirm(`【確認】Scene ${sIdx} をタイムラインから丸ごと削除しますか？\n（※ 画像のみを削除したい場合は「画像削除(繰上げ)」ボタンをご利用ください）`)) return;

    this.pushUndoState();
    this.project.scenes.splice(targetIdx, 1);
    // スライド番号を 1 から連番で再付番
    this.project.scenes.forEach((sc, i) => sc.slide_index = i + 1);

    this.selectedSceneIndices.clear();

    if (this.currentSceneIndex >= this.project.scenes.length) {
      this.currentSceneIndex = Math.max(0, this.project.scenes.length - 1);
    }

    this.renderScenesList();
    this.renderTimeline();
    if (this.project.scenes.length > 0) {
      this.selectScene(this.currentSceneIndex);
    } else {
      this.clearInspector();
    }
  },

  clearCurrentImageOnly() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;

    // 複数選択されている場合
    if (this.selectedSceneIndices.size > 0) {
      const count = this.selectedSceneIndices.size;
      if (!confirm(`選択されている ${count} 件のシーンから「スライド画像のみ」を削除（クリア）しますか？\n（※ セリフ文章や音声設定はすべて残ります）`)) {
        return;
      }
      this.pushUndoState();
      this.selectedSceneIndices.forEach(idx => {
        const sc = this.project.scenes[idx];
        if (sc) sc.image_path = null;
      });
      this.renderScenesList();
      this.renderTimeline();
      this.selectScene(this.currentSceneIndex);
      alert(`${count} 件のシーンのスライド画像を削除しました。`);
      return;
    }

    // 単一選択の場合
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;
    if (!confirm(`Scene ${scene.slide_index || (this.currentSceneIndex + 1)} の「スライド画像のみ」を削除（クリア）しますか？\n（※ セリフ文章や音声設定はすべて残ります）`)) {
      return;
    }

    this.pushUndoState();
    scene.image_path = null;
    this.renderScenesList();
    this.renderTimeline();
    this.selectScene(this.currentSceneIndex);
  },

  // ==========================================
  // スライド画像削除 & 後続画像を自動繰り上げ (Ripple Shift Image)
  // ==========================================
  deleteImageAndShiftNext() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;
    const scene = this.project.scenes[this.currentSceneIndex];
    if (!scene) return;

    const sIdx = scene.slide_index || (this.currentSceneIndex + 1);
    if (!confirm(`【確認】Scene ${sIdx} のスライド画像を削除し、以降の後続スライド画像を1つずつ手前に自動繰り上げしますか？\n（※ セリフや音声設定は一切動かずそのまま残ります）`)) {
      return;
    }

    this.pushUndoState();

    const scenes = this.project.scenes;
    const startIdx = this.currentSceneIndex;

    // startIdx から末尾まで画像を1つ手前にシフト
    for (let i = startIdx; i < scenes.length - 1; i++) {
      scenes[i].image_path = scenes[i + 1].image_path;
    }
    // 最後のシーンの画像は空に
    scenes[scenes.length - 1].image_path = null;

    this.renderScenesList();
    this.renderTimeline();
    this.selectScene(this.currentSceneIndex);
    alert(`Scene ${sIdx} の画像を削除し、後続のスライド画像を1つずつ手前に繰り上げました！`);
  },

  // ==========================================
  // 履歴管理 (Undo / Redo - 元に戻す / やり直す)
  // ==========================================
  pushUndoState() {
    if (!this.project) return;
    try {
      const snap = JSON.stringify(this.project);
      this.undoStack.push(snap);
      if (this.undoStack.length > 50) {
        this.undoStack.shift();
      }
      this.redoStack = [];
      this.updateUndoRedoButtons();
    } catch (e) {}
  },

  undo() {
    if (this.undoStack.length === 0) return;
    try {
      const currentSnap = JSON.stringify(this.project);
      this.redoStack.push(currentSnap);
      if (this.redoStack.length > 50) {
        this.redoStack.shift();
      }

      const prevSnap = this.undoStack.pop();
      this.project = JSON.parse(prevSnap);
      if (this.currentSceneIndex >= (this.project.scenes ? this.project.scenes.length : 0)) {
        this.currentSceneIndex = Math.max(0, (this.project.scenes ? this.project.scenes.length : 0) - 1);
      }
      this.selectedSceneIndices.clear();
      this.renderScenesList();
      this.renderTimeline();
      if (this.project.scenes && this.project.scenes.length > 0) {
        this.selectScene(this.currentSceneIndex);
      } else {
        this.clearInspector();
      }
      this.updateUndoRedoButtons();
    } catch (e) {
      console.error("Undo error:", e);
    }
  },

  redo() {
    if (this.redoStack.length === 0) return;
    try {
      const currentSnap = JSON.stringify(this.project);
      this.undoStack.push(currentSnap);
      if (this.undoStack.length > 50) {
        this.undoStack.shift();
      }

      const nextSnap = this.redoStack.pop();
      this.project = JSON.parse(nextSnap);
      if (this.currentSceneIndex >= (this.project.scenes ? this.project.scenes.length : 0)) {
        this.currentSceneIndex = Math.max(0, (this.project.scenes ? this.project.scenes.length : 0) - 1);
      }
      this.selectedSceneIndices.clear();
      this.renderScenesList();
      this.renderTimeline();
      if (this.project.scenes && this.project.scenes.length > 0) {
        this.selectScene(this.currentSceneIndex);
      } else {
        this.clearInspector();
      }
      this.updateUndoRedoButtons();
    } catch (e) {
      console.error("Redo error:", e);
    }
  },

  updateUndoRedoButtons() {
    const btnUndo = document.getElementById("btn-undo");
    const btnRedo = document.getElementById("btn-redo");
    if (btnUndo) {
      btnUndo.disabled = this.undoStack.length === 0;
      btnUndo.style.opacity = this.undoStack.length === 0 ? "0.4" : "1.0";
    }
    if (btnRedo) {
      btnRedo.disabled = this.redoStack.length === 0;
      btnRedo.style.opacity = this.redoStack.length === 0 ? "0.4" : "1.0";
    }
  },

  // ==========================================
  // クリップボード操作 (Cut, Copy, Paste)
  // ==========================================
  copySelectedScene() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;
    
    let targetScenes = [];
    if (this.selectedSceneIndices.size > 0) {
      const sortedIdxs = Array.from(this.selectedSceneIndices).sort((a, b) => a - b);
      targetScenes = sortedIdxs.map(i => this.project.scenes[i]).filter(Boolean);
    } else {
      const s = this.project.scenes[this.currentSceneIndex];
      if (s) targetScenes = [s];
    }

    if (targetScenes.length === 0) return;
    this.clipboardScenes = JSON.parse(JSON.stringify(targetScenes));
    alert(`${this.clipboardScenes.length} 件のシーンをクリップボードにコピーしました！`);
  },

  cutSelectedScene() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) return;
    this.pushUndoState();

    let targetIndices = [];
    if (this.selectedSceneIndices.size > 0) {
      targetIndices = Array.from(this.selectedSceneIndices).sort((a, b) => b - a); // 降順
    } else {
      targetIndices = [this.currentSceneIndex];
    }

    const copied = targetIndices.slice().reverse().map(i => this.project.scenes[i]).filter(Boolean);
    this.clipboardScenes = JSON.parse(JSON.stringify(copied));

    // 削除
    targetIndices.forEach(i => {
      this.project.scenes.splice(i, 1);
    });

    // スライド番号振り直し
    this.project.scenes.forEach((sc, i) => sc.slide_index = i + 1);
    this.selectedSceneIndices.clear();

    if (this.currentSceneIndex >= this.project.scenes.length) {
      this.currentSceneIndex = Math.max(0, this.project.scenes.length - 1);
    }

    this.renderScenesList();
    this.renderTimeline();
    if (this.project.scenes.length > 0) {
      this.selectScene(this.currentSceneIndex);
    } else {
      this.clearInspector();
    }
  },

  pasteScene() {
    if (!this.project || !this.clipboardScenes || this.clipboardScenes.length === 0) {
      alert("クリップボードが空です。先にシーンをコピーまたはカットしてください。");
      return;
    }
    this.pushUndoState();

    if (!this.project.scenes) this.project.scenes = [];
    const insertPos = (this.currentSceneIndex >= 0 && this.currentSceneIndex < this.project.scenes.length)
      ? this.currentSceneIndex + 1
      : this.project.scenes.length;

    const toPaste = JSON.parse(JSON.stringify(this.clipboardScenes));
    toPaste.forEach((s, idx) => {
      this.project.scenes.splice(insertPos + idx, 0, s);
    });

    // スライド番号振り直し
    this.project.scenes.forEach((sc, i) => sc.slide_index = i + 1);
    this.selectedSceneIndices.clear();

    this.renderScenesList();
    this.renderTimeline();
    this.selectScene(insertPos);
  },

  // ==========================================
  // キーボードショートカット
  // ==========================================
  setupKeyboardShortcuts() {
    window.addEventListener("keydown", (e) => {
      const activeTag = document.activeElement ? document.activeElement.tagName.toLowerCase() : "";
      const isInputFocused = (activeTag === "input" || activeTag === "textarea" || activeTag === "select");

      const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
      const modKey = isMac ? e.metaKey : e.ctrlKey;

      // 入力フォーカスがない場合の単独キー操作
      if (!isInputFocused) {
        // スペースキー: 再生 / 一時停止
        if (e.code === "Space" || e.key === " ") {
          e.preventDefault();
          this.togglePlay();
          return;
        }
        // Fキー: 全画面プレビュー切替
        if (e.key.toLowerCase() === "f" && !modKey) {
          e.preventDefault();
          this.toggleFullscreenPreview();
          return;
        }
        // Cキー: 字幕オーバーレイ切替
        if (e.key.toLowerCase() === "c" && !modKey) {
          e.preventDefault();
          this.toggleTelopOverlay();
          return;
        }
        // 左矢印キー: 前のシーンへ
        if (e.key === "ArrowLeft" && !modKey) {
          e.preventDefault();
          this.jumpPrevScene();
          return;
        }
        // 右矢印キー: 次のシーンへ
        if (e.key === "ArrowRight" && !modKey) {
          e.preventDefault();
          this.jumpNextScene();
          return;
        }
        // Iキー: In点マーク
        if (e.key.toLowerCase() === "i" && !modKey) {
          e.preventDefault();
          this.setMarkerIn();
          return;
        }
        // Oキー: Out点マーク
        if (e.key.toLowerCase() === "o" && !modKey) {
          e.preventDefault();
          this.setMarkerOut();
          return;
        }
      }

      if (!modKey) return;

      // Undo: Cmd+Z (or Ctrl+Z)
      if (e.key.toLowerCase() === "z" && !e.shiftKey) {
        if (!isInputFocused) {
          e.preventDefault();
          this.undo();
        }
      }
      // Redo: Cmd+Shift+Z (or Ctrl+Y / Ctrl+Shift+Z)
      else if ((e.key.toLowerCase() === "z" && e.shiftKey) || e.key.toLowerCase() === "y") {
        if (!isInputFocused) {
          e.preventDefault();
          this.redo();
        }
      }
      // Cut: Cmd+X
      else if (e.key.toLowerCase() === "x") {
        if (!isInputFocused) {
          e.preventDefault();
          this.cutSelectedScene();
        }
      }
      // Copy: Cmd+C
      else if (e.key.toLowerCase() === "c") {
        if (!isInputFocused) {
          e.preventDefault();
          this.copySelectedScene();
        }
      }
      // Paste: Cmd+V
      else if (e.key.toLowerCase() === "v") {
        if (!isInputFocused) {
          e.preventDefault();
          this.pasteScene();
        }
      }
    });
  },

  // ==========================================
  // バックアップ・最大100分巻き戻し (10枠)
  // ==========================================
  openBackupsModal() {
    const modal = document.getElementById("modal-backups");
    if (!modal) return;
    modal.classList.add("active");
    this.loadBackupsList();
  },

  closeBackupsModal() {
    const modal = document.getElementById("modal-backups");
    if (modal) modal.classList.remove("active");
  },

  async loadBackupsList() {
    const listContainer = document.getElementById("backups-list-container");
    if (!listContainer) return;
    listContainer.innerHTML = '<div style="padding: 20px; text-align: center; color: #888;">バックアップ履歴を読み込み中...</div>';

    try {
      const pName = this.project ? encodeURIComponent(this.project.project_name || "") : "";
      const res = await fetch(`/api/project/backups?project_name=${pName}`);
      const data = await res.json();

      if (data.success && data.backups && data.backups.length > 0) {
        listContainer.innerHTML = "";
        data.backups.forEach((b, idx) => {
          const itemDiv = document.createElement("div");
          itemDiv.className = "file-row";
          itemDiv.style.display = "flex";
          itemDiv.style.justifyContent = "space-between";
          itemDiv.style.alignItems = "center";
          itemDiv.style.padding = "10px 14px";
          itemDiv.style.borderBottom = "1px solid #333";

          const slotNum = idx + 1;
          const timeAgo = b.time_ago || `${b.diff_minutes || 0}分前`;

          itemDiv.innerHTML = `
            <div style="display: flex; flex-direction: column; gap: 4px;">
              <div style="font-weight: 700; color: #fff; font-size: 13px;">
                <span style="background: var(--accent-blue); padding: 2px 6px; border-radius: 4px; font-size: 11px; margin-right: 6px;">枠 ${slotNum} / 10</span>
                ${b.project_name} - <span style="color: var(--accent-green);">${timeAgo}</span>
              </div>
              <div style="font-size: 11px; color: #888;">
                保存日時: ${b.updated_at} | シーン数: ${b.scenes_count} | 容量: ${this.formatBytes(b.size_bytes)}
              </div>
            </div>
            <button class="btn-sm btn-primary" onclick="App.restoreFromBackup('${encodeURIComponent(b.path)}')" style="white-space: nowrap; padding: 4px 12px; font-weight: 700;">⏪ この時点に巻き戻す</button>
          `;
          listContainer.appendChild(itemDiv);
        });
      } else {
        listContainer.innerHTML = '<div style="padding: 30px; text-align: center; color: #888;">保存されたバックアップはまだありません。</div>';
      }
    } catch (e) {
      listContainer.innerHTML = `<div style="padding: 20px; color: #ff6b6b;">バックアップ取得エラー: ${e}</div>`;
    }
  },

  async backupNow() {
    if (!this.project) return;
    try {
      const res = await fetch("/api/project/backup_now", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ project: this.project })
      });
      const data = await res.json();
      if (data.success) {
        alert("手動バックアップを保存しました！");
        this.loadBackupsList();
      } else {
        alert("バックアップ保存に失敗しました。");
      }
    } catch (e) {
      alert("通信エラー: " + e);
    }
  },

  async restoreFromBackup(encodedPath) {
    const backupPath = decodeURIComponent(encodedPath);
    if (!confirm(`本当にこのバックアップ時点へプロジェクトを巻き戻しますか？\n（現在の未保存の変更はバックアップの内容に置き換わります）`)) {
      return;
    }

    try {
      const res = await fetch("/api/project/restore_backup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ backup_path: backupPath })
      });
      const data = await res.json();
      if (data.success && data.project) {
        this.project = data.project;
        this.currentSceneIndex = 0;
        this.selectedSceneIndices.clear();
        this.renderScenesList();
        this.renderTimeline();
        if (this.project.scenes && this.project.scenes.length > 0) {
          this.selectScene(0);
        } else {
          this.clearInspector();
        }
        this.closeBackupsModal();
        alert(`バックアップから正常に復元しました！（全 ${this.project.scenes ? this.project.scenes.length : 0} シーン）`);
      } else {
        alert("復元エラー: " + (data.error || ""));
      }
    } catch (e) {
      alert("通信エラー: " + e);
    }
  },

  // ==========================================
  // 複数シーン連続効果音 (SE) & BGM の管理
  // ==========================================
  openAddSpanSeModal() {
    if (!this.project || !this.project.scenes || this.project.scenes.length === 0) {
      alert("先にプロジェクトを読み込むか作成してください。");
      return;
    }
    const modal = document.getElementById("modal-span-se");
    if (!modal) return;

    document.getElementById("span-se-modal-title").innerText = "🔔 複数シーン連続効果音 (SE) の追加";
    document.getElementById("span-se-id").value = "";
    document.getElementById("btn-span-se-delete").style.display = "none";

    const curSlide = (this.currentSceneIndex >= 0 && this.project.scenes[this.currentSceneIndex]) 
      ? (this.project.scenes[this.currentSceneIndex].slide_index || (this.currentSceneIndex + 1)) : 1;
    document.getElementById("span-se-start-scene").value = curSlide;
    document.getElementById("span-se-end-scene").value = Math.min(this.project.scenes.length, curSlide + 2);
    document.getElementById("span-se-volume").value = 100;
    document.getElementById("span-se-vol-val").innerText = "100%";
    document.getElementById("span-se-speed").value = 100;
    document.getElementById("span-se-spd-val").innerText = "1.0x";
    document.getElementById("span-se-loop").checked = false;
    document.getElementById("span-se-reverse").checked = false;

    this.populateSeSelectDropdown("span-se-select");
    modal.classList.add("active");
  },

  openEditSpanSeModal(seId) {
    if (!this.project || !this.project.timeline || !this.project.timeline.sound_effects) return;
    const se = this.project.timeline.sound_effects.find(item => item.id === seId);
    if (!se) return;

    const modal = document.getElementById("modal-span-se");
    if (!modal) return;

    document.getElementById("span-se-modal-title").innerText = `🔔 効果音設定: ${se.name || "SE"}`;
    document.getElementById("span-se-id").value = se.id;
    document.getElementById("btn-span-se-delete").style.display = "block";

    this.populateSeSelectDropdown("span-se-select", se.audio_path);
    document.getElementById("span-se-start-scene").value = se.start_scene_index || 1;
    document.getElementById("span-se-end-scene").value = se.end_scene_index || 1;
    const vol = Math.round((se.volume !== undefined ? se.volume : 1.0) * 100);
    document.getElementById("span-se-volume").value = vol;
    document.getElementById("span-se-vol-val").innerText = `${vol}%`;
    const spd = Math.round((se.speed !== undefined ? se.speed : 1.0) * 100);
    document.getElementById("span-se-speed").value = spd;
    document.getElementById("span-se-spd-val").innerText = `${(spd / 100).toFixed(2)}x`;
    document.getElementById("span-se-loop").checked = se.loop === true;
    document.getElementById("span-se-reverse").checked = se.reverse === true;

    modal.classList.add("active");
  },

  closeSpanSeModal() {
    const modal = document.getElementById("modal-span-se");
    if (modal) modal.classList.remove("active");
  },

  populateSeSelectDropdown(selectId, selectedVal = "") {
    const sel = document.getElementById(selectId);
    if (!sel) return;
    sel.innerHTML = "";
    if (this.soundEffectsList && this.soundEffectsList.length > 0) {
      this.soundEffectsList.forEach(se => {
        const opt = document.createElement("option");
        opt.value = se.path;
        opt.innerText = se.name;
        if (se.path === selectedVal || (selectedVal && se.name === selectedVal)) {
          opt.selected = true;
        }
        sel.appendChild(opt);
      });
    } else {
      sel.innerHTML = '<option value="">(効果音が見つかりません)</option>';
    }
  },

  async previewSpanSeModalSound() {
    this.stopAllAudioAndTimers(false);
    const sel = document.getElementById("span-se-select");
    if (!sel || !sel.value) return;
    const audioUrl = `/media/${encodeURIComponent(sel.value)}`;
    const vol = Math.min(1.0, parseInt(document.getElementById("span-se-volume").value || 100) / 100.0);
    const spd = parseInt(document.getElementById("span-se-speed").value || 100) / 100.0;
    const isRev = document.getElementById("span-se-reverse").checked;
    
    try {
      if (this._modalSeNode) {
        try { this._modalSeNode.stop(); } catch(e){}
        this._modalSeNode = null;
      }
      this._modalSeNode = await this.playCustomAudio(audioUrl, {
        volume: vol,
        playbackRate: spd,
        reverse: isRev
      });
    } catch (e) {
      alert("試聴エラー: " + e);
    }
  },

  saveSpanSeClip() {
    if (!this.project) return;
    this.pushUndoState();
    if (!this.project.timeline) this.project.timeline = {};
    if (!this.project.timeline.sound_effects) this.project.timeline.sound_effects = [];

    const seId = document.getElementById("span-se-id").value;
    const sel = document.getElementById("span-se-select");
    const audioPath = sel ? sel.value : "";
    const seName = sel && sel.options[sel.selectedIndex] ? sel.options[sel.selectedIndex].text : "SE";

    const stScene = parseInt(document.getElementById("span-se-start-scene").value) || 1;
    const endScene = parseInt(document.getElementById("span-se-end-scene").value) || stScene;
    const vol = (parseInt(document.getElementById("span-se-volume").value) || 100) / 100.0;
    const spd = (parseInt(document.getElementById("span-se-speed").value) || 100) / 100.0;
    const loop = document.getElementById("span-se-loop").checked;
    const reverse = document.getElementById("span-se-reverse").checked;

    if (!audioPath) {
      alert("効果音ファイルを選択してください。");
      return;
    }

    if (seId) {
      const existing = this.project.timeline.sound_effects.find(item => item.id === seId);
      if (existing) {
        existing.name = seName;
        existing.audio_path = audioPath;
        existing.start_scene_index = Math.min(stScene, endScene);
        existing.end_scene_index = Math.max(stScene, endScene);
        existing.volume = vol;
        existing.speed = spd;
        existing.loop = loop;
        existing.reverse = reverse;
      }
    } else {
      const newSe = {
        id: "se_" + Date.now(),
        name: seName,
        audio_path: audioPath,
        start_scene_index: Math.min(stScene, endScene),
        end_scene_index: Math.max(stScene, endScene),
        volume: vol,
        speed: spd,
        loop: loop,
        reverse: reverse
      };
      this.project.timeline.sound_effects.push(newSe);
    }

    // 再生中ノードのキャッシュクリア（設定変更を即座に適用）
    if (this._activeSpanSeMap) {
      for (const [id, handle] of this._activeSpanSeMap.entries()) {
        try { handle.stop(); } catch(e) {}
      }
      this._activeSpanSeMap.clear();
    }

    this.renderTimeline();
    this.saveProjectSilently();
    this.closeSpanSeModal();
  },

  deleteSpanSeClip() {
    const seId = document.getElementById("span-se-id").value;
    if (!seId || !this.project || !this.project.timeline || !this.project.timeline.sound_effects) return;
    if (!confirm("この効果音クリップを削除しますか？")) return;

    this.pushUndoState();
    this.project.timeline.sound_effects = this.project.timeline.sound_effects.filter(item => item.id !== seId);

    // 再生中ノードのキャッシュクリア
    if (this._activeSpanSeMap) {
      for (const [id, handle] of this._activeSpanSeMap.entries()) {
        try { handle.stop(); } catch(e) {}
      }
      this._activeSpanSeMap.clear();
    }

    this.renderTimeline();
    this.saveProjectSilently();
    this.closeSpanSeModal();
  },

  // BGM モーダル
  openBgmModal() {
    if (!this.project) return;
    const modal = document.getElementById("modal-bgm");
    if (!modal) return;

    const bgmSel = document.getElementById("bgm-select-file");
    if (bgmSel) {
      bgmSel.innerHTML = "";
      if (this.soundEffectsList && this.soundEffectsList.length > 0) {
        this.soundEffectsList.forEach(item => {
          const opt = document.createElement("option");
          opt.value = item.path;
          opt.innerText = item.name;
          bgmSel.appendChild(opt);
        });
      }
    }

    const currentBgm = this.project.timeline ? this.project.timeline.bgm : null;
    if (currentBgm && currentBgm.audio_path) {
      if (bgmSel) bgmSel.value = currentBgm.audio_path;
      const vol = Math.round((currentBgm.volume !== undefined ? currentBgm.volume : 0.25) * 100);
      document.getElementById("bgm-volume").value = vol;
      document.getElementById("bgm-vol-val").innerText = `${vol}%`;
      const spd = Math.round((currentBgm.speed !== undefined ? currentBgm.speed : 1.0) * 100);
      document.getElementById("bgm-speed").value = spd;
      document.getElementById("bgm-spd-val").innerText = `${(spd / 100).toFixed(2)}x`;
      document.getElementById("bgm-loop").checked = currentBgm.loop !== false;
    } else {
      document.getElementById("bgm-volume").value = 25;
      document.getElementById("bgm-vol-val").innerText = "25%";
      document.getElementById("bgm-speed").value = 100;
      document.getElementById("bgm-spd-val").innerText = "1.0x";
      document.getElementById("bgm-loop").checked = true;
    }

    modal.classList.add("active");
  },

  closeBgmModal() {
    const modal = document.getElementById("modal-bgm");
    if (modal) modal.classList.remove("active");
  },

  previewBgmModalSound() {
    this.stopAllAudioAndTimers(false);
    const sel = document.getElementById("bgm-select-file");
    if (!sel || !sel.value) return;
    const audioUrl = `/media/${encodeURIComponent(sel.value)}`;
    const aud = new Audio(audioUrl);
    aud.volume = Math.min(1.0, parseInt(document.getElementById("bgm-volume").value || 25) / 100.0);
    aud.playbackRate = parseInt(document.getElementById("bgm-speed").value || 100) / 100.0;
    aud.play().catch(e => alert("試聴エラー: " + e));
  },

  saveBgmSettings() {
    if (!this.project) return;
    this.pushUndoState();
    if (!this.project.timeline) this.project.timeline = {};

    const sel = document.getElementById("bgm-select-file");
    const audioPath = sel ? sel.value : "";
    const name = sel && sel.options[sel.selectedIndex] ? sel.options[sel.selectedIndex].text : "BGM";
    const vol = (parseInt(document.getElementById("bgm-volume").value) || 25) / 100.0;
    const spd = (parseInt(document.getElementById("bgm-speed").value) || 100) / 100.0;
    const loop = document.getElementById("bgm-loop").checked;

    if (!audioPath) {
      alert("BGMファイルを選択してください。");
      return;
    }

    this.project.timeline.bgm = {
      name: name,
      audio_path: audioPath,
      volume: vol,
      speed: spd,
      loop: loop
    };

    this.renderTimeline();
    this.closeBgmModal();
  },

  clearBgm() {
    if (!this.project || !this.project.timeline) return;
    this.pushUndoState();
    this.project.timeline.bgm = null;
    this.bgmElement.pause();
    this.renderTimeline();
    this.closeBgmModal();
  },

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = (seconds % 60).toFixed(1);
    return `${mins.toString().padStart(2, "0")}:${secs.padStart(4, "0")}`;
  },

  formatBytes(bytes) {
    if (bytes === 0) return "0 B";
    const k = 1024;
    const sizes = ["B", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
  },

  getFileIcon(ext) {
    const e = (ext || "").toLowerCase();
    if ([".key", ".pptx"].includes(e)) return "📊";
    if ([".mp4", ".mov", ".avi"].includes(e)) return "🎬";
    if ([".wav", ".mp3", ".m4a", ".aac"].includes(e)) return "🎵";
    if ([".png", ".jpg", ".jpeg", ".gif"].includes(e)) return "🖼️";
    if ([".tpmproj", ".json", ".ymmp"].includes(e)) return "📁";
    return "📄";
  },

  showNotification(title, body) {
    if ("Notification" in window && Notification.permission === "granted") {
      new Notification(title, { body });
    }
  }
};

// 起動時初期化
window.addEventListener("DOMContentLoaded", () => {
  App.init();
});
