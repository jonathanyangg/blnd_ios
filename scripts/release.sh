#!/usr/bin/env bash
# Release pipeline: clean checkout -> archive -> export (-> upload, ONLY with --upload).
#
#   scripts/release.sh [--ref release/2.0] [--out ~/blnd-release] [--upload]
#
# By default this NEVER uploads to App Store Connect. Pass --upload explicitly
# (and only when the release owner says so) to run the upload step.
set -euo pipefail

REF="release/2.0"
OUT="${HOME}/blnd-release"
UPLOAD=0
REPO_URL="$(git -C "$(dirname "$0")/.." remote get-url origin)"
SRC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) REF="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --upload) UPLOAD=1; shift ;;
    -h|--help) sed -n 2,8p "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$OUT/$STAMP"
CHECKOUT="$WORK/src"
ARCHIVE="$WORK/blnd.xcarchive"
EXPORT="$WORK/export"
mkdir -p "$WORK"

echo "==> Clean checkout of $REF into $CHECKOUT"
git clone --quiet --no-hardlinks "$SRC_ROOT" "$CHECKOUT"
git -C "$CHECKOUT" remote set-url origin "$REPO_URL"
git -C "$CHECKOUT" fetch --quiet origin "$REF" 2>/dev/null || true
git -C "$CHECKOUT" checkout --quiet "$REF" 2>/dev/null || git -C "$CHECKOUT" checkout --quiet "origin/$REF"
echo "    HEAD: $(git -C "$CHECKOUT" rev-parse --short HEAD)"

echo "==> Guard: Release must point at production API"
if ! grep -q 'API_BASE_URL = "https://blnd-backend.onrender.com"' "$CHECKOUT/blnd_ios.xcodeproj/project.pbxproj"; then
  echo "Release API_BASE_URL is not https://blnd-backend.onrender.com" >&2; exit 1
fi

echo "==> Archive (Release)"
xcodebuild archive \
  -project "$CHECKOUT/blnd_ios.xcodeproj" -scheme blnd_ios \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  | tee "$WORK/archive.log" | tail -n 5

echo "==> Export (app-store-connect, no upload)"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$CHECKOUT/scripts/ExportOptions.plist" \
  -exportPath "$EXPORT" -allowProvisioningUpdates \
  | tee "$WORK/export.log" | tail -n 5

IPA="$(ls "$EXPORT"/*.ipa 2>/dev/null | head -n1 || true)"
echo "==> Built: ${IPA:-<no ipa found in $EXPORT>}"

if [[ "$UPLOAD" -eq 1 ]]; then
  [[ -n "$IPA" ]] || { echo "no ipa to upload" >&2; exit 1; }
  echo "==> --upload given: uploading to App Store Connect"
  xcrun altool --upload-app -f "$IPA" -t ios --apiKey "${ASC_KEY_ID:?set ASC_KEY_ID}" --apiIssuer "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
else
  echo "==> Upload skipped (pass --upload to enable)."
fi
