#!/usr/bin/env bash
set -euo pipefail

test -f Sources/AppProfileCore.swift || { echo 'FAIL: Sources/AppProfileCore.swift missing'; exit 1; }

swiftc Sources/AppProfileCore.swift Tests/AppProfileCoreTests.swift -o /tmp/app-profile-core-tests
/tmp/app-profile-core-tests
