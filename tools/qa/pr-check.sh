#!/usr/bin/env bash
# Local PR gate (macOS runners in CI are ~10x the price, so iOS tests run on this Mac).
#   tools/qa/pr-check.sh <pr-number> [--merge] [--no-post]
# 1. builds the PR on its own sim (blnd-pr-<n>) against the local backend
# 2. runs iOS unit tests + all Maestro flows (screenshots)
# 3. writes the mini paper to ~/cursor-work/papers/<date>-pr-<n>/
# 4. posts a PR comment + a `blnd/local-qa` commit status (skip with --no-post)
# 5. with --merge (or PR label `automerge`): squash-merges into dev if everything required passed
# "Required" = unit tests + flows listed in .maestro/required.txt (default: all except flows marked PENDING).
set -uo pipefail
PR="${1:?usage: pr-check.sh <pr> [--merge] [--no-post]}"; shift || true
MERGE=0; POST=1; for a in "$@"; do case $a in --merge) MERGE=1;; --no-post) POST=0;; esac; done
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; WORK="$HOME/cursor-work/qa"; cd "$REPO"
SLUG="pr-$PR"; OUT="$WORK/artifacts/$SLUG"; rm -rf "$OUT"; mkdir -p "$OUT"
NWO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
INFO=$(gh pr view "$PR" --json title,headRefOid,baseRefName,labels,body)
SHA=$(echo "$INFO" | python3 -c 'import sys,json;print(json.load(sys.stdin)["headRefOid"])')
BASE=$(echo "$INFO" | python3 -c 'import sys,json;print(json.load(sys.stdin)["baseRefName"])')
echo "$INFO" | python3 -c 'import sys,json;print("automerge" if any(l["name"]=="automerge" for l in json.load(sys.stdin)["labels"]) else "")' | grep -q automerge && MERGE=1
[ $POST = 1 ] && gh api -X POST "repos/$NWO/statuses/$SHA" -f state=pending -f context=blnd/local-qa -f description="running on Jonathan's Mac" >/dev/null 2>&1

tools/qa/warm.sh up || exit 2
git fetch -q origin "+refs/pull/$PR/head:refs/remotes/origin/pr/$PR"
app=$(BLND_PORT="${BLND_PORT:-8100}" tools/qa/warm.sh pr "$PR" 2>&1 | tail -1); echo "$app"
SIM_NAME="blnd-pr-$PR"

# unit tests from the PR worktree on the PR sim
WT="$WORK/builds/pr-$PR"
( cd "$WT" && xcodebuild test -project blnd_ios.xcodeproj -scheme blnd_ios -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -only-testing:blnd_iosTests "API_BASE_URL=http://localhost:8100" -derivedDataPath "$WORK/dd/pr-$PR" \
    -resultBundlePath "$OUT/unit.xcresult" >"$OUT/unit.log" 2>&1 )
xcrun xcresulttool get test-results summary --path "$OUT/unit.xcresult" --compact > "$OUT/unit.json" 2>/dev/null
python3 - "$OUT" <<'PY'
import json,sys
o=sys.argv[1]
try: d=json.load(open(o+"/unit.json"))
except Exception: d={}
t=d.get("totalTestCount",0); f=d.get("failedTests",0); s=d.get("skippedTests",0)
open(o+"/unit.xml","w").write(f'<testsuite tests="{t}" failures="{f}" skipped="{s}" errors="0"/>')
PY

# UI flows always come from THIS checkout (the PR build is only the app under test), so older PR branches are tested too
( cd "$REPO" && tools/qa/run-flows.sh "$SIM_NAME" "$OUT/flows" ) | tail -3
# baseline = latest dev run if present
BEFORE=$(ls -dt "$WORK"/artifacts/maestro-dev* 2>/dev/null | head -1)

TASK=$(echo "$INFO" | python3 -c 'import sys,json;print(json.load(sys.stdin)["body"][:600])')
PAPER=$(tools/qa/feature-paper.py --slug "$SLUG" --pr "$PR" --repo "$NWO" --task "$TASK" \
   --after "$OUT/flows" ${BEFORE:+--before "$BEFORE"} --flows-after "$OUT/flows/results.tsv" --unit-junit "$OUT/unit.xml" 2>/dev/null | tail -1)
VERDICT=$(sed -n 2p "$PAPER/summary.md" | sed 's/\*\*Verdict:\*\* //')

# required flows
REQ="$REPO/.maestro/required.txt"; FAILED_REQ=0
while IFS=$'\t' read -r flow res _; do
  if [ -f "$REQ" ]; then grep -qx "$flow" "$REQ" || continue; fi
  [ "$res" = PASS ] || FAILED_REQ=1
done < "$OUT/flows/results.tsv"
grep -q 'failures="0"' "$OUT/unit.xml" || FAILED_REQ=1
STATE=success; [ $FAILED_REQ = 1 ] && STATE=failure
echo "verdict: $VERDICT | gate: $STATE | paper: $PAPER/index.html"
if [ $POST = 1 ]; then
  gh api -X POST "repos/$NWO/statuses/$SHA" -f state=$STATE -f context=blnd/local-qa -f description="${VERDICT:0:130}" >/dev/null 2>&1
  gh pr comment "$PR" --body "**blnd local QA:** $VERDICT

Mini paper (screenshots, per-flow results): \`$PAPER/index.html\` on Jonathan's Mac. Flows run: $(wc -l < "$OUT/flows/results.tsv")." >/dev/null 2>&1
fi
if [ $MERGE = 1 ] && [ $STATE = success ] && [ "$BASE" = dev ]; then gh pr merge "$PR" --squash --delete-branch && echo merged; fi
[ $STATE = success ]
