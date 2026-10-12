#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc \
    libraries/Foundations/Domain/Sources/Domain/Features/DomainInclusionSettings.swift \
    libraries/Core/NEProviders/Sources/WireGuardExtension/InclusionAddressResolver.swift \
    libraries/Core/NEProviders/Sources/WireGuardExtension/InclusionNetworkSettings.swift \
    Integration/Tests/DomainInclusionChecks.swift \
    -o "$check_dir/checks"
"$check_dir/checks"
