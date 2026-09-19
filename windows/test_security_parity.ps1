$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Require-Text([string]$path, [string]$needle, [string]$message) {
    $text = Get-Content (Join-Path $root $path) -Raw
    if (-not $text.Contains($needle)) { throw "FAIL: $message" }
}
function Forbid-Text([string]$path, [string]$needle, [string]$message) {
    $text = Get-Content (Join-Path $root $path) -Raw
    if ($text.Contains($needle)) { throw "FAIL: $message" }
}

# Credential hardening
Require-Text "windows/src/CredentialStore.cs" "ProtectedData.Protect" "Windows keys must be encrypted with DPAPI"
Require-Text "windows/src/CredentialStore.cs" "ProtectedData.Unprotect" "Windows keys must be decrypted with DPAPI"
Require-Text "windows/src/CredentialStore.cs" "DataProtectionScope.CurrentUser" "DPAPI must be scoped to the current user"
Require-Text "windows/src/Config.cs" "MigratePlaintextKeys" "plaintext config keys must migrate"
Require-Text "windows/src/Config.cs" 'CredentialStore.Read("stt:"' "STT keys must resolve from DPAPI store"
Require-Text "windows/src/Config.cs" 'CredentialStore.Read("llm:"' "LLM keys must resolve from DPAPI store"
Require-Text "windows/build.bat" "System.Security.dll" "Windows build must reference System.Security for DPAPI"

# STT parity
Require-Text "windows/src/Providers.cs" 'Id = "qwen_asr"' "Windows must expose Qwen3 ASR"
Require-Text "windows/src/Providers.cs" 'DefaultModel = "qwen3-asr-flash"' "Windows Qwen ASR model must match macOS"
Require-Text "windows/src/SttClient.cs" "QwenAudioChat" "Windows STT must implement Qwen audio-chat transport"
Require-Text "windows/src/SttClient.cs" '"input_audio"' "Qwen request must send input_audio"
Require-Text "windows/src/SttClient.cs" '"data:audio/wav;base64,"' "Qwen audio must use a Data URI"
Require-Text "windows/src/SttClient.cs" '"choices"' "Qwen response must parse chat choices"

# Language parity
Require-Text "windows/src/SettingsForm.cs" "ไทย + English (Mixed)" "Windows settings must expose Thai-English mixed mode"
Require-Text "windows/src/SettingsForm.cs" '"th-en"' "Windows must persist th-en language mode"

# Dynamic LLM model catalog
Require-Text "windows/src/Providers.cs" "ModelsEndpoint" "Windows providers must define model catalog metadata"
Require-Text "windows/src/ModelCatalogClient.cs" "FetchAsync" "Windows must fetch model catalogs"
Require-Text "windows/src/ModelCatalogClient.cs" '"data"' "Windows model catalog must parse OpenAI-compatible data"
Require-Text "windows/src/SettingsForm.cs" "Load Models" "Windows settings must expose model loading"

# Z.AI remains aligned
Require-Text "windows/src/Providers.cs" "https://api.z.ai/api/paas/v4/chat/completions" "Windows Z.AI endpoint must remain General API"
Require-Text "windows/src/Providers.cs" 'DefaultModel = "glm-5.2"' "Windows Z.AI model must remain glm-5.2"

Write-Host "WindowsSecurityParity: PASS"
