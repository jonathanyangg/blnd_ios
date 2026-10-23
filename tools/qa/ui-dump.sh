#!/usr/bin/env bash
# Print the visible accessibility labels / ids on a simulator (helps write Maestro flows).
#   tools/qa/ui-dump.sh [SIM_UDID|booted]
SIM="${1:-booted}"
maestro --device "$SIM" hierarchy 2>/dev/null | python3 -c '
import json,sys
raw=sys.stdin.read(); d=json.loads(raw[raw.find("{"):])
def walk(n,depth=0):
    a=n.get("attributes",{}); t=a.get("text") or a.get("accessibilityText") or ""; rid=a.get("resource-id","")
    if t or rid: print("  "*min(depth,6), repr(t)[:70], ("#"+rid) if rid else "")
    for c in n.get("children",[]): walk(c,depth+1)
walk(d)'
