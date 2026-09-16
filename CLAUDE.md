# Whisper (WhisperApp)

macOS menu-bar dictation app (Swift) — กด Fn ค้างแล้วพูด → STT → LLM แก้คำ → paste ลงแอปที่ใช้อยู่

## สถานะปัจจุบัน (v1.2 — released 2026-07-05)

- **ชื่อแอป:** "Whisper" — bundle = `Whisper.app` (ใน /Applications ขึ้น "Whisper") ตั้งแต่ v1.2.3; executable ข้างในยังชื่อ `WhisperApp` (ตาม SPM target)
- **อย่า rename:** repo/GitHub URL, SPM target (`WhisperApp`), หรือ bundle ID (`com.game.whisperapp`) — กระทบ git history, SPM build, TCC permissions. เปลี่ยนชื่อ bundle dir (`Whisper.app`) ได้เพราะ TCC bind กับ bundle ID + code signature ไม่ใช่ชื่อไฟล์
- **Hotkey default:** Fn, hold-to-talk · toggle mode = เคาะ 2 ครั้งเริ่ม เคาะ 1 ครั้งหยุด (`HotkeyManager.swift`)
- **Provider:** Groq ยังเป็นค่าเริ่มต้นและรองรับ key เดียวสำหรับ STT (`whisper-large-v3-turbo`) + correction (`llama-3.3-70b-versatile`) แต่ Settings สามารถเลือก STT และ LLM แยกกันได้แล้ว
- **LLM architecture:** `LLMProviderCore.swift` แยก vendor / wire protocol / auth / capabilities ออกจาก persistence ใน `LLMProvider.swift`; รองรับ OpenAI-compatible Chat Completions และ Anthropic Messages โดยไม่เดาพฤติกรรมจากชื่อโมเดล
- **LLM presets:** Groq, OpenAI, Anthropic Claude, Google Gemini, xAI Grok, OpenRouter, DeepSeek, Alibaba Qwen / Model Studio, Z.AI GLM, MiniMax, Moonshot/Kimi, ByteDance Doubao/Volcengine Ark, Custom; macOS มี Ollama และ LM Studio แบบ local/no-key เพิ่มด้วย
- **Kimi policy:** `kimi-k2.6` ใช้ OpenAI Chat Completions, ไม่ส่ง `temperature` และส่ง `thinking: {type: disabled}` สำหรับงาน correction latency ต่ำ; model list ใช้ `/v1/models`
- **Doubao policy:** ใช้ Ark OpenAI-compatible `/api/v3/chat/completions`, Bearer `ARK_API_KEY`, default `doubao-seed-2-1-pro-260628` และยัง override endpoint/model ได้จาก Settings
- **Model catalog:** macOS Settings มี `Load Models` สำหรับ provider ที่มี `/models`; parser รองรับรูปแบบ `data[].id` และยังกรอก Model ID เองได้เสมอ
- **STT architecture:** `STTProviderCore.swift` แยก transport/auth/language metadata ออกจาก persistence; `CloudTranscriptionService` route ตาม transport (`multipartTranscription` หรือ `audioChatJSON`) แทนการเช็คชื่อ vendor
- **STT presets:** ElevenLabs, OpenAI, Groq, Alibaba Qwen3-ASR-Flash และ Custom OpenAI-compatible transcription
- **Qwen ASR:** ใช้ `qwen3-asr-flash` ผ่าน workspace/region-specific `/compatible-mode/v1/chat/completions`, ส่ง WAV เป็น Base64 Data URI และอ่าน transcript จาก `choices[0].message.content`
- **Logo:** Claude-style cream/clay paper-cut mic — mask ด้วย superellipse (n=5) เขียนด้วย Python/PIL, อย่าใช้ขอบที่ AI gen มาตรงๆ (มันเบี้ยว)
- **About window:** มีแล้ว (`AboutView.swift`) — เครดิต Gamezxz + ลิงก์

## Build & Release

- `./run.sh` — build + เปิดแอป (dev loop)
- `./make_dmg.sh` — build → sign → **notarize + staple อัตโนมัติ** (ต้องมี keychain profile `whisperapp-notary`, มีแล้วในเครื่องนี้)
- LLM provider regression tests: `bash scripts/test_provider_core.sh`
- STT provider regression tests: `bash scripts/test_stt_provider_core.sh`
- ออกเวอร์ชันใหม่: bump `Info.plist` → `./make_dmg.sh` → `gh release create vX.Y *.dmg` → แก้ลิงก์ดาวน์โหลด + badge เวอร์ชันใน `docs/index.html` (ลิงก์ตรงไปไฟล์ DMG ไม่ใช่ releases/latest)

## เว็บโปรโมต (GitHub Pages)

- https://gamezxz.github.io/WhisperApp/ — source ที่ `docs/`, ภาษาอังกฤษ, ธีม cream/clay แบบ cointh.com (Fraunces + Hanken Grotesk, palette `#f4f2ea`/`#cd6f4d` + dark mode)
- SEO ครบแล้ว: OG/Twitter card + `og.png`, JSON-LD SoftwareApplication, canonical, `robots.txt`, `sitemap.xml`
- Pages build fail เป็นครั้งคราว (transient) → retrigger: `gh api repos/Gamezxz/WhisperApp/pages/builds -X POST`

## ค้าง / ทำต่อได้

- Responses API adapters สำหรับ OpenAI/xAI/Alibaba และ provider ที่รองรับ
- ย้าย credential ไป Keychain (macOS) / DPAPI (Windows) พร้อม migration จากค่าเดิม
- เพิ่ม dynamic model catalog ฝั่ง Windows ให้ parity กับ macOS
- เพิ่ม Qwen ASR transport parity ฝั่ง Windows
- Submit sitemap ใน Google Search Console (user ต้องทำเอง)
- JSON-LD `softwareVersion` + `downloadUrl` ใน `docs/index.html` ต้องอัปเดตทุกครั้งที่ออกเวอร์ชันใหม่
