#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="${PACKAGE:-./cmd/xcodecli}"
OUTPUT="${1:-${OUTPUT:-${ROOT_DIR}/xcodecli}}"
VERSION="${VERSION:-dev}"
GO_LDFLAGS="${GO_LDFLAGS:-}"

if [[ -n "$GO_LDFLAGS" ]]; then
  GO_LDFLAGS="${GO_LDFLAGS} "
fi
GO_LDFLAGS="${GO_LDFLAGS}-X main.cliVersion=${VERSION}"

mkdir -p "$(dirname "$OUTPUT")"

echo "[build] package: ${PACKAGE}"
echo "[build] output:  ${OUTPUT}"
echo "[build] version: ${VERSION}"

cd "$ROOT_DIR"
go build -ldflags "$GO_LDFLAGS" -o "$OUTPUT" "$PACKAGE"

echo "[build] done"
