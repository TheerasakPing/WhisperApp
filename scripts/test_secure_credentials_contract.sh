#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

require() {
  local file="$1" pattern="$2" message="$3"
  grep -Fq "$pattern" "$ROOT/$file" || { echo "FAIL: $message"; exit 1; }
}
forbid() {
  local file="$1" pattern="$2" message="$3"
  if grep -Fq "$pattern" "$ROOT/$file"; then echo "FAIL: $message"; exit 1; fi
}

require Sources/SecureCredentialStore.swift "import Security" "macOS credentials must use Security.framework"
require Sources/SecureCredentialStore.swift "SecItemCopyMatching" "Keychain read must use SecItemCopyMatching"
require Sources/SecureCredentialStore.swift "SecItemAdd" "Keychain save must use SecItemAdd"
require Sources/SecureCredentialStore.swift "SecItemUpdate" "Keychain update must use SecItemUpdate"
require Sources/SecureCredentialStore.swift "SecItemDelete" "Keychain delete must use SecItemDelete"
require Sources/LLMProvider.swift 'SecureCredentialStore.shared.read(account: "llm:' "LLM keys must resolve from Keychain"
require Sources/STTProvider.swift 'SecureCredentialStore.shared.read(account: "stt:' "STT keys must resolve from Keychain"
require Sources/LLMProvider.swift "migrateLegacyKey" "LLM legacy key files must migrate safely"
require Sources/STTProvider.swift "migrateLegacyKey" "STT legacy key files must migrate safely"
require Sources/SecureCredentialStore.swift "removeItem" "legacy plaintext files must be removed only after successful secure migration"
forbid README.md 'API keys are stored locally (`~/.whisperapp/`' "README must not claim API keys remain plaintext files"

echo "SecureCredentialContract: PASS"
