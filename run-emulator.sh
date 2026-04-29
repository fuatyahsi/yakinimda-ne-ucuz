#!/usr/bin/env bash
# run-emulator.sh — secrets.txt'i parse edip flutter run koşturur.
#
# Kullanim:
#   ./run-emulator.sh           # default: debug + emulator (auto-detect)
#   ./run-emulator.sh release   # release mode (daha hizli ama hot reload yok)
#
# secrets.txt formatı (key = 'value' veya key=value):
#   SUPABASE_URL = 'https://...'
#   SUPABASE_ANON_KEY = 'eyJhbGci...'

set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f secrets.txt ]; then
  echo "HATA: secrets.txt bulunamadi. SUPABASE_URL ve SUPABASE_ANON_KEY satiri olmali." >&2
  exit 1
fi

# Quote (', ") ve bosluklari handle eden parser
extract() {
  local key="$1"
  grep -E "^[[:space:]]*${key}[[:space:]]*=" secrets.txt \
    | head -1 \
    | sed -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//" \
    | sed -E "s/^['\"]//; s/['\"]$//"
}

URL="$(extract SUPABASE_URL)"
ANON="$(extract SUPABASE_ANON_KEY)"

if [ -z "$URL" ] || [ -z "$ANON" ]; then
  echo "HATA: secrets.txt icinde SUPABASE_URL veya SUPABASE_ANON_KEY bulunamadi/bos." >&2
  exit 1
fi

MODE="${1:-debug}"
FLUTTER_FLAGS=()
if [ "$MODE" = "release" ]; then
  FLUTTER_FLAGS+=(--release)
fi

echo "[run-emulator] URL=${URL}"
echo "[run-emulator] ANON=${ANON:0:24}... (${#ANON} char)"
echo "[run-emulator] mode=${MODE}"
echo "[run-emulator] flutter run baslatiliyor..."
echo

exec flutter run "${FLUTTER_FLAGS[@]}" \
  --dart-define=SUPABASE_URL="${URL}" \
  --dart-define=SUPABASE_ANON_KEY="${ANON}"
