#!/usr/bin/env bash
set -euo pipefail

require_file() { test -f "$1" || { echo "FAIL: missing $1"; exit 1; }; }
require_text() { grep -Fq "$2" "$1" || { echo "FAIL: $1 missing: $2"; exit 1; }; }

require_file Sources/AppProfileStore.swift
require_file Sources/AppContextService.swift
require_file Sources/ProfilesView.swift

require_text Sources/AppContextService.swift 'NSWorkspace.shared.frontmostApplication'
require_text Sources/AppContextService.swift 'bundleIdentifier'
require_text Sources/AppProfileStore.swift 'profiles-v1.json'
require_text Sources/DictationPipelineCore.swift 'profile: AppProfile?'
require_text Sources/DictationPipelineCore.swift 'bundleIdentifier: String?'
require_text Sources/DictationController.swift 'AppContextService.shared.currentBundleIdentifier'
require_text Sources/DictationController.swift 'AppProfileStore.shared.resolve'
require_text Sources/CloudTranscriptionService.swift 'profile?.sttProviderID'
require_text Sources/CloudTranscriptionService.swift 'profile?.sttModel'
require_text Sources/TextCorrectionService.swift 'profile?.llmProviderID'
require_text Sources/TextCorrectionService.swift 'profile?.llmModel'
require_text Sources/TextCorrectionService.swift 'profile?.customPrompt'
require_text Sources/Dictionary.swift 'bundleIdentifier:'
require_text Sources/Dictionary.swift 'DictionaryV2Codec.activeRules'
require_text Sources/SettingsView.swift 'ProfilesView()'

echo 'App profile integration contract PASS'
