# Whisper

A macOS menu-bar dictation app — hold **Fn**, speak, release, and the AI-corrected text is pasted into whatever you're typing. Groq remains the default zero-friction setup, while advanced users can select separate Speech-to-Text and LLM providers.

**Website:** https://gamezxz.github.io/WhisperApp/

![Whisper](assets/logo.png)

> The app is named **Whisper** (v1.2+); the repo/bundle keeps the historical name `WhisperApp`.

## Features

- 🎙️ **Global hotkey** — default is the **Fn key alone**, hold-to-talk; toggle mode: double-tap to start, single tap to stop. Fully configurable in Settings.
- ⚡ **Groq by default** — a single Groq API key can still power both transcription (`whisper-large-v3-turbo`) and AI correction (`llama-3.3-70b-versatile`)
- 🔌 **Multi-provider AI correction** — presets for OpenAI, Anthropic Claude, Google Gemini, xAI Grok, Groq, OpenRouter, DeepSeek, Alibaba Qwen / Model Studio, Z.AI GLM, MiniMax, Moonshot/Kimi, ByteDance Doubao/Volcengine Ark, plus custom OpenAI-compatible endpoints
- 🧩 **Responses API variants** — optional OpenAI, xAI and Alibaba Qwen presets use OpenAI-compatible `/responses` without changing the legacy Chat Completions presets
- ⚡ **Latency-aware reasoning** — text correction uses `none` reasoning for GPT-5.6 Luna/Qwen Responses and `low` for Grok 4.6, while keeping `store: false` on Responses requests
- 🔄 **Live model catalogs** — supported providers can load their current `/models` catalog directly in Settings while retaining manual Model ID entry as a fallback
- 🖥️ **Local LLM support on macOS** — Ollama and LM Studio presets, with no API key required
- ☁️ **Selectable cloud STT** — ElevenLabs Scribe, OpenAI, Groq Whisper, Alibaba Qwen3-ASR-Flash, or a custom OpenAI-compatible transcription endpoint
- 🇹🇭 **Qwen3-ASR-Flash** — supports Thai and other multilingual dictation through Alibaba Model Studio's OpenAI-compatible audio-chat API
- ✨ **AI text correction** — fixes garbled words and adds punctuation before pasting
- 📋 **Auto-paste** into the focused app (simulates ⌘V)
- 🌊 Live waveform + status overlay (recording → transcribing → fixing → done)
- 🔒 API keys are stored locally (`~/.whisperapp/` on macOS; app config on Windows) and are never bundled with the app
- ✅ Signed & **notarized** macOS DMG

## Requirements

- macOS 13+
- **Permissions:** Microphone + Accessibility (for auto-paste)
- At least one configured STT provider; Groq is the default/recommended first setup
- AI correction is optional and can use a different provider from STT

## Install

1. Download `Whisper-x.x.dmg` from [Releases](../../releases) (or the [website](https://gamezxz.github.io/WhisperApp/))
2. Drag **Whisper** to **Applications**
3. Open it — a mic icon appears in the menu bar
4. **System Settings → Privacy & Security:** enable **Microphone** and **Accessibility**
5. Click the mic icon → **Settings…**
6. Configure the STT provider and, optionally, a separate AI correction provider
7. Hold **Fn** and speak

## Provider configuration

Provider settings are stored per provider, so switching between services does not overwrite the other providers' model or endpoint choices.

API keys are resolved from the Settings UI first, then from the provider's environment variable (for example `GROQ_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `XAI_API_KEY`, `DASHSCOPE_API_KEY`, `MOONSHOT_API_KEY`, or `ARK_API_KEY`).

```sh
# Optional: use an environment variable instead of entering a key in Settings
export GROQ_API_KEY="gsk_..."
```

For providers with a model catalog endpoint, click **Load Models** in Settings to fetch the currently available model IDs. You can always type a model ID manually when a provider does not expose a catalog or when you need a model that is not listed.

Alibaba Model Studio uses region/workspace-specific OpenAI-compatible endpoints. Use the full `/chat/completions` URL for the Qwen Chat preset, the full `/compatible-mode/v1/responses` URL for Qwen Responses, and the workspace `/compatible-mode/v1/chat/completions` URL for Qwen3-ASR-Flash. Qwen3-ASR-Flash sends the recorded WAV as a Base64 Data URI and reads the non-streaming transcript from the chat-completion response. Kimi uses the international Moonshot endpoint by default. Doubao uses Volcengine Ark's Beijing OpenAI-compatible endpoint; users can override endpoint/model for their Ark project or inference endpoint.

## Build from source

```bash
git clone https://github.com/TheerasakPing/WhisperApp
cd WhisperApp
./run.sh             # dev loop: build + launch the app
./make_dmg.sh        # build → sign → notarize → staple → .dmg
```

Provider-core regression tests can be run without launching the macOS app:

```bash
bash scripts/test_provider_core.sh
bash scripts/test_responses_policy.sh
bash scripts/test_stt_provider_core.sh
```

GitHub Actions also compiles the Windows port with `windows/build.bat` so C# provider parity is checked on a native Windows runner.

Notarization in `make_dmg.sh` expects a keychain profile named `whisperapp-notary`
(`xcrun notarytool store-credentials`). For a stable signature (so macOS remembers
permissions across rebuilds), sign with your own **Developer ID Application**
certificate — the build scripts auto-detect it.

### macOS Apple Silicon (M1–M4) release in GitHub Actions

The `macOS ARM64 Release` workflow builds a native `arm64` app on the macOS Apple Silicon runner, signs it with a **Developer ID Application** certificate, notarizes both the `.app` and `.dmg`, staples the notarization tickets, verifies Gatekeeper acceptance, and uploads:

- `Whisper-<version>-macOS-arm64.dmg`
- `Whisper-<version>-macOS-arm64.dmg.sha256`

Configure these repository **Actions secrets** before running the release workflow:

- `MACOS_CERTIFICATE_P12_BASE64` — Base64-encoded Developer ID Application `.p12`
- `MACOS_CERTIFICATE_PASSWORD` — password for the `.p12`
- `APPLE_ID` — Apple Developer account email used for notarization
- `APPLE_APP_SPECIFIC_PASSWORD` — app-specific password for that Apple ID
- `APPLE_TEAM_ID` — Apple Developer Team ID

Run the workflow manually from **Actions → macOS ARM64 Release → Run workflow** to produce a signed/notarized downloadable Actions artifact. Pushing a tag matching `v*` (for example `v1.3.0`) additionally creates or updates the matching GitHub Release and attaches the ARM64 DMG plus checksum.

### Release checklist

1. Bump version in `Info.plist`
2. For a local Mac release, run `./make_dmg.sh`; for Apple Silicon CI release, use the `macOS ARM64 Release` workflow
3. Push a `vX.Y` / `vX.Y.Z` tag when the ARM64 artifact should be attached to GitHub Releases
4. Update the download link + version badge + JSON-LD (`softwareVersion`, `downloadUrl`) in `docs/index.html`

## Architecture

- SwiftUI menu-bar app (`LSUIElement`), `NSEvent` global hotkey (`HotkeyManager.swift`)
- `AVAudioEngine` → 16 kHz mono Int16 WAV recording
- Separate STT and LLM provider registries
- Transport-driven STT core for multipart transcription and OpenAI-compatible audio-chat JSON
- Capability-driven LLM request builder for OpenAI-compatible Chat Completions, OpenAI-compatible Responses, and Anthropic Messages
- Responses parser reads typed `output[].content[].output_text` blocks and supports provider convenience `output_text` fields
- Dynamic model catalog service for providers exposing `{ "data": [{ "id": ... }] }` model lists
- Provider-specific model, endpoint, auth, reasoning, and request-policy settings with Groq as the backward-compatible default
- Floating `NSPanel` + SwiftUI status overlay
- Windows port mirrors the configurable STT/LLM provider model and is compiled in CI
- Promo site lives in `docs/` (GitHub Pages, cream/clay theme, full SEO meta)

## License

MIT
