#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${ROOT_DIR}/.derivedData"
SCHEME="FinancialCalculatorKit"
PROJECT="${ROOT_DIR}/FinancialCalculatorKit.xcodeproj"
APP_NAME="FinancialCalculatorKit"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/${APP_NAME}.app"

MODE="run"

for arg in "$@"; do
  case "${arg}" in
    --verify)
      MODE="verify"
      ;;
    --logs)
      MODE="logs"
      ;;
    --debug)
      MODE="debug"
      ;;
    *)
      echo "Unknown option: ${arg}" >&2
      exit 1
      ;;
  esac
done

pkill -x "${APP_NAME}" >/dev/null 2>&1 || true

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Built app not found at ${APP_PATH}" >&2
  exit 1
fi

case "${MODE}" in
  debug)
    exec lldb -- "${APP_PATH}/Contents/MacOS/${APP_NAME}"
    ;;
  logs)
    /usr/bin/open -n "${APP_PATH}"
    exec /usr/bin/log stream --level info --predicate "process == \"${APP_NAME}\""
    ;;
  verify)
    /usr/bin/open -n "${APP_PATH}"
    sleep 2
    if pgrep -x "${APP_NAME}" >/dev/null; then
      echo "${APP_NAME} launched successfully."
      exit 0
    fi
    echo "${APP_NAME} did not launch successfully." >&2
    exit 1
    ;;
  run)
    exec /usr/bin/open -n "${APP_PATH}"
    ;;
esac
