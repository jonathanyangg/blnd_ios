#!/usr/bin/env bash
# Run every Maestro flow on one simulator, one at a time, and collect screenshots.
#   tools/qa/run-flows.sh <sim-udid-or-name> [out-dir] [flow-glob]
# Output: <out-dir>/<flow>/takeScreenshot/*.png, <out-dir>/results.tsv (flow<TAB>PASS|FAIL<TAB>seconds)
set -u
cd "$(dirname "$0")/../.."
SIM="${1:?usage: run-flows.sh <sim-udid-or-name> [out-dir] [flow-glob]}"
OUT="${2:-$HOME/cursor-work/qa/artifacts/maestro-$(date +%Y%m%d-%H%M%S)}"
GLOB="${3:-[0-9][0-9]_*.yaml}"
if [[ ! "$SIM" =~ ^[0-9A-F-]{36}$ ]]; then
  SIM=$(xcrun simctl list devices | grep -F "$SIM (" | head -1 | grep -oE '[0-9A-F-]{36}')
fi
mkdir -p "$OUT"; : > "$OUT/results.tsv"
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
for f in .maestro/$GLOB; do
  name=$(basename "$f" .yaml); start=$(date +%s)
  "$(dirname "$0")/reset-state.sh" >/dev/null 2>&1 || true   # repeatable flows
  if maestro --device "$SIM" test -e EMAIL="${EMAIL:-maya@blnd.local}" -e PASSWORD="${PASSWORD:-Premium123!}" -e USERNAME_B="${USERNAME_B:-leo}" -e EMAIL_A="${EMAIL_A:-sam@blnd.local}" --test-output-dir "$OUT/$name" "$f" >"$OUT/$name.log" 2>&1; then r=PASS; else r=FAIL; fi
  # optional server-side assertion: .maestro/<flow>.verify.sh must exit 0 (UI alone can't prove data was saved)
  if [ "$r" = PASS ] && [ -x ".maestro/$name.verify.sh" ] && ! ".maestro/$name.verify.sh" >>"$OUT/$name.log" 2>&1; then r=FAIL; echo "DB verify failed" >>"$OUT/$name.log"; fi
  # maestro nests output in a timestamp dir; flatten so paths are predictable
  for d in "$OUT/$name"/20*/*/; do [ -d "$d" ] && cp -R "$d"/. "$OUT/$name/" 2>/dev/null; done
  printf '%s\t%s\t%s\n' "$name" "$r" "$(( $(date +%s) - start ))" | tee -a "$OUT/results.tsv"
done
echo "artifacts: $OUT"
grep -c PASS "$OUT/results.tsv" | xargs echo "passed:"; grep -c FAIL "$OUT/results.tsv" | xargs echo "failed:"
