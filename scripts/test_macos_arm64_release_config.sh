#!/bin/bash
set -euo pipefail

WORKFLOW=.github/workflows/macos-arm64-release.yml

[ -f "$WORKFLOW" ] || { echo "missing $WORKFLOW"; exit 1; }

grep -Fq 'runs-on: macos-15' "$WORKFLOW"
grep -Fq 'WHISPERAPP_ARCH: arm64' "$WORKFLOW"
grep -Fq 'WHISPERAPP_RELEASE_SUFFIX: macOS-arm64' "$WORKFLOW"
grep -Fq 'MACOS_CERTIFICATE_P12_BASE64' "$WORKFLOW"
grep -Fq 'APPLE_APP_SPECIFIC_PASSWORD' "$WORKFLOW"
grep -Fq 'actions/upload-artifact@v4' "$WORKFLOW"
grep -Fq 'gh release upload' "$WORKFLOW"

grep -Fq 'WHISPERAPP_ARCH' make_app.sh
grep -Fq -- '--show-bin-path' make_app.sh
grep -Fq 'WHISPERAPP_KEYCHAIN' make_app.sh
grep -Fq 'WHISPERAPP_RELEASE_SUFFIX' make_dmg.sh
grep -Fq 'WHISPERAPP_NOTARY_PROFILE' make_dmg.sh

echo 'macOS arm64 release configuration OK'
