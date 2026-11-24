import Foundation
import AppKit
import AVFoundation

// MARK: - Media Modality (4大メディア種別)
public enum AIMediaModality: String, CaseIterable, Identifiable, Codable {
    case image = "画像"
    case video = "動画"
    case se = "効果音(SE)"
    case bgm = "BGM"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .image: return "photo.artframe"
        case .video: return "film.stack"
        case .se: return "waveform.badge.exclamationmark"
        case .bgm: return "music.quarternote.3"
        }
    }
}

// MARK: - Dedicated Media Model Specification
public struct AIMediaModelSpec: Identifiable, Hashable, Codable {
    public let id: String
    public let displayName: String
    public let modality: AIMediaModality
    public let provider: AIMediaProviderType
    public let summary: String

    public init(id: String, displayName: String, modality: AIMediaModality, provider: AIMediaProviderType, summary: String) {
        self.id = id
        self.displayName = displayName
        self.modality = modality
        self.provider = provider
        self.summary = summary
    }
}

// MARK: - External Media AI Provider Type
public enum AIMediaProviderType: String, CaseIterable, Identifiable, Codable {
    case gemini = "Google Gemini API"
    case openAI = "OpenAI API"
    case elevenLabs = "ElevenLabs API"
    case stabilityAI = "Stability AI API"
    case falAI = "fal.ai 統合メディアAPI"
    case replicate = "Replicate API"
    case grok = "xAI Grok API"
    case runway = "Runway API"
    case luma = "Luma Dream Machine API"
    case localBuiltIn = "内蔵オフライン合成 / 参考資料"

    public var id: String { rawValue }

    /// APIキー登録を伴う外部プロバイダー一覧
    public static var externalProviders: [AIMediaProviderType] {
        return allCases.filter { $0 != .localBuiltIn }
    }

    /// LLMプロバイダーとは独立して専用カードを持つメディア特化プロバイダー一覧
    public static var dedicatedMediaProviders: [AIMediaProviderType] {
        return [.elevenLabs, .stabilityAI, .falAI, .replicate, .runway, .luma]
    }

    /// 指定モダリティをサポートする全プロバイダー一覧（外部API優先）
    public static func providers(for modality: AIMediaModality) -> [AIMediaProviderType] {
        return allCases.filter { $0.supportedModalities.contains(modality) }
    }

    public var iconName: String {
        switch self {
        case .gemini: return "sparkles"
        case .openAI: return "brain"
        case .elevenLabs: return "waveform.circle.fill"
        case .stabilityAI: return "paintbrush.pointed.fill"
        case .falAI: return "bolt.horizontal.icloud.fill"
        case .replicate: return "cube.transparent.fill"
        case .grok: return "bolt.horizontal.circle.fill"
        case .runway: return "film.circle.fill"
        case .luma: return "rays"
        case .localBuiltIn: return "internaldrive.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .gemini:
            return "Google AI Studio (画像: Imagen 3/4, Gemini Flash Image / 動画: Veo 2/3)"
        case .openAI:
            return "OpenAI Platform (画像: GPT Image 1, DALL-E 3 / 動画: Sora 2)"
        case .elevenLabs:
            return "ElevenLabs Audio AI (SE: Sound Effects v3/v2 / BGM: ElevenLabs Music v2.5)"
        case .stabilityAI:
            return "Stability Platform (画像: Stable Image Ultra/Core/SD3.5 / BGM・SE: Stable Audio 2.0)"
        case .falAI:
            return "fal.ai Queue API (画像: FLUX.1/SDXL / 動画: Wan 2.1・Kling / BGM: Ace-Step / SE: MMAudio)"
        case .replicate:
            return "Replicate Cloud (画像: FLUX 1.1 Pro / 動画: Wan 2.1・Ray 2 / BGM: MusicGen / SE: AudioLDM 2)"
        case .grok:
            return "xAI Console (画像: Grok Imagine Image 2.0 / Grok 2 Image)"
        case .runway:
            return "Runway Developer API (動画: Gen-4.5 / Gen-4 Turbo / Gen-3 Alpha Turbo)"
        case .luma:
            return "Luma Labs Dream Machine (動画: Ray 2 / 画像: Photon 1)"
        case .localBuiltIn:
            return "APIキー不要 (東方公式参考資料アーカイブ・内蔵シンセ波形合成・プロシージャル演出動画)"
        }
    }

    public var defaultBillingURL: String {
        switch self {
        case .gemini: return "https://aistudio.google.com/"
        case .openAI: return "https://platform.openai.com/usage"
        case .elevenLabs: return "https://elevenlabs.io/app/subscription"
        case .stabilityAI: return "https://platform.stability.ai/account/credits"
        case .falAI: return "https://fal.ai/dashboard/billing"
        case .replicate: return "https://replicate.com/account/billing"
        case .grok: return "https://console.x.ai/"
        case .runway: return "https://dev.runwayml.com/"
        case .luma: return "https://lumalabs.ai/dream-machine/api/keys"
        case .localBuiltIn: return "https://www.nanndemoya.net/top"
        }
    }

    public var supportedModalities: [AIMediaModality] {
        switch self {
        case .gemini: return [.image, .video]
        case .openAI: return [.image, .video]
        case .elevenLabs: return [.se, .bgm]
        case .stabilityAI: return [.image, .bgm, .se]
        case .falAI: return [.image, .video, .bgm, .se]
        case .replicate: return [.image, .video, .bgm, .se]
        case .grok: return [.image]
        case .runway: return [.video]
        case .luma: return [.image, .video]
        case .localBuiltIn: return [.image, .video, .bgm, .se]
        }
    }

    public func models(for modality: AIMediaModality) -> [AIMediaModelSpec] {
        switch (self, modality) {
        // --- Google Gemini API ---
        case (.gemini, .image):
            return [
                AIMediaModelSpec(id: "imagen-3.0-generate-002", displayName: "Imagen 3 (高精細イラスト・風景)", modality: .image, provider: .gemini, summary: "Google Imagen 3 専用画像生成モデル"),
                AIMediaModelSpec(id: "imagen-4.0-generate-001", displayName: "Imagen 4 (最新フラッグシップ画像)", modality: .image, provider: .gemini, summary: "Google Imagen 4 高精細生成モデル"),
                AIMediaModelSpec(id: "gemini-2.5-flash-image", displayName: "Gemini 2.5 Flash Image (ネイティブ画像生成)", modality: .image, provider: .gemini, summary: "Geminiマルチモーダル直接画像出力")
            ]
        case (.gemini, .video):
            return [
                AIMediaModelSpec(id: "veo-3.0-generate-preview", displayName: "Veo 3 (高品位シネマティック動画)", modality: .video, provider: .gemini, summary: "Google Veo 3 非同期MP4動画生成"),
                AIMediaModelSpec(id: "veo-2.0-generate-001", displayName: "Veo 2 (安定MP4アニメーション動画)", modality: .video, provider: .gemini, summary: "Google Veo 2 動画生成モデル")
            ]

        // --- OpenAI API ---
        case (.openAI, .image):
            return [
                AIMediaModelSpec(id: "gpt-image-1", displayName: "GPT Image 1 (高精度プロンプト追従)", modality: .image, provider: .openAI, summary: "OpenAI最新ネイティブ画像生成モデル"),
                AIMediaModelSpec(id: "dall-e-3", displayName: "DALL-E 3 (高彩度イラスト・背景)", modality: .image, provider: .openAI, summary: "OpenAI DALL-E 3 拡散モデル")
            ]
        case (.openAI, .video):
            return [
                AIMediaModelSpec(id: "sora-2", displayName: "Sora 2 (高速AI動画生成)", modality: .video, provider: .openAI, summary: "OpenAI Sora 2 MP4動画生成"),
                AIMediaModelSpec(id: "sora-2-pro", displayName: "Sora 2 Pro (高精細シネマ動画)", modality: .video, provider: .openAI, summary: "OpenAI Sora 2 Pro 高品質動画生成")
            ]

        // --- ElevenLabs API ---
        case (.elevenLabs, .se):
            return [
                AIMediaModelSpec(id: "eleven_text_to_sound_v3", displayName: "Sound Effects v3 (高精度効果音)", modality: .se, provider: .elevenLabs, summary: "ElevenLabs最新SE専用モデル"),
                AIMediaModelSpec(id: "eleven_text_to_sound_v2", displayName: "Sound Effects v2 (標準効果音・ループ対応)", modality: .se, provider: .elevenLabs, summary: "ElevenLabs SE v2モデル")
            ]
        case (.elevenLabs, .bgm):
            return [
                AIMediaModelSpec(id: "music_v2_5", displayName: "ElevenLabs Music v2.5 (高音質インストBGM)", modality: .bgm, provider: .elevenLabs, summary: "スタジオ品質インストゥルメンタル作曲"),
                AIMediaModelSpec(id: "music_v1", displayName: "ElevenLabs Music v1 (標準BGM作曲)", modality: .bgm, provider: .elevenLabs, summary: "ElevenLabs Music v1モデル")
            ]

        // --- Stability AI API ---
        case (.stabilityAI, .image):
            return [
                AIMediaModelSpec(id: "ultra", displayName: "Stable Image Ultra (最高品質)", modality: .image, provider: .stabilityAI, summary: "Stability最高峰フラッグシップ画像生成"),
                AIMediaModelSpec(id: "core", displayName: "Stable Image Core (高速・高精細)", modality: .image, provider: .stabilityAI, summary: "高速・バランスの取れたイラスト生成"),
                AIMediaModelSpec(id: "sd3.5-large", displayName: "Stable Diffusion 3.5 Large", modality: .image, provider: .stabilityAI, summary: "SD 3.5 Large 8Bモデル")
            ]
        case (.stabilityAI, .bgm):
            return [
                AIMediaModelSpec(id: "stable-audio-2", displayName: "Stable Audio 2.0 (ステレオBGM作曲)", modality: .bgm, provider: .stabilityAI, summary: "最大180秒対応・高音質ステレオBGM生成")
            ]
        case (.stabilityAI, .se):
            return [
                AIMediaModelSpec(id: "stable-audio-2-se", displayName: "Stable Audio 2.0 (高品位効果音SE)", modality: .se, provider: .stabilityAI, summary: "テキストから任意のSE・環境音を生成")
            ]

        // --- fal.ai 統合メディアAPI ---
        case (.falAI, .image):
            return [
                AIMediaModelSpec(id: "fal-ai/flux/dev", displayName: "FLUX.1 [dev] (高精細アニメ・背景)", modality: .image, provider: .falAI, summary: "12Bパラメータ高精細拡散モデル"),
                AIMediaModelSpec(id: "fal-ai/flux/schnell", displayName: "FLUX.1 [schnell] (超高速生成)", modality: .image, provider: .falAI, summary: "4ステップ高速生成モデル"),
                AIMediaModelSpec(id: "fal-ai/fast-lightning-sdxl", displayName: "SDXL 1.0 Lightning (アニメ・立ち絵)", modality: .image, provider: .falAI, summary: "SDXL高速アニメイラスト生成"),
                AIMediaModelSpec(id: "fal-ai/recraft-v3", displayName: "Recraft V3 (デザイン・イラスト特化)", modality: .image, provider: .falAI, summary: "構図・スタイル制御に優れた画像モデル")
            ]
        case (.falAI, .video):
            return [
                AIMediaModelSpec(id: "fal-ai/wan-t2v", displayName: "Wan 2.1 Text-to-Video (アニメ・汎用動画)", modality: .video, provider: .falAI, summary: "滑らかな動きのMP4動画生成"),
                AIMediaModelSpec(id: "fal-ai/kling-video/v1.6/standard/text-to-video", displayName: "Kling Video v1.6 (高品質モーション)", modality: .video, provider: .falAI, summary: "Kling v1.6 Text-to-Video"),
                AIMediaModelSpec(id: "fal-ai/minimax/video-01", displayName: "MiniMax Hailuo Video-01", modality: .video, provider: .falAI, summary: "MiniMax高表現力AI動画モデル"),
                AIMediaModelSpec(id: "fal-ai/luma-dream-machine", displayName: "Luma Dream Machine (fal経由)", modality: .video, provider: .falAI, summary: "Luma動画生成をfalキーで利用")
            ]
        case (.falAI, .bgm):
            return [
                AIMediaModelSpec(id: "fal-ai/ace-step", displayName: "Ace-Step AI Music (高速BGM作曲)", modality: .bgm, provider: .falAI, summary: "多ジャンル対応AI楽曲生成"),
                AIMediaModelSpec(id: "fal-ai/stable-audio", displayName: "Stable Audio Open (BGM生成)", modality: .bgm, provider: .falAI, summary: "インストBGM・アンビエント生成"),
                AIMediaModelSpec(id: "fal-ai/cassetteai/music-generator", displayName: "CassetteAI Music Generator", modality: .bgm, provider: .falAI, summary: "プロンプトからクリアなBGMを作曲")
            ]
        case (.falAI, .se):
            return [
                AIMediaModelSpec(id: "fal-ai/mmaudio-v2/text-to-audio", displayName: "MMAudio v2 (効果音・環境音特化)", modality: .se, provider: .falAI, summary: "高精度フォーリー・効果音生成"),
                AIMediaModelSpec(id: "fal-ai/cassetteai/sound-effects-generator", displayName: "CassetteAI Sound Effects", modality: .se, provider: .falAI, summary: "ゲーム・映像向けクリアなSE生成")
            ]

        // --- Replicate API ---
        case (.replicate, .image):
            return [
                AIMediaModelSpec(id: "black-forest-labs/flux-1.1-pro", displayName: "FLUX 1.1 Pro (フラッグシップ画像)", modality: .image, provider: .replicate, summary: "FLUX 1.1 Pro 高品質画像"),
                AIMediaModelSpec(id: "black-forest-labs/flux-schnell", displayName: "FLUX Schnell (高速画像)", modality: .image, provider: .replicate, summary: "高速・低コスト生成"),
                AIMediaModelSpec(id: "stability-ai/sdxl", displayName: "SDXL 1.0 (定番アニメ・イラスト)", modality: .image, provider: .replicate, summary: "Stable Diffusion XL 1.0")
            ]
        case (.replicate, .video):
            return [
                AIMediaModelSpec(id: "wan-video/wan-2.1-t2v-480p", displayName: "Wan 2.1 T2V (アニメ・汎用動画)", modality: .video, provider: .replicate, summary: "Wan 2.1 動画生成モデル"),
                AIMediaModelSpec(id: "minimax/video-01", displayName: "MiniMax Video-01", modality: .video, provider: .replicate, summary: "MiniMax動画生成モデル"),
                AIMediaModelSpec(id: "luma/ray-2-720p", displayName: "Luma Ray 2 720p", modality: .video, provider: .replicate, summary: "Luma Ray 2 720p動画生成")
            ]
        case (.replicate, .bgm):
            return [
                AIMediaModelSpec(id: "meta/musicgen", displayName: "Meta MusicGen Stereo Large (BGM)", modality: .bgm, provider: .replicate, summary: "Meta公式MusicGenステレオ作曲モデル"),
                AIMediaModelSpec(id: "stability-ai/stable-audio-2.5", displayName: "Stable Audio 2.5 (BGM)", modality: .bgm, provider: .replicate, summary: "Stable Audio 2.5 BGM生成")
            ]
        case (.replicate, .se):
            return [
                AIMediaModelSpec(id: "haoheliu/audio-ldm-2", displayName: "AudioLDM 2 (効果音・環境音)", modality: .se, provider: .replicate, summary: "AudioLDM 2 効果音拡散モデル"),
                AIMediaModelSpec(id: "stability-ai/stable-audio-2.5", displayName: "Stable Audio 2.5 (SE)", modality: .se, provider: .replicate, summary: "Stable Audio 2.5 効果音生成")
            ]

        // --- xAI Grok API ---
        case (.grok, .image):
            return [
                AIMediaModelSpec(id: "grok-imagine-image-2.0", displayName: "Grok Imagine Image 2.0", modality: .image, provider: .grok, summary: "xAI Grok最新ネイティブ画像モデル"),
                AIMediaModelSpec(id: "grok-2-image-1212", displayName: "Grok 2 Image", modality: .image, provider: .grok, summary: "xAI Grok 2 画像生成モデル")
            ]

        // --- Runway API ---
        case (.runway, .video):
            return [
                AIMediaModelSpec(id: "gen4.5", displayName: "Runway Gen-4.5 (最新フラッグシップ動画)", modality: .video, provider: .runway, summary: "Runway最新世代Text-to-Video"),
                AIMediaModelSpec(id: "gen4_turbo", displayName: "Runway Gen-4 Turbo (高速動画)", modality: .video, provider: .runway, summary: "Runway Gen-4 高速動画生成"),
                AIMediaModelSpec(id: "gen3a_turbo", displayName: "Runway Gen-3 Alpha Turbo", modality: .video, provider: .runway, summary: "Runway Gen-3 Alpha Turbo")
            ]

        // --- Luma Dream Machine API ---
        case (.luma, .image):
            return [
                AIMediaModelSpec(id: "photon-1", displayName: "Luma Photon 1 (高精細画像)", modality: .image, provider: .luma, summary: "Luma Photon 1 高品位画像生成"),
                AIMediaModelSpec(id: "photon-flash-1", displayName: "Luma Photon Flash 1 (高速生成)", modality: .image, provider: .luma, summary: "Luma Photon 高速モデル")
            ]
        case (.luma, .video):
            return [
                AIMediaModelSpec(id: "ray-2", displayName: "Luma Ray 2 (高精細モーション動画)", modality: .video, provider: .luma, summary: "Luma Ray 2 720p MP4動画生成"),
                AIMediaModelSpec(id: "ray-flash-2", displayName: "Luma Ray Flash 2 (高速動画)", modality: .video, provider: .luma, summary: "Luma Ray Flash 2 高速動画生成")
            ]

        // --- Local Built-In Fallback ---
        case (.localBuiltIn, .image):
            return [
                AIMediaModelSpec(id: "local-reference-archive", displayName: "東方公式参考資料アーカイブ (原画素材)", modality: .image, provider: .localBuiltIn, summary: "ローカル公式参考資料から原画素材を検出・配置")
            ]
        case (.localBuiltIn, .video):
            return [
                AIMediaModelSpec(id: "local-procedural-mp4", displayName: "内蔵プロシージャル演出動画 (オフラインMP4)", modality: .video, provider: .localBuiltIn, summary: "オフライン動作の弾幕・桜吹雪エフェクトMP4合成")
            ]
        case (.localBuiltIn, .bgm):
            return [
                AIMediaModelSpec(id: "local-synth-bgm", displayName: "内蔵多重シンセ波形合成 (ZUNペット/ピアノ/Lo-Fi)", modality: .bgm, provider: .localBuiltIn, summary: "オフライン動作のプロシージャルBGM波形合成")
            ]
        case (.localBuiltIn, .se):
            return [
                AIMediaModelSpec(id: "local-synth-se", displayName: "内蔵プロシージャル効果音合成 (東方SE・UI・日常)", modality: .se, provider: .localBuiltIn, summary: "オフライン動作のプロシージャル効果音波形合成")
            ]

        default:
            return []
        }
    }

    public func defaultModelId(for modality: AIMediaModality) -> String {
        return models(for: modality).first?.id ?? ""
    }

    public func displayName(forModelId modelId: String, modality: AIMediaModality) -> String {
        return models(for: modality).first(where: { $0.id == modelId })?.displayName ?? modelId
    }
}

// MARK: - Unified External Media REST API Client
public final class ExternalMediaAPIClient {
    public static let shared = ExternalMediaAPIClient()

    private init() {}

    public struct MediaAPIError: LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
        public init(_ message: String) { self.message = message }
    }

    // MARK: - Prompt Optimization / English Translation
    public func resolveEnglishMediaPrompt(
        prompt: String,
        modality: AIMediaModality,
        completion: @escaping (String) -> Void
    ) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(trimmed)
            return
        }
        if !CloudVirtualLinuxService.containsJapanese(trimmed) {
            completion(trimmed)
            return
        }

        // 1. 登録済みの外部LLM APIキーが有効な場合、それを用いて高精度な英語メディアプロンプトへ変換
        let tohoAI = TohoAIService.shared
        if let llmProvider = tohoAI.firstEnabledExternalLLMProvider() {
            let instruction: String
            switch modality {
            case .image:
                instruction = "Translate the following Japanese image generation prompt into concise English visual tags separated by commas. Begin with 'anime style, cel shaded anime illustration, masterpiece, best quality' unless photorealism is explicitly requested. Output ONLY the English prompt:\n\(trimmed)"
            case .video:
                instruction = "Translate the following Japanese video generation prompt into a vivid, concise English motion prompt describing subject, action, camera movement, and anime/cinematic style. Output ONLY the English prompt:\n\(trimmed)"
            case .bgm:
                instruction = "Translate the following Japanese background music request into a concise English instrumental music prompt specifying genre, instruments, mood, and tempo (BPM). Output ONLY the English prompt:\n\(trimmed)"
            case .se:
                instruction = "Translate the following Japanese sound effect request into a clear, concise English sound effect description (1 sentence). Output ONLY the English prompt:\n\(trimmed)"
            }
            let model = tohoAI.preferredLLMModel(for: llmProvider)
            tohoAI.callAPIOrGenerateSmart(prompt: instruction, provider: llmProvider, model: model) { responseText, _ in
                let cleaned = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && !cleaned.hasPrefix("⚠️") && !CloudVirtualLinuxService.containsJapanese(cleaned) {
                    completion(cleaned.replacingOccurrences(of: "\"", with: ""))
                } else {
                    completion(Self.deterministicFallbackPrompt(from: trimmed, modality: modality))
                }
            }
            return
        }

        // 2. ローカルゲートウェイ / Ollama 補助翻訳を試行し、オフライン時は内蔵辞書で即時補完
        let localMediaType: CloudVirtualLinuxService.LocalLLMMediaType
        switch modality {
        case .image: localMediaType = .image
        case .video: localMediaType = .video
        case .bgm: localMediaType = .music
        case .se: localMediaType = .soundEffect
        }
        CloudVirtualLinuxService.shared.translateAndOptimizePromptWithLocalLLM(prompt: trimmed, mediaType: localMediaType) { translated in
            if CloudVirtualLinuxService.containsJapanese(translated) {
                completion(Self.deterministicFallbackPrompt(from: trimmed, modality: modality))
            } else {
                completion(translated)
            }
        }
    }

    public static func deterministicFallbackPrompt(from raw: String, modality: AIMediaModality) -> String {
        switch modality {
        case .image:
            return AIImageGeneratorService.generateOptimizedEnglishPrompt(from: raw)
        case .video:
            let base = AIImageGeneratorService.generateOptimizedEnglishPrompt(from: raw)
            return "smooth anime motion, dynamic camera pan, fluid animation, \(base)"
        case .bgm:
            let inferred = AISoundGeneratorService.shared.analyzeBGMPrompt(raw)
            let styleEng: String
            switch inferred.style {
            case .modernSynthWave: styleEng = "80s analog synthwave, driving drum machine, groovy bassline"
            case .pianoAndStrings: styleEng = "emotional acoustic piano and lush orchestral strings"
            case .acousticGuitarLoFi: styleEng = "warm acoustic guitar, relaxing lo-fi chill beats, gentle piano"
            case .edmPluckAndBass: styleEng = "energetic EDM festival synth leads and punchy sub-bass"
            case .zunPetAndRock: styleEng = "fast-paced Japanese doujin melodic trumpet lead, piano arpeggio, rock drums"
            case .traditionalJapanese: styleEng = "traditional Japanese koto, shinobue flute, taiko percussion, oriental fantasy"
            case .chiptune8Bit: styleEng = "upbeat retro 8-bit chiptune game soundtrack"
            }
            return "Instrumental background music, \(styleEng), \(Int(inferred.bpm)) BPM, high quality studio mix"
        case .se:
            let lower = raw.lowercased()
            if lower.contains("着信") || lower.contains("通知") || lower.contains("スマホ") {
                return "Clean modern smartphone notification chime sound effect, crisp bell tone"
            } else if lower.contains("爆発") || lower.contains("ドカーン") {
                return "Massive cinematic explosion sound effect with deep impact boom and debris"
            } else if lower.contains("魔法") || lower.contains("キラキラ") || lower.contains("スペル") {
                return "Magical sparkling chime sound effect, shimmering fantasy spell cast"
            } else if lower.contains("剣") || lower.contains("刀") || lower.contains("斬") {
                return "Sharp metallic sword slash whoosh sound effect"
            } else if lower.contains("雷") || lower.contains("稲妻") {
                return "Powerful thunder strike and crackling lightning sound effect"
            } else if lower.contains("雨") || lower.contains("水滴") {
                return "Clear water droplet splash and gentle rain sound effect"
            } else if lower.contains("打撃") || lower.contains("パンチ") {
                return "Heavy martial arts punch impact sound effect"
            } else if lower.contains("足音") {
                return "Crisp footsteps walking on hard floor sound effect"
            } else if lower.contains("シャッター") || lower.contains("カメラ") {
                return "Mechanical DSLR camera shutter click sound effect"
            } else if lower.contains("タイピング") || lower.contains("キーボード") {
                return "Fast mechanical keyboard typing clack sound effect"
            }
            return "High clarity studio foley sound effect, crisp transient audio"
        }
    }

    // MARK: - 1. Dedicated Image Generation
    public func generateImage(
        provider: AIMediaProviderType,
        modelId: String,
        apiKey: String,
        prompt: String,
        negativePrompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        seed: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            completion(.failure(MediaAPIError("[\(provider.rawValue)] のAPIキーが未登録です。「外部API・Nanndemoya認証」タブから設定してください。")))
            return
        }

        switch provider {
        case .gemini:
            generateGeminiImage(modelId: modelId, apiKey: cleanKey, prompt: prompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        case .openAI:
            generateOpenAIImage(modelId: modelId, apiKey: cleanKey, prompt: prompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        case .stabilityAI:
            generateStabilityImage(modelId: modelId, apiKey: cleanKey, prompt: prompt, negativePrompt: negativePrompt, aspectRatio: aspectRatio, seed: seed, statusCallback: statusCallback, completion: completion)
        case .falAI:
            generateFalImage(modelId: modelId, apiKey: cleanKey, prompt: prompt, negativePrompt: negativePrompt, aspectRatio: aspectRatio, seed: seed, statusCallback: statusCallback, completion: completion)
        case .replicate:
            generateReplicateImage(modelId: modelId, apiKey: cleanKey, prompt: prompt, negativePrompt: negativePrompt, aspectRatio: aspectRatio, seed: seed, statusCallback: statusCallback, completion: completion)
        case .grok:
            generateGrokImage(modelId: modelId, apiKey: cleanKey, prompt: prompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        case .luma:
            generateLumaImage(modelId: modelId, apiKey: cleanKey, prompt: prompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        default:
            completion(.failure(MediaAPIError("プロバイダー \(provider.rawValue) は画像生成に対応していません。")))
        }
    }

    // MARK: - 2. Dedicated Video Generation
    public func generateVideo(
        provider: AIMediaProviderType,
        modelId: String,
        apiKey: String,
        prompt: String,
        negativePrompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            completion(.failure(MediaAPIError("[\(provider.rawValue)] のAPIキーが未登録です。「外部API・Nanndemoya認証」タブから設定してください。")))
            return
        }

        switch provider {
        case .gemini:
            generateGeminiVeoVideo(modelId: modelId, apiKey: cleanKey, prompt: prompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        case .openAI:
            generateOpenAISoraVideo(modelId: modelId, apiKey: cleanKey, prompt: prompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        case .falAI:
            generateFalVideo(modelId: modelId, apiKey: cleanKey, prompt: prompt, negativePrompt: negativePrompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        case .replicate:
            generateReplicateVideo(modelId: modelId, apiKey: cleanKey, prompt: prompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        case .runway:
            generateRunwayVideo(modelId: modelId, apiKey: cleanKey, prompt: prompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        case .luma:
            generateLumaVideo(modelId: modelId, apiKey: cleanKey, prompt: prompt, aspectRatio: aspectRatio, statusCallback: statusCallback, completion: completion)
        default:
            completion(.failure(MediaAPIError("プロバイダー \(provider.rawValue) は動画生成に対応していません。")))
        }
    }

    // MARK: - 3. Dedicated Audio (BGM & SE) Generation
    public func generateAudio(
        modality: AIMediaModality,
        provider: AIMediaProviderType,
        modelId: String,
        apiKey: String,
        prompt: String,
        durationSeconds: Double,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            completion(.failure(MediaAPIError("[\(provider.rawValue)] のAPIキーが未登録です。「外部API・Nanndemoya認証」タブから設定してください。")))
            return
        }

        switch provider {
        case .elevenLabs:
            if modality == .bgm {
                generateElevenLabsMusic(modelId: modelId, apiKey: cleanKey, prompt: prompt, durationSeconds: durationSeconds, statusCallback: statusCallback, completion: completion)
            } else {
                generateElevenLabsSE(modelId: modelId, apiKey: cleanKey, prompt: prompt, durationSeconds: durationSeconds, statusCallback: statusCallback, completion: completion)
            }
        case .stabilityAI:
            generateStabilityAudio(modality: modality, modelId: modelId, apiKey: cleanKey, prompt: prompt, durationSeconds: durationSeconds, statusCallback: statusCallback, completion: completion)
        case .falAI:
            generateFalAudio(modality: modality, modelId: modelId, apiKey: cleanKey, prompt: prompt, durationSeconds: durationSeconds, statusCallback: statusCallback, completion: completion)
        case .replicate:
            generateReplicateAudio(modality: modality, modelId: modelId, apiKey: cleanKey, prompt: prompt, durationSeconds: durationSeconds, statusCallback: statusCallback, completion: completion)
        default:
            completion(.failure(MediaAPIError("プロバイダー \(provider.rawValue) は\(modality.rawValue)生成に対応していません。")))
        }
    }

    // =========================================================================
    // MARK: - Provider Implementations: Google Gemini (Imagen 3/4, Flash Image, Veo)
    // =========================================================================

    private func generateGeminiImage(
        modelId: String,
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        var candidates: [String] = [modelId]
        for fallback in ["imagen-3.0-generate-002", "imagen-4.0-generate-001", "gemini-2.5-flash-image", "gemini-2.0-flash-exp-image-generation"] where !candidates.contains(fallback) {
            candidates.append(fallback)
        }
        tryGeminiImageCandidates(candidates: candidates, apiKey: apiKey, prompt: prompt, aspectRatio: aspectRatio, lastError: nil, statusCallback: statusCallback, completion: completion)
    }

    private func tryGeminiImageCandidates(
        candidates: [String],
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        lastError: String?,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        guard let currentModel = candidates.first else {
            completion(.failure(MediaAPIError(lastError ?? "Google Gemini 画像生成モデルへの接続に失敗しました。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("Google Gemini (\(currentModel)) で画像を生成中...")
        }

        let isGeminiMultimodal = currentModel.lowercased().hasPrefix("gemini-")
        let action = isGeminiMultimodal ? "generateContent" : "predict"
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(currentModel):\(action)") else {
            completion(.failure(MediaAPIError("無効なGeminiエンドポイントURLです。")))
            return
        }

        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let aspectStr = Self.aspectRatioString(aspectRatio)
        let body: [String: Any]
        if isGeminiMultimodal {
            body = [
                "contents": [
                    ["parts": [["text": "Generate a high quality anime illustration (\(aspectStr) aspect ratio): \(prompt)"]]]
                ],
                "generationConfig": [
                    "responseModalities": ["TEXT", "IMAGE"]
                ]
            ]
        } else {
            body = [
                "instances": [["prompt": prompt]],
                "parameters": [
                    "sampleCount": 1,
                    "aspectRatio": aspectStr
                ]
            ]
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let imgData = Self.extractGeminiImageBytes(from: json),
                   let saved = Self.saveImageData(imgData, prefix: "Gemini_\(currentModel)") {
                    completion(.success((saved.0, saved.1, "Google Gemini (\(currentModel))")))
                    return
                }
            }

            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            let remaining = Array(candidates.dropFirst())
            if !remaining.isEmpty && code != 401 {
                self?.tryGeminiImageCandidates(candidates: remaining, apiKey: apiKey, prompt: prompt, aspectRatio: aspectRatio, lastError: "\(currentModel): \(errMsg)", statusCallback: statusCallback, completion: completion)
            } else {
                completion(.failure(MediaAPIError("Google Gemini 画像生成エラー (\(currentModel)): \(errMsg)")))
            }
        }.resume()
    }

    private static func extractGeminiImageBytes(from json: [String: Any]) -> Data? {
        if let predictions = json["predictions"] as? [[String: Any]],
           let first = predictions.first,
           let b64 = first["bytesBase64Encoded"] as? String,
           let data = Data(base64Encoded: b64) {
            return data
        }
        if let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            for part in parts {
                if let inline = (part["inlineData"] as? [String: Any]) ?? (part["inline_data"] as? [String: Any]),
                   let b64 = inline["data"] as? String,
                   let data = Data(base64Encoded: b64) {
                    return data
                }
            }
        }
        return nil
    }

    private func generateGeminiVeoVideo(
        modelId: String,
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        var candidates: [String] = [modelId]
        for fb in ["veo-3.0-generate-preview", "veo-3.1-generate-preview", "veo-2.0-generate-001"] where !candidates.contains(fb) {
            candidates.append(fb)
        }
        tryGeminiVeoCandidates(candidates: candidates, apiKey: apiKey, prompt: prompt, aspectRatio: aspectRatio, lastError: nil, statusCallback: statusCallback, completion: completion)
    }

    private func tryGeminiVeoCandidates(
        candidates: [String],
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        lastError: String?,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        guard let currentModel = candidates.first else {
            completion(.failure(MediaAPIError(lastError ?? "Google Veo 動画生成モデルへの接続に失敗しました。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("Google Gemini (\(currentModel)) に動画生成ジョブを送信中...")
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(currentModel):predictLongRunning") else {
            completion(.failure(MediaAPIError("無効なVeoエンドポイントURLです。")))
            return
        }

        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let aspectStr = aspectRatio == .portrait9_16 ? "9:16" : "16:9"
        let body: [String: Any] = [
            "instances": [["prompt": prompt]],
            "parameters": ["aspectRatio": aspectStr]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let opName = json["name"] as? String, !opName.isEmpty {
                self?.pollGeminiVeoOperation(opName: opName, modelName: currentModel, apiKey: apiKey, attempt: 1, statusCallback: statusCallback, completion: completion)
                return
            }

            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            let remaining = Array(candidates.dropFirst())
            if !remaining.isEmpty && code != 401 {
                self?.tryGeminiVeoCandidates(candidates: remaining, apiKey: apiKey, prompt: prompt, aspectRatio: aspectRatio, lastError: "\(currentModel): \(errMsg)", statusCallback: statusCallback, completion: completion)
            } else {
                completion(.failure(MediaAPIError("Google Veo 動画生成エラー (\(currentModel)): \(errMsg)")))
            }
        }.resume()
    }

    private func pollGeminiVeoOperation(
        opName: String,
        modelName: String,
        apiKey: String,
        attempt: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        if attempt > 60 {
            completion(.failure(MediaAPIError("Google Veo 動画生成がタイムアウトしました。")))
            return
        }

        let cleanOp = opName.hasPrefix("/") ? String(opName.dropFirst()) : opName
        guard let pollURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/\(cleanOp)") else {
            completion(.failure(MediaAPIError("Veo オペレーション確認URLが不正です。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("Google \(modelName) 動画レンダリング待機中... (\(attempt * 4)秒経過)")
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 4.0) { [weak self] in
            var req = URLRequest(url: pollURL, timeoutInterval: 30)
            req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

            URLSession.shared.dataTask(with: req) { data, response, error in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard code == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
                    completion(.failure(MediaAPIError("Veo ポーリングエラー: \(errMsg)")))
                    return
                }

                if let errObj = json["error"] as? [String: Any] {
                    let msg = (errObj["message"] as? String) ?? "Veo ジョブ失敗"
                    completion(.failure(MediaAPIError("Google Veo エラー: \(msg)")))
                    return
                }

                let isDone = (json["done"] as? Bool) ?? false
                if !isDone {
                    self?.pollGeminiVeoOperation(opName: opName, modelName: modelName, apiKey: apiKey, attempt: attempt + 1, statusCallback: statusCallback, completion: completion)
                    return
                }

                // Extract video URI or base64
                if let resp = json["response"] as? [String: Any] {
                    var videoURI: String? = nil
                    if let genResp = resp["generateVideoResponse"] as? [String: Any],
                       let samples = genResp["generatedSamples"] as? [[String: Any]],
                       let vid = samples.first?["video"] as? [String: Any] {
                        videoURI = vid["uri"] as? String
                        if let b64 = vid["bytesBase64Encoded"] as? String, let bin = Data(base64Encoded: b64),
                           let saved = Self.saveVideoData(bin, prefix: "Veo") {
                            completion(.success((saved.0, saved.1, "Google Gemini (\(modelName))")))
                            return
                        }
                    } else if let videos = resp["videos"] as? [[String: Any]], let first = videos.first {
                        videoURI = first["uri"] as? String
                        if let b64 = first["bytesBase64Encoded"] as? String, let bin = Data(base64Encoded: b64),
                           let saved = Self.saveVideoData(bin, prefix: "Veo") {
                            completion(.success((saved.0, saved.1, "Google Gemini (\(modelName))")))
                            return
                        }
                    }

                    if let uriStr = videoURI, let dlURL = URL(string: uriStr) {
                        var dlReq = URLRequest(url: dlURL, timeoutInterval: 120)
                        dlReq.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                        Self.downloadVideoRequest(dlReq, prefix: "Veo", engineLabel: "Google Gemini (\(modelName))", completion: completion)
                        return
                    }
                }

                completion(.failure(MediaAPIError("Google Veo から動画データを取得できませんでした。")))
            }.resume()
        }
    }

    // =========================================================================
    // MARK: - Provider Implementations: OpenAI (GPT Image 1, DALL-E 3, Sora 2)
    // =========================================================================

    private func generateOpenAIImage(
        modelId: String,
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        let candidates = modelId == "dall-e-3" ? ["dall-e-3", "gpt-image-1"] : ["gpt-image-1", "dall-e-3"]
        tryOpenAIImageCandidates(candidates: candidates, apiKey: apiKey, prompt: prompt, aspectRatio: aspectRatio, lastError: nil, statusCallback: statusCallback, completion: completion)
    }

    private func tryOpenAIImageCandidates(
        candidates: [String],
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        lastError: String?,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        guard let currentModel = candidates.first,
              let url = URL(string: "https://api.openai.com/v1/images/generations") else {
            completion(.failure(MediaAPIError(lastError ?? "OpenAI 画像生成APIへの接続に失敗しました。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("OpenAI (\(currentModel)) で画像を生成中...")
        }

        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": currentModel,
            "prompt": prompt,
            "n": 1
        ]
        if currentModel == "gpt-image-1" {
            let sizeStr = aspectRatio == .portrait9_16 ? "1024x1536" : (aspectRatio == .square1_1 ? "1024x1024" : "1536x1024")
            body["size"] = sizeStr
        } else {
            let sizeStr = aspectRatio == .portrait9_16 ? "1024x1792" : (aspectRatio == .square1_1 ? "1024x1024" : "1792x1024")
            body["size"] = sizeStr
            body["response_format"] = "b64_json"
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = json["data"] as? [[String: Any]], let first = arr.first {
                if let b64 = first["b64_json"] as? String,
                   let imgData = Data(base64Encoded: b64),
                   let saved = Self.saveImageData(imgData, prefix: "OpenAI_\(currentModel)") {
                    completion(.success((saved.0, saved.1, "OpenAI (\(currentModel))")))
                    return
                }
                if let urlStr = first["url"] as? String, let imgURL = URL(string: urlStr) {
                    Self.downloadImageURL(imgURL, prefix: "OpenAI_\(currentModel)", engineLabel: "OpenAI (\(currentModel))", completion: completion)
                    return
                }
            }

            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            let remaining = Array(candidates.dropFirst())
            if !remaining.isEmpty && code != 401 {
                self?.tryOpenAIImageCandidates(candidates: remaining, apiKey: apiKey, prompt: prompt, aspectRatio: aspectRatio, lastError: "\(currentModel): \(errMsg)", statusCallback: statusCallback, completion: completion)
            } else {
                completion(.failure(MediaAPIError("OpenAI 画像生成エラー (\(currentModel)): \(errMsg)")))
            }
        }.resume()
    }

    private func generateOpenAISoraVideo(
        modelId: String,
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.openai.com/v1/videos") else {
            completion(.failure(MediaAPIError("無効なOpenAI VideosエンドポイントURLです。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("OpenAI (\(modelId)) に動画生成ジョブを送信中...")
        }

        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let sizeStr = aspectRatio == .portrait9_16 ? "720x1280" : "1280x720"
        let body: [String: Any] = [
            "model": modelId,
            "prompt": prompt,
            "seconds": "4",
            "size": sizeStr
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (code == 200 || code == 201 || code == 202),
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let videoId = json["id"] as? String, !videoId.isEmpty {
                self?.pollOpenAISoraVideo(videoId: videoId, modelId: modelId, apiKey: apiKey, attempt: 1, statusCallback: statusCallback, completion: completion)
                return
            }
            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            completion(.failure(MediaAPIError("OpenAI Sora 動画生成エラー (\(modelId)): \(errMsg)")))
        }.resume()
    }

    private func pollOpenAISoraVideo(
        videoId: String,
        modelId: String,
        apiKey: String,
        attempt: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        if attempt > 60 {
            completion(.failure(MediaAPIError("OpenAI Sora 動画生成がタイムアウトしました。")))
            return
        }

        guard let pollURL = URL(string: "https://api.openai.com/v1/videos/\(videoId)") else {
            completion(.failure(MediaAPIError("Sora ステータス確認URLが不正です。")))
            return
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 4.0) { [weak self] in
            var req = URLRequest(url: pollURL, timeoutInterval: 30)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req) { data, response, error in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard code == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
                    completion(.failure(MediaAPIError("OpenAI Sora ステータス確認エラー: \(errMsg)")))
                    return
                }

                let status = ((json["status"] as? String) ?? "").lowercased()
                let progress = (json["progress"] as? Int) ?? min(95, attempt * 5)
                DispatchQueue.main.async {
                    statusCallback("OpenAI \(modelId) 動画生成中... (\(progress)%)")
                }

                if status == "completed" || status == "succeeded" {
                    if let contentURL = URL(string: "https://api.openai.com/v1/videos/\(videoId)/content") {
                        var dlReq = URLRequest(url: contentURL, timeoutInterval: 120)
                        dlReq.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                        Self.downloadVideoRequest(dlReq, prefix: "Sora", engineLabel: "OpenAI (\(modelId))", completion: completion)
                    } else {
                        completion(.failure(MediaAPIError("Sora 動画ダウンロードURLの構築に失敗しました。")))
                    }
                } else if status == "failed" || status == "cancelled" {
                    let errObj = json["error"] as? [String: Any]
                    let msg = (errObj?["message"] as? String) ?? "ジョブが失敗しました (\(status))"
                    completion(.failure(MediaAPIError("OpenAI Sora エラー: \(msg)")))
                } else {
                    self?.pollOpenAISoraVideo(videoId: videoId, modelId: modelId, apiKey: apiKey, attempt: attempt + 1, statusCallback: statusCallback, completion: completion)
                }
            }.resume()
        }
    }

    // =========================================================================
    // MARK: - Provider Implementations: xAI Grok Image
    // =========================================================================

    private func generateGrokImage(
        modelId: String,
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        var candidates: [String] = [modelId]
        for fb in ["grok-imagine-image-2.0", "grok-2-image-1212"] where !candidates.contains(fb) {
            candidates.append(fb)
        }
        tryGrokImageCandidates(candidates: candidates, apiKey: apiKey, prompt: prompt, aspectRatio: aspectRatio, lastError: nil, statusCallback: statusCallback, completion: completion)
    }

    private func tryGrokImageCandidates(
        candidates: [String],
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        lastError: String?,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        guard let currentModel = candidates.first,
              let url = URL(string: "https://api.x.ai/v1/images/generations") else {
            completion(.failure(MediaAPIError(lastError ?? "xAI Grok 画像生成APIへの接続に失敗しました。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("xAI Grok (\(currentModel)) で画像を生成中...")
        }

        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": currentModel,
            "prompt": prompt,
            "n": 1
        ]
        if currentModel.contains("imagine") {
            body["aspect_ratio"] = Self.aspectRatioString(aspectRatio)
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = json["data"] as? [[String: Any]], let first = arr.first {
                if let b64 = first["b64_json"] as? String,
                   let imgData = Data(base64Encoded: b64),
                   let saved = Self.saveImageData(imgData, prefix: "Grok") {
                    completion(.success((saved.0, saved.1, "xAI Grok (\(currentModel))")))
                    return
                }
                if let urlStr = first["url"] as? String, let imgURL = URL(string: urlStr) {
                    Self.downloadImageURL(imgURL, prefix: "Grok", engineLabel: "xAI Grok (\(currentModel))", completion: completion)
                    return
                }
            }

            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            let remaining = Array(candidates.dropFirst())
            if !remaining.isEmpty && code != 401 {
                self?.tryGrokImageCandidates(candidates: remaining, apiKey: apiKey, prompt: prompt, aspectRatio: aspectRatio, lastError: "\(currentModel): \(errMsg)", statusCallback: statusCallback, completion: completion)
            } else {
                completion(.failure(MediaAPIError("xAI Grok 画像生成エラー (\(currentModel)): \(errMsg)")))
            }
        }.resume()
    }

    // =========================================================================
    // MARK: - Provider Implementations: ElevenLabs (Sound Effects & Music)
    // =========================================================================

    private func generateElevenLabsSE(
        modelId: String,
        apiKey: String,
        prompt: String,
        durationSeconds: Double,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        var candidates: [String] = [modelId]
        for fb in ["eleven_text_to_sound_v3", "eleven_text_to_sound_v2"] where !candidates.contains(fb) {
            candidates.append(fb)
        }
        tryElevenLabsSECandidates(candidates: candidates, apiKey: apiKey, prompt: prompt, durationSeconds: durationSeconds, lastError: nil, statusCallback: statusCallback, completion: completion)
    }

    private func tryElevenLabsSECandidates(
        candidates: [String],
        apiKey: String,
        prompt: String,
        durationSeconds: Double,
        lastError: String?,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        guard let currentModel = candidates.first,
              let url = URL(string: "https://api.elevenlabs.io/v1/sound-generation") else {
            completion(.failure(MediaAPIError(lastError ?? "ElevenLabs 効果音APIへの接続に失敗しました。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("ElevenLabs (\(currentModel)) で効果音(SE)を生成中...")
        }

        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let clampedDuration = min(22.0, max(0.5, durationSeconds))
        let body: [String: Any] = [
            "text": prompt,
            "model_id": currentModel,
            "duration_seconds": clampedDuration,
            "prompt_influence": 0.4
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let data = data, data.count > 500,
               let savedURL = Self.saveAudioData(data, prefix: "ElevenLabs_SE", ext: "mp3") {
                completion(.success((savedURL, "ElevenLabs (\(currentModel))")))
                return
            }

            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            let remaining = Array(candidates.dropFirst())
            if !remaining.isEmpty && code != 401 {
                self?.tryElevenLabsSECandidates(candidates: remaining, apiKey: apiKey, prompt: prompt, durationSeconds: durationSeconds, lastError: "\(currentModel): \(errMsg)", statusCallback: statusCallback, completion: completion)
            } else {
                completion(.failure(MediaAPIError("ElevenLabs SE生成エラー: \(errMsg)")))
            }
        }.resume()
    }

    private func generateElevenLabsMusic(
        modelId: String,
        apiKey: String,
        prompt: String,
        durationSeconds: Double,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        var candidates: [String] = [modelId]
        for fb in ["music_v2_5", "music_v1"] where !candidates.contains(fb) {
            candidates.append(fb)
        }
        tryElevenLabsMusicCandidates(candidates: candidates, apiKey: apiKey, prompt: prompt, durationSeconds: durationSeconds, lastError: nil, statusCallback: statusCallback, completion: completion)
    }

    private func tryElevenLabsMusicCandidates(
        candidates: [String],
        apiKey: String,
        prompt: String,
        durationSeconds: Double,
        lastError: String?,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        guard let currentModel = candidates.first,
              let url = URL(string: "https://api.elevenlabs.io/v1/music") else {
            completion(.failure(MediaAPIError(lastError ?? "ElevenLabs Music APIへの接続に失敗しました。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("ElevenLabs (\(currentModel)) でBGMを作曲中...")
        }

        var req = URLRequest(url: url, timeoutInterval: 150)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let lengthMs = Int(min(180.0, max(5.0, durationSeconds)) * 1000.0)
        let body: [String: Any] = [
            "prompt": prompt,
            "model_id": currentModel,
            "music_length_ms": lengthMs,
            "force_instrumental": true
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let data = data, data.count > 1000,
               let savedURL = Self.saveAudioData(data, prefix: "ElevenLabs_BGM", ext: "mp3") {
                completion(.success((savedURL, "ElevenLabs (\(currentModel))")))
                return
            }

            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            let remaining = Array(candidates.dropFirst())
            if !remaining.isEmpty && code != 401 {
                self?.tryElevenLabsMusicCandidates(candidates: remaining, apiKey: apiKey, prompt: prompt, durationSeconds: durationSeconds, lastError: "\(currentModel): \(errMsg)", statusCallback: statusCallback, completion: completion)
            } else {
                completion(.failure(MediaAPIError("ElevenLabs BGM生成エラー: \(errMsg)")))
            }
        }.resume()
    }

    // =========================================================================
    // MARK: - Provider Implementations: Stability AI (Stable Image & Stable Audio 2.0)
    // =========================================================================

    private func generateStabilityImage(
        modelId: String,
        apiKey: String,
        prompt: String,
        negativePrompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        seed: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        let endpointTier = modelId.hasPrefix("sd3") ? "sd3" : (modelId == "ultra" ? "ultra" : "core")
        guard let url = URL(string: "https://api.stability.ai/v2beta/stable-image/generate/\(endpointTier)") else {
            completion(.failure(MediaAPIError("無効なStability AI URLです。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("Stability AI (\(modelId)) で画像を生成中...")
        }

        var fields: [(String, String)] = [
            ("prompt", prompt),
            ("aspect_ratio", Self.aspectRatioString(aspectRatio)),
            ("output_format", "png")
        ]
        if !negativePrompt.isEmpty {
            fields.append(("negative_prompt", AIImageGeneratorService.convertNegativePromptToEnglish(negativePrompt)))
        }
        if seed > 0 {
            fields.append(("seed", "\(seed)"))
        }
        if endpointTier == "sd3" {
            fields.append(("model", modelId))
        }

        let boundary = "StabilityBoundary-\(UUID().uuidString)"
        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("image/*", forHTTPHeaderField: "Accept")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.buildMultipartBody(fields: fields, boundary: boundary)

        URLSession.shared.dataTask(with: req) { data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let data = data, data.count > 1000,
               let saved = Self.saveImageData(data, prefix: "Stability_\(endpointTier)") {
                completion(.success((saved.0, saved.1, "Stability AI (\(modelId))")))
                return
            }
            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            completion(.failure(MediaAPIError("Stability AI 画像生成エラー: \(errMsg)")))
        }.resume()
    }

    private func generateStabilityAudio(
        modality: AIMediaModality,
        modelId: String,
        apiKey: String,
        prompt: String,
        durationSeconds: Double,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.stability.ai/v2beta/audio/stable-audio-2/text-to-audio") else {
            completion(.failure(MediaAPIError("無効なStable Audio URLです。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("Stability AI (Stable Audio 2.0) で\(modality.rawValue)を生成中...")
        }

        let clampedSec = Int(min(180.0, max(1.0, round(durationSeconds))))
        let fields: [(String, String)] = [
            ("prompt", prompt),
            ("duration", "\(clampedSec)"),
            ("output_format", "wav")
        ]

        let boundary = "StabilityAudio-\(UUID().uuidString)"
        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("audio/*", forHTTPHeaderField: "Accept")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.buildMultipartBody(fields: fields, boundary: boundary)

        URLSession.shared.dataTask(with: req) { data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let data = data, data.count > 1000,
               let savedURL = Self.saveAudioData(data, prefix: "StableAudio_\(modality == .bgm ? "BGM" : "SE")", ext: "wav") {
                completion(.success((savedURL, "Stability AI (Stable Audio 2.0)")))
                return
            }
            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            completion(.failure(MediaAPIError("Stable Audio 2.0 エラー: \(errMsg)")))
        }.resume()
    }

    // =========================================================================
    // MARK: - Provider Implementations: fal.ai Queue / Sync API
    // =========================================================================

    private func generateFalImage(
        modelId: String,
        apiKey: String,
        prompt: String,
        negativePrompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        seed: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        let imageSize: String
        switch aspectRatio {
        case .landscape16_9: imageSize = "landscape_16_9"
        case .square1_1: imageSize = "square_hd"
        case .portrait9_16: imageSize = "portrait_16_9"
        }

        var payload: [String: Any] = [
            "prompt": prompt,
            "image_size": imageSize
        ]
        if !negativePrompt.isEmpty {
            payload["negative_prompt"] = AIImageGeneratorService.convertNegativePromptToEnglish(negativePrompt)
        }
        if seed > 0 {
            payload["seed"] = seed
        }

        submitAndPollFalJob(modelId: modelId, apiKey: apiKey, payload: payload, statusCallback: statusCallback) { result in
            switch result {
            case .success(let mediaURL):
                Self.downloadImageURL(mediaURL, prefix: "FalAI", engineLabel: "fal.ai (\(modelId))", completion: completion)
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func generateFalVideo(
        modelId: String,
        apiKey: String,
        prompt: String,
        negativePrompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        var payload: [String: Any] = [
            "prompt": prompt,
            "aspect_ratio": Self.aspectRatioString(aspectRatio)
        ]
        if !negativePrompt.isEmpty {
            payload["negative_prompt"] = AIImageGeneratorService.convertNegativePromptToEnglish(negativePrompt)
        }

        submitAndPollFalJob(modelId: modelId, apiKey: apiKey, payload: payload, statusCallback: statusCallback) { result in
            switch result {
            case .success(let mediaURL):
                Self.downloadVideoRequest(URLRequest(url: mediaURL, timeoutInterval: 120), prefix: "FalAI_Video", engineLabel: "fal.ai (\(modelId))", completion: completion)
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func generateFalAudio(
        modality: AIMediaModality,
        modelId: String,
        apiKey: String,
        prompt: String,
        durationSeconds: Double,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        let clampedSec = max(1, Int(round(durationSeconds)))
        let payload: [String: Any] = [
            "prompt": prompt,
            "duration": clampedSec,
            "seconds_total": clampedSec
        ]

        submitAndPollFalJob(modelId: modelId, apiKey: apiKey, payload: payload, statusCallback: statusCallback) { result in
            switch result {
            case .success(let mediaURL):
                Self.downloadAudioURL(mediaURL, prefix: "FalAI_\(modality == .bgm ? "BGM" : "SE")", engineLabel: "fal.ai (\(modelId))", completion: completion)
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func submitAndPollFalJob(
        modelId: String,
        apiKey: String,
        payload: [String: Any],
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let submitURL = URL(string: "https://queue.fal.run/\(modelId)") else {
            completion(.failure(MediaAPIError("無効なfal.aiモデルパスです: \(modelId)")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("fal.ai (\(modelId)) へリクエスト送信中...")
        }

        var req = URLRequest(url: submitURL, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...202).contains(code), let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
                completion(.failure(MediaAPIError("fal.ai エラー (\(modelId)): \(errMsg)")))
                return
            }

            // If synchronous result already contains output URL
            if let directURL = Self.extractMediaURL(from: json) {
                completion(.success(directURL))
                return
            }

            guard let statusURLStr = json["status_url"] as? String,
                  let statusURL = URL(string: statusURLStr),
                  let responseURLStr = json["response_url"] as? String,
                  let responseURL = URL(string: responseURLStr) else {
                completion(.failure(MediaAPIError("fal.ai キュー応答の解析に失敗しました。")))
                return
            }

            self?.pollFalQueue(statusURL: statusURL, responseURL: responseURL, modelId: modelId, apiKey: apiKey, attempt: 1, statusCallback: statusCallback, completion: completion)
        }.resume()
    }

    private func pollFalQueue(
        statusURL: URL,
        responseURL: URL,
        modelId: String,
        apiKey: String,
        attempt: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if attempt > 75 {
            completion(.failure(MediaAPIError("fal.ai (\(modelId)) の処理がタイムアウトしました。")))
            return
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.5) { [weak self] in
            var req = URLRequest(url: statusURL, timeoutInterval: 30)
            req.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req) { data, response, error in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard code == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
                    completion(.failure(MediaAPIError("fal.ai ステータス取得エラー: \(errMsg)")))
                    return
                }

                let status = (json["status"] as? String) ?? ""
                DispatchQueue.main.async {
                    statusCallback("fal.ai (\(modelId)) 生成中... [\(status)]")
                }

                if status == "COMPLETED" {
                    var resReq = URLRequest(url: responseURL, timeoutInterval: 60)
                    resReq.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
                    URLSession.shared.dataTask(with: resReq) { rData, rRes, rErr in
                        let rCode = (rRes as? HTTPURLResponse)?.statusCode ?? 0
                        if rCode == 200, let rData = rData,
                           let rJson = try? JSONSerialization.jsonObject(with: rData) as? [String: Any],
                           let mediaURL = Self.extractMediaURL(from: rJson) {
                            completion(.success(mediaURL))
                        } else {
                            let errMsg = Self.extractErrorText(data: rData, statusCode: rCode, error: rErr)
                            completion(.failure(MediaAPIError("fal.ai 結果取得エラー: \(errMsg)")))
                        }
                    }.resume()
                } else if status == "FAILED" || status == "ERROR" {
                    completion(.failure(MediaAPIError("fal.ai 生成ジョブが失敗しました。")))
                } else {
                    self?.pollFalQueue(statusURL: statusURL, responseURL: responseURL, modelId: modelId, apiKey: apiKey, attempt: attempt + 1, statusCallback: statusCallback, completion: completion)
                }
            }.resume()
        }
    }

    // =========================================================================
    // MARK: - Provider Implementations: Replicate API
    // =========================================================================

    private func generateReplicateImage(
        modelId: String,
        apiKey: String,
        prompt: String,
        negativePrompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        seed: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        var input: [String: Any] = [
            "prompt": prompt,
            "aspect_ratio": Self.aspectRatioString(aspectRatio)
        ]
        if !negativePrompt.isEmpty {
            input["negative_prompt"] = AIImageGeneratorService.convertNegativePromptToEnglish(negativePrompt)
        }
        if seed > 0 {
            input["seed"] = seed
        }

        runReplicatePrediction(modelId: modelId, apiKey: apiKey, input: input, statusCallback: statusCallback) { result in
            switch result {
            case .success(let mediaURL):
                Self.downloadImageURL(mediaURL, prefix: "Replicate", engineLabel: "Replicate (\(modelId))", completion: completion)
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func generateReplicateVideo(
        modelId: String,
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        let input: [String: Any] = [
            "prompt": prompt,
            "aspect_ratio": Self.aspectRatioString(aspectRatio)
        ]

        runReplicatePrediction(modelId: modelId, apiKey: apiKey, input: input, statusCallback: statusCallback) { result in
            switch result {
            case .success(let mediaURL):
                Self.downloadVideoRequest(URLRequest(url: mediaURL, timeoutInterval: 120), prefix: "Replicate_Video", engineLabel: "Replicate (\(modelId))", completion: completion)
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func generateReplicateAudio(
        modality: AIMediaModality,
        modelId: String,
        apiKey: String,
        prompt: String,
        durationSeconds: Double,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        var input: [String: Any] = [
            "prompt": prompt,
            "duration": max(1, Int(round(durationSeconds)))
        ]
        if modelId.contains("musicgen") {
            input["model_version"] = "stereo-large"
            input["output_format"] = "wav"
        }

        runReplicatePrediction(modelId: modelId, apiKey: apiKey, input: input, statusCallback: statusCallback) { result in
            switch result {
            case .success(let mediaURL):
                Self.downloadAudioURL(mediaURL, prefix: "Replicate_\(modality == .bgm ? "BGM" : "SE")", engineLabel: "Replicate (\(modelId))", completion: completion)
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func runReplicatePrediction(
        modelId: String,
        apiKey: String,
        input: [String: Any],
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.replicate.com/v1/models/\(modelId)/predictions") else {
            completion(.failure(MediaAPIError("無効なReplicateモデル指定です: \(modelId)")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("Replicate (\(modelId)) で推論を実行中...")
        }

        var req = URLRequest(url: url, timeoutInterval: 65)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("wait=50", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["input": input])

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0

            // Community models without official deployment endpoint require latest_version ID via /v1/predictions
            if code == 404 {
                self?.runReplicateVersionedPrediction(modelId: modelId, apiKey: apiKey, input: input, statusCallback: statusCallback, completion: completion)
                return
            }

            self?.handleReplicatePredictionResponse(data: data, statusCode: code, error: error, modelId: modelId, apiKey: apiKey, statusCallback: statusCallback, completion: completion)
        }.resume()
    }

    private func runReplicateVersionedPrediction(
        modelId: String,
        apiKey: String,
        input: [String: Any],
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let infoURL = URL(string: "https://api.replicate.com/v1/models/\(modelId)") else {
            completion(.failure(MediaAPIError("Replicate モデル取得URLが不正です。")))
            return
        }

        var infoReq = URLRequest(url: infoURL, timeoutInterval: 20)
        infoReq.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: infoReq) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let latest = json["latest_version"] as? [String: Any],
                  let versionId = latest["id"] as? String,
                  let predURL = URL(string: "https://api.replicate.com/v1/predictions") else {
                let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
                completion(.failure(MediaAPIError("Replicate モデルバージョン解決エラー (\(modelId)): \(errMsg)")))
                return
            }

            var req = URLRequest(url: predURL, timeoutInterval: 65)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("wait=50", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "version": versionId,
                "input": input
            ])

            URLSession.shared.dataTask(with: req) { pData, pRes, pErr in
                let pCode = (pRes as? HTTPURLResponse)?.statusCode ?? 0
                self?.handleReplicatePredictionResponse(data: pData, statusCode: pCode, error: pErr, modelId: modelId, apiKey: apiKey, statusCallback: statusCallback, completion: completion)
            }.resume()
        }.resume()
    }

    private func handleReplicatePredictionResponse(
        data: Data?,
        statusCode: Int,
        error: Error?,
        modelId: String,
        apiKey: String,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard (200...202).contains(statusCode), let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let errMsg = Self.extractErrorText(data: data, statusCode: statusCode, error: error)
            completion(.failure(MediaAPIError("Replicate エラー (\(modelId)): \(errMsg)")))
            return
        }

        let status = (json["status"] as? String) ?? ""
        if status == "succeeded" {
            if let outURL = Self.extractReplicateOutputURL(from: json) {
                completion(.success(outURL))
            } else {
                completion(.failure(MediaAPIError("Replicate の出力URLを取得できませんでした。")))
            }
            return
        }
        if status == "failed" || status == "canceled" {
            let errStr = (json["error"] as? String) ?? "推論ジョブが失敗しました"
            completion(.failure(MediaAPIError("Replicate 失敗: \(errStr)")))
            return
        }

        if let urls = json["urls"] as? [String: Any],
           let getStr = urls["get"] as? String,
           let getURL = URL(string: getStr) {
            pollReplicatePrediction(getURL: getURL, modelId: modelId, apiKey: apiKey, attempt: 1, statusCallback: statusCallback, completion: completion)
        } else {
            completion(.failure(MediaAPIError("Replicate ポーリングURLが見つかりません。")))
        }
    }

    private func pollReplicatePrediction(
        getURL: URL,
        modelId: String,
        apiKey: String,
        attempt: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if attempt > 70 {
            completion(.failure(MediaAPIError("Replicate (\(modelId)) がタイムアウトしました。")))
            return
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.0) { [weak self] in
            var req = URLRequest(url: getURL, timeoutInterval: 30)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req) { data, response, error in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard code == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
                    completion(.failure(MediaAPIError("Replicate ポーリングエラー: \(errMsg)")))
                    return
                }

                let status = (json["status"] as? String) ?? ""
                DispatchQueue.main.async {
                    statusCallback("Replicate (\(modelId)) 生成中... [\(status)]")
                }

                if status == "succeeded" {
                    if let outURL = Self.extractReplicateOutputURL(from: json) {
                        completion(.success(outURL))
                    } else {
                        completion(.failure(MediaAPIError("Replicate の出力URLが空でした。")))
                    }
                } else if status == "failed" || status == "canceled" {
                    let errStr = (json["error"] as? String) ?? "ジョブ失敗"
                    completion(.failure(MediaAPIError("Replicate 失敗: \(errStr)")))
                } else {
                    self?.pollReplicatePrediction(getURL: getURL, modelId: modelId, apiKey: apiKey, attempt: attempt + 1, statusCallback: statusCallback, completion: completion)
                }
            }.resume()
        }
    }

    // =========================================================================
    // MARK: - Provider Implementations: Runway API (Text-to-Video)
    // =========================================================================

    private func generateRunwayVideo(
        modelId: String,
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.dev.runwayml.com/v1/text_to_video") else {
            completion(.failure(MediaAPIError("無効なRunway API URLです。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("Runway (\(modelId)) に動画生成タスクを送信中...")
        }

        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("2024-11-06", forHTTPHeaderField: "X-Runway-Version")

        let ratioStr: String
        switch aspectRatio {
        case .landscape16_9: ratioStr = "1280:720"
        case .portrait9_16: ratioStr = "720:1280"
        case .square1_1: ratioStr = "960:960"
        }

        let body: [String: Any] = [
            "model": modelId,
            "promptText": prompt,
            "duration": 5,
            "ratio": ratioStr
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...202).contains(code), let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let taskId = json["id"] as? String, !taskId.isEmpty {
                self?.pollRunwayTask(taskId: taskId, modelId: modelId, apiKey: apiKey, attempt: 1, statusCallback: statusCallback, completion: completion)
                return
            }
            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            completion(.failure(MediaAPIError("Runway 動画生成エラー (\(modelId)): \(errMsg)")))
        }.resume()
    }

    private func pollRunwayTask(
        taskId: String,
        modelId: String,
        apiKey: String,
        attempt: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        if attempt > 65 {
            completion(.failure(MediaAPIError("Runway 動画生成がタイムアウトしました。")))
            return
        }

        guard let url = URL(string: "https://api.dev.runwayml.com/v1/tasks/\(taskId)") else {
            completion(.failure(MediaAPIError("Runway タスク確認URLが不正です。")))
            return
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 4.0) { [weak self] in
            var req = URLRequest(url: url, timeoutInterval: 30)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("2024-11-06", forHTTPHeaderField: "X-Runway-Version")

            URLSession.shared.dataTask(with: req) { data, response, error in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard code == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
                    completion(.failure(MediaAPIError("Runway タスク確認エラー: \(errMsg)")))
                    return
                }

                let status = ((json["status"] as? String) ?? "").uppercased()
                DispatchQueue.main.async {
                    statusCallback("Runway (\(modelId)) 動画レンダリング中... [\(status)]")
                }

                if status == "SUCCEEDED" {
                    if let outputs = json["output"] as? [String], let first = outputs.first, let dlURL = URL(string: first) {
                        Self.downloadVideoRequest(URLRequest(url: dlURL, timeoutInterval: 120), prefix: "Runway", engineLabel: "Runway (\(modelId))", completion: completion)
                    } else {
                        completion(.failure(MediaAPIError("Runway の出力動画URLを取得できませんでした。")))
                    }
                } else if status == "FAILED" || status == "CANCELLED" {
                    let failure = (json["failure"] as? String) ?? "Runway タスク失敗"
                    completion(.failure(MediaAPIError("Runway エラー: \(failure)")))
                } else {
                    self?.pollRunwayTask(taskId: taskId, modelId: modelId, apiKey: apiKey, attempt: attempt + 1, statusCallback: statusCallback, completion: completion)
                }
            }.resume()
        }
    }

    // =========================================================================
    // MARK: - Provider Implementations: Luma Dream Machine (Photon & Ray 2)
    // =========================================================================

    private func generateLumaImage(
        modelId: String,
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        let body: [String: Any] = [
            "model": modelId,
            "prompt": prompt,
            "aspect_ratio": Self.aspectRatioString(aspectRatio)
        ]
        submitAndPollLumaGeneration(endpoint: "https://api.lumalabs.ai/dream-machine/v1/generations/image", modelId: modelId, apiKey: apiKey, body: body, assetKey: "image", statusCallback: statusCallback) { result in
            switch result {
            case .success(let mediaURL):
                Self.downloadImageURL(mediaURL, prefix: "LumaPhoton", engineLabel: "Luma (\(modelId))", completion: completion)
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func generateLumaVideo(
        modelId: String,
        apiKey: String,
        prompt: String,
        aspectRatio: AIImageGeneratorService.ImageAspectRatio,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        let body: [String: Any] = [
            "model": modelId,
            "prompt": prompt,
            "aspect_ratio": Self.aspectRatioString(aspectRatio),
            "resolution": "720p",
            "duration": "5s"
        ]
        submitAndPollLumaGeneration(endpoint: "https://api.lumalabs.ai/dream-machine/v1/generations", modelId: modelId, apiKey: apiKey, body: body, assetKey: "video", statusCallback: statusCallback) { result in
            switch result {
            case .success(let mediaURL):
                Self.downloadVideoRequest(URLRequest(url: mediaURL, timeoutInterval: 120), prefix: "LumaRay", engineLabel: "Luma (\(modelId))", completion: completion)
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func submitAndPollLumaGeneration(
        endpoint: String,
        modelId: String,
        apiKey: String,
        body: [String: Any],
        assetKey: String,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            completion(.failure(MediaAPIError("無効なLuma API URLです。")))
            return
        }

        DispatchQueue.main.async {
            statusCallback("Luma Labs (\(modelId)) にリクエスト送信中...")
        }

        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...202).contains(code), let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let genId = json["id"] as? String, !genId.isEmpty {
                self?.pollLumaGeneration(genId: genId, modelId: modelId, apiKey: apiKey, assetKey: assetKey, attempt: 1, statusCallback: statusCallback, completion: completion)
                return
            }
            let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
            completion(.failure(MediaAPIError("Luma Labs エラー (\(modelId)): \(errMsg)")))
        }.resume()
    }

    private func pollLumaGeneration(
        genId: String,
        modelId: String,
        apiKey: String,
        assetKey: String,
        attempt: Int,
        statusCallback: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if attempt > 65 {
            completion(.failure(MediaAPIError("Luma (\(modelId)) 生成がタイムアウトしました。")))
            return
        }

        guard let pollURL = URL(string: "https://api.lumalabs.ai/dream-machine/v1/generations/\(genId)") else {
            completion(.failure(MediaAPIError("Luma ポーリングURLが不正です。")))
            return
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.5) { [weak self] in
            var req = URLRequest(url: pollURL, timeoutInterval: 30)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: req) { data, response, error in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard code == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let errMsg = Self.extractErrorText(data: data, statusCode: code, error: error)
                    completion(.failure(MediaAPIError("Luma ポーリングエラー: \(errMsg)")))
                    return
                }

                let state = ((json["state"] as? String) ?? "").lowercased()
                DispatchQueue.main.async {
                    statusCallback("Luma (\(modelId)) 生成中... [\(state)]")
                }

                if state == "completed" {
                    if let assets = json["assets"] as? [String: Any],
                       let urlStr = assets[assetKey] as? String,
                       let mediaURL = URL(string: urlStr) {
                        completion(.success(mediaURL))
                    } else {
                        completion(.failure(MediaAPIError("Luma アセットURLが見つかりませんでした。")))
                    }
                } else if state == "failed" {
                    let reason = (json["failure_reason"] as? String) ?? "生成失敗"
                    completion(.failure(MediaAPIError("Luma エラー: \(reason)")))
                } else {
                    self?.pollLumaGeneration(genId: genId, modelId: modelId, apiKey: apiKey, assetKey: assetKey, attempt: attempt + 1, statusCallback: statusCallback, completion: completion)
                }
            }.resume()
        }
    }

    // =========================================================================
    // MARK: - Shared Binary Savers, Multipart Builder & JSON Extractors
    // =========================================================================

    private static func aspectRatioString(_ ratio: AIImageGeneratorService.ImageAspectRatio) -> String {
        switch ratio {
        case .landscape16_9: return "16:9"
        case .square1_1: return "1:1"
        case .portrait9_16: return "9:16"
        }
    }

    private static func buildMultipartBody(fields: [(String, String)], boundary: String) -> Data {
        var body = Data()
        for (name, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private static func extractMediaURL(from json: [String: Any]) -> URL? {
        if let images = json["images"] as? [[String: Any]],
           let u = images.first?["url"] as? String, let url = URL(string: u) {
            return url
        }
        for key in ["image", "video", "audio_file", "audio"] {
            if let obj = json[key] as? [String: Any],
               let u = obj["url"] as? String, let url = URL(string: u) {
                return url
            }
            if let u = json[key] as? String, u.hasPrefix("http"), let url = URL(string: u) {
                return url
            }
        }
        for key in ["audio_url", "video_url", "image_url", "output"] {
            if let u = json[key] as? String, u.hasPrefix("http"), let url = URL(string: u) {
                return url
            }
            if let obj = json[key] as? [String: Any],
               let u = obj["url"] as? String, let url = URL(string: u) {
                return url
            }
        }
        return nil
    }

    private static func extractReplicateOutputURL(from json: [String: Any]) -> URL? {
        if let str = json["output"] as? String, str.hasPrefix("http"), let url = URL(string: str) {
            return url
        }
        if let arr = json["output"] as? [String], let first = arr.first, first.hasPrefix("http"), let url = URL(string: first) {
            return url
        }
        if let dict = json["output"] as? [String: Any] {
            for k in ["url", "video", "audio", "image", "mp4", "wav"] {
                if let u = dict[k] as? String, u.hasPrefix("http"), let url = URL(string: u) {
                    return url
                }
            }
        }
        return nil
    }

    private static func saveImageData(_ data: Data, prefix: String) -> (NSImage, URL)? {
        guard let image = NSImage(data: data) else { return nil }
        let cleanPrefix = prefix.replacingOccurrences(of: "/", with: "_")
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let fileURL = outputDir.appendingPathComponent("\(cleanPrefix)_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 100...999)).png")
        do {
            try data.write(to: fileURL)
            return (image, fileURL)
        } catch {
            return nil
        }
    }

    private static func saveVideoData(_ data: Data, prefix: String) -> (NSImage, URL)? {
        guard data.count > 1000 else { return nil }
        let cleanPrefix = prefix.replacingOccurrences(of: "/", with: "_")
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Videos", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let fileURL = outputDir.appendingPathComponent("\(cleanPrefix)_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 100...999)).mp4")
        do {
            try data.write(to: fileURL)
            let thumb = AIImageGeneratorService.generateVideoThumbnail(from: fileURL)
                ?? NSImage(systemSymbolName: "film.fill", accessibilityDescription: nil)
                ?? NSImage()
            return (thumb, fileURL)
        } catch {
            return nil
        }
    }

    private static func saveAudioData(_ data: Data, prefix: String, ext: String) -> URL? {
        guard data.count > 256 else { return nil }
        let cleanPrefix = prefix.replacingOccurrences(of: "/", with: "_")
        let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let fileURL = outputDir.appendingPathComponent("\(cleanPrefix)_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 100...999)).\(ext)")
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    private static func downloadImageURL(
        _ url: URL,
        prefix: String,
        engineLabel: String,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let saved = saveImageData(data, prefix: prefix) {
                completion(.success((saved.0, saved.1, engineLabel)))
            } else {
                completion(.failure(MediaAPIError("生成画像のダウンロードに失敗しました: \(error?.localizedDescription ?? "データ不正")")))
            }
        }.resume()
    }

    private static func downloadVideoRequest(
        _ request: URLRequest,
        prefix: String,
        engineLabel: String,
        completion: @escaping (Result<(NSImage, URL, String), Error>) -> Void
    ) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 200
            if (200...299).contains(code), let data = data, let saved = saveVideoData(data, prefix: prefix) {
                completion(.success((saved.0, saved.1, engineLabel)))
            } else {
                let detail = extractErrorText(data: data, statusCode: code, error: error)
                completion(.failure(MediaAPIError("生成動画のダウンロードに失敗しました: \(detail)")))
            }
        }.resume()
    }

    private static func downloadAudioURL(
        _ url: URL,
        prefix: String,
        engineLabel: String,
        completion: @escaping (Result<(URL, String), Error>) -> Void
    ) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            let ext = url.pathExtension.lowercased()
            let fileExt = (ext == "mp3" || ext == "wav" || ext == "m4a" || ext == "ogg" || ext == "flac") ? ext : "wav"
            if let data = data, let saved = saveAudioData(data, prefix: prefix, ext: fileExt) {
                completion(.success((saved, engineLabel)))
            } else {
                completion(.failure(MediaAPIError("生成音声のダウンロードに失敗しました: \(error?.localizedDescription ?? "データ不正")")))
            }
        }.resume()
    }

    public static func extractErrorText(data: Data?, statusCode: Int, error: Error?) -> String {
        if let data = data {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errObj = json["error"] as? [String: Any],
                   let msg = errObj["message"] as? String, !msg.isEmpty {
                    return String(msg.prefix(240))
                }
                if let detailObj = json["detail"] as? [String: Any],
                   let msg = detailObj["message"] as? String, !msg.isEmpty {
                    return String(msg.prefix(240))
                }
                for key in ["error", "detail", "message", "errors"] {
                    if let s = json[key] as? String, !s.isEmpty {
                        return String(s.prefix(240))
                    }
                    if let arr = json[key] as? [String], let first = arr.first, !first.isEmpty {
                        return String(first.prefix(240))
                    }
                }
            }
            if let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !raw.isEmpty, !raw.hasPrefix("<") {
                return String(raw.prefix(200))
            }
        }
        if let error = error {
            return error.localizedDescription
        }
        switch statusCode {
        case 401, 403: return "APIキーが無効、または対象モデルの利用権限・クレジットがありません (HTTP \(statusCode))"
        case 404: return "指定モデルまたはエンドポイントが見つかりません (HTTP 404)"
        case 429: return "APIレート制限または利用枠上限に達しました (HTTP 429)"
        default: return statusCode > 0 ? "HTTPステータス \(statusCode)" : "通信エラー"
        }
    }
}
