# Whisper (WhisperApp)

macOS menu-bar dictation app (Swift) — กด Fn ค้างแล้วพูด → STT → LLM แก้คำ → paste ลงแอปที่ใช้อยู่

## สถานะปัจจุบัน (v1.2 — released 2026-07-05)

- **ชื่อแอป:** "Whisper" — bundle = `Whisper.app` (ใน /Applications ขึ้น "Whisper") ตั้งแต่ v1.2.3; executable ข้างในยังชื่อ `WhisperApp` (ตาม SPM target)
- **อย่า rename:** repo/GitHub URL, SPM target (`WhisperApp`), หรือ bundle ID (`com.game.whisperapp`) — กระทบ git history, SPM build, TCC permissions. เปลี่ยนชื่อ bundle dir (`Whisper.app`) ได้เพราะ TCC bind กับ bundle ID + code signature ไม่ใช่ชื่อไฟล์
- **Hotkey default:** Fn, hold-to-talk · toggle mode = เคาะ 2 ครั้งเริ่ม เคาะ 1 ครั้งหยุด (`HotkeyManager.swift`)
- **Dictation pipeline:** `DictationController` ดูแล recording/UI state + paste เท่านั้น; `DictationPipeline` เป็นเจ้าของ cloud/local STT routing, sound-annotation cleanup, optional correction, dictionary finalization และอายุของ temporary audio file. `DictationPipelineCore.swift` เป็น Foundation-only เพื่อทดสอบบน Linux และเป็นฐานสำหรับ History/Profile/Fallback/Commands/Meeting ต่อไป
- **Provider:** Groq ยังเป็นค่าเริ่มต้นและรองรับ key เดียวสำหรับ STT (`whisper-large-v3-turbo`) + correction (`llama-3.3-70b-versatile`) แต่ Settings สามารถเลือก STT และ LLM แยกกันได้แล้ว
- **LLM architecture:** `LLMProviderCore.swift` แยก vendor / wire protocol / auth / capabilities ออกจาก persistence ใน `LLMProvider.swift`; รองรับ OpenAI-compatible Chat Completions, OpenAI-compatible Responses และ Anthropic Messages โดยไม่เดาพฤติกรรมจากชื่อโมเดล
- **Responses presets:** `openai_responses` (`gpt-5.6-luna`, `/v1/responses`), `xai_responses` (`grok-4.6`, `/v1/responses`) และ `qwen_responses` (workspace-specific `/compatible-mode/v1/responses`)
- **Responses policy:** ส่ง `store: false`; text extraction อ่าน `output[].content[].output_text`; reasoning effort = `none` สำหรับ OpenAI/Qwen และ `low` สำหรับ Grok 4.6 เพื่อให้เหมาะกับ text correction latency
- **LLM presets:** Groq, OpenAI, Anthropic Claude, Google Gemini, xAI Grok, OpenRouter, DeepSeek, Alibaba Qwen / Model Studio, Z.AI GLM, MiniMax, Moonshot/Kimi, ByteDance Doubao/Volcengine Ark, Custom; macOS มี Ollama และ LM Studio แบบ local/no-key เพิ่มด้วย
- **Kimi policy:** `kimi-k2.6` ใช้ OpenAI Chat Completions, ไม่ส่ง `temperature` และส่ง `thinking: {type: disabled}` สำหรับงาน correction latency ต่ำ; model list ใช้ `/v1/models`
- **Doubao policy:** ใช้ Ark OpenAI-compatible `/api/v3/chat/completions`, Bearer `ARK_API_KEY`, default `doubao-seed-2-1-pro-260628` และยัง override endpoint/model ได้จาก Settings
- **Model catalog:** macOS Settings มี `Load Models` สำหรับ provider ที่มี `/models`; parser รองรับรูปแบบ `data[].id` และยังกรอก Model ID เองได้เสมอ
- **STT presets:** ElevenLabs, OpenAI, Groq และ Custom OpenAI-compatible; Qwen ASR อยู่ใน PR แยกเพื่อไม่ผูก STT กับ Responses LLM work
- **CI:** `.github/workflows/provider-core-tests.yml` รัน Swift core regression, native macOS `swift build -c release`, และ compile `windows/build.bat` บน `windows-latest`; Windows build ใช้ `vswhere` หา Roslyn รุ่นปัจจุบันแทนการ hard-code VS2019
- **Logo:** Claude-style cream/clay paper-cut mic — mask ด้วย superellipse (n=5) เขียนด้วย Python/PIL, อย่าใช้ขอบที่ AI gen มาตรงๆ (มันเบี้ยว)
- **About window:** มีแล้ว (`AboutView.swift`) — เครดิต Gamezxz + ลิงก์

## Build & Release

- `./run.sh` — build + เปิดแอป (dev loop)
- `./make_dmg.sh` — build → sign → **notarize + staple อัตโนมัติ** (ต้องมี keychain profile `whisperapp-notary`, มีแล้วในเครื่องนี้)
- Provider core regression tests: `bash scripts/test_provider_core.sh`
- Responses policy regression tests: `bash scripts/test_responses_policy.sh`
- Dictation pipeline regression tests: `bash scripts/test_dictation_pipeline_core.sh`
- Controller/pipeline boundary contract: `bash scripts/test_dictation_controller_pipeline_contract.sh`
- ออกเวอร์ชันใหม่: bump `Info.plist` → `./make_dmg.sh` → `gh release create vX.Y *.dmg` → แก้ลิงก์ดาวน์โหลด + badge เวอร์ชันใน `docs/index.html` (ลิงก์ตรงไปไฟล์ DMG ไม่ใช่ releases/latest)

## เว็บโปรโมต (GitHub Pages)

- https://gamezxz.github.io/WhisperApp/ — source ที่ `docs/`, ภาษาอังกฤษ, ธีม cream/clay แบบ cointh.com (Fraunces + Hanken Grotesk, palette `#f4f2ea`/`#cd6f4d` + dark mode)
- SEO ครบแล้ว: OG/Twitter card + `og.png`, JSON-LD SoftwareApplication, canonical, `robots.txt`, `sitemap.xml`
- Pages build fail เป็นครั้งคราว (transient) → retrigger: `gh api repos/Gamezxz/WhisperApp/pages/builds -X POST`

## ค้าง / ทำต่อได้

- Phase 1: ยกระดับ Personal Dictionary เป็น Dictionary V2 + learning suggestions
- Phase 2: History / Undo / Paste Last Transcript
- Phase 3: App-aware Profiles
- Phase 4: STT/LLM provider fallback chains
- Phase 5: Thai-English mixed speech mode
- Phase 6: Voice Commands + backtracking
- Phase 7: Voice Snippets / Macros
- Phase 8: Local Model Manager สำหรับ M1–M4 โดยไม่บังคับ Homebrew
- Phase 9: AI Action / Command Mode บน selected text
- Phase 10: Meeting Mode
- ย้าย credential ไป Keychain (macOS) / DPAPI (Windows) พร้อม migration จากค่าเดิม
- เพิ่ม dynamic model catalog ฝั่ง Windows ให้ parity กับ macOS
- Submit sitemap ใน Google Search Console (user ต้องทำเอง)
- JSON-LD `softwareVersion` + `downloadUrl` ใน `docs/index.html` ต้องอัปเดตทุกครั้งที่ออกเวอร์ชันใหม่
