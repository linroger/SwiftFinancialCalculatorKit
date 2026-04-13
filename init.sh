#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DERIVED_DATA_PATH="${ROOT_DIR}/.derivedData"
SCHEME="FinancialCalculatorKit"
PROJECT="FinancialCalculatorKit.xcodeproj"

echo "==> SwiftPM build"
swift build --package-path "${ROOT_DIR}"

echo "==> Xcode build"
xcodebuild \
  -project "${ROOT_DIR}/${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

if [[ "${1:-}" == "--test" ]]; then
  echo "==> Xcode test"
  xcodebuild \
    -project "${ROOT_DIR}/${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    test
fi
