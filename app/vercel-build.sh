#!/usr/bin/env bash
# Vercel has no Flutter runtime preinstalled, so this script fetches the SDK
# during the build itself (a shallow clone of the stable channel is fast
# enough to fit comfortably in a normal build timeout) and then does a
# regular release web build.
#
# SUPABASE_URL / SUPABASE_ANON_KEY: the anon/publishable key is meant to be
# public (it's protected by Postgres Row Level Security, not secrecy), so
# defaulting it here is safe. Set Environment Variables of the same name in
# the Vercel project settings to point a given deployment at a different
# Supabase project (e.g. a staging project) without touching this file.
set -euo pipefail

echo "==> Fetching Flutter SDK (stable, shallow clone)"
git clone --depth 1 -b stable https://github.com/flutter/flutter.git flutter-sdk
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

flutter config --no-analytics
flutter doctor -v

echo "==> Installing dependencies"
flutter pub get

echo "==> Building release web bundle"
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://vttghkeqsewqmkulmaie.supabase.co}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_1jYPkKhwww7eGEpFTAcP4A_XeESUVBw}"

echo "==> Trimming unused CanvasKit renderer variants (this build only ever targets the default canvaskit renderer, never skwasm/wasm)"
rm -f build/web/canvaskit/skwasm*.js build/web/canvaskit/skwasm*.js.symbols build/web/canvaskit/skwasm*.wasm
rm -f build/web/canvaskit/wimp.js build/web/canvaskit/wimp.js.symbols build/web/canvaskit/wimp.wasm
rm -rf build/web/canvaskit/webparagraph
