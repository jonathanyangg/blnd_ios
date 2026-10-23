#!/usr/bin/env bash
# Warm simulators for Jonathan: booted, signed in, latest build installed, local backend + seed data running.
#
#   tools/qa/warm.sh up                 start Supabase/backend, boot warm sims (idempotent, safe to run any time)
#   tools/qa/warm.sh refresh [ref]      build ref (default origin/dev), install on all warm sims, sign in, screenshot
#   tools/qa/warm.sh pr <number>        build a PR branch into its own sim "blnd-pr-<n>", sign in, screenshot, open it
#   tools/qa/warm.sh wt <worktree-dir>  build whatever is in a worktree (committed or not) into its OWN sim "blnd-wt-<dirname>"
#   tools/qa/warm.sh gc                 delete the per-PR / per-worktree sims (blnd-pr-*, blnd-wt-*)
#   tools/qa/warm.sh open [name]        bring a sim window to the front (default blnd-warm-1)
#   tools/qa/warm.sh status             what is running / which build is where
#   tools/qa/warm.sh launchd-install    keep `up` running at login and every 10 min (survives sleep/reboot)
#   tools/qa/warm.sh launchd-remove
#
# Config (env, all optional):
#   BLND_BACKEND_DIR   backend checkout with scripts/qa/serve-local.sh   (default ~/cursor-work/qa/run-backend)
#   BLND_PORT          local backend port                                 (default 8100)
#   BLND_SIMS          space separated sim names to keep warm             (default "blnd-warm-1 blnd-warm-2 blnd-warm-3")
#   BLND_DEVICE_TYPE   simulator model for new sims                       (default "iPhone 17 Pro")
# Sim roles: 1 = premium (maya), 2 = free (sam, sees paywall), 3 = premium (leo, maya's friend, for Blend invites).
set -uo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${BLND_WORK:-$HOME/cursor-work/qa}"
BACKEND_DIR="${BLND_BACKEND_DIR:-$HOME/cursor-work/qa/run-backend}"
PORT="${BLND_PORT:-8100}"
SIMS=(${BLND_SIMS:-blnd-warm-1 blnd-warm-2 blnd-warm-3})
DEVICE_TYPE="${BLND_DEVICE_TYPE:-iPhone 17 Pro}"
PW='Premium123!'   # local seed demo password (supabase/seed.sql), not a secret
role_email() { case "$1" in *-2) echo sam@blnd.local;; *-3) echo leo@blnd.local;; *) echo maya@blnd.local;; esac; }
log() { printf '[warm] %s\n' "$*"; }
udid() { xcrun simctl list devices | grep -F "    $1 (" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1; }

ensure_sim() { # name -> udid (creates if missing)
  local n="$1" u; u=$(udid "$n")
  if [ -z "$u" ]; then
    local rt; rt=$(xcrun simctl list runtimes | grep -E 'iOS' | grep -v unavailable | tail -1 | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.[A-Za-z0-9-]+')
    u=$(xcrun simctl create "$n" "$DEVICE_TYPE" "$rt"); log "created $n $u" >&2
  fi
  echo "$u"
}
boot_sim() {
  local u="$1"
  xcrun simctl bootstatus "$u" -b >/dev/null 2>&1 || true
  xcrun simctl status_bar "$u" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4 --operatorName "" >/dev/null 2>&1 || true
}

cmd_up() {
  # 1. Supabase (docker) -- only starts existing containers; `supabase start` is needed once per machine.
  if ! docker info >/dev/null 2>&1; then log "starting Docker Desktop"; open -a Docker; for _ in $(seq 60); do docker info >/dev/null 2>&1 && break; sleep 3; done; fi
  for c in $(docker ps -a --filter "name=supabase_.*_blnd_backend" --format '{{.Names}}'); do docker start "$c" >/dev/null 2>&1; done
  # Docker Desktop sometimes drops host port forwarding while containers look healthy -> restart kong+db to republish :54321/:54322
  for _ in $(seq 10); do curl -s -m 3 -o /dev/null http://127.0.0.1:54321/auth/v1/health && break; sleep 3; done
  if ! curl -s -m 3 -o /dev/null http://127.0.0.1:54321/auth/v1/health; then log "supabase ports not reachable, restarting kong+db"; docker restart supabase_kong_blnd_backend supabase_db_blnd_backend >/dev/null 2>&1; sleep 15; fi
  if ! docker ps --format '{{.Names}}' | grep -q '^supabase_db_blnd_backend$'; then
    log "Supabase is not running. First time? run: (cd $BACKEND_DIR && supabase start)"; return 1
  fi
  # 2. seed demo users (maya/leo premium, sam free), idempotent
  if [ -f "$BACKEND_DIR/supabase/seed.sql" ]; then
    docker exec -i supabase_db_blnd_backend psql -U postgres -d postgres -q -v ON_ERROR_STOP=0 < "$BACKEND_DIR/supabase/seed.sql" >/dev/null 2>&1
  fi
  # 3. backend
  if ! curl -fsS -m 3 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && ! curl -sS -m 3 -o /dev/null "http://127.0.0.1:$PORT/openapi.json"; then
    log "starting backend on :$PORT"
    mkdir -p "$WORK/reports"
    (cd "$BACKEND_DIR" && PORT=$PORT nohup scripts/qa/serve-local.sh >"$WORK/reports/serve-$PORT.log" 2>&1 &)
    for _ in $(seq 40); do curl -sS -m 2 -o /dev/null "http://127.0.0.1:$PORT/openapi.json" && break; sleep 2; done
  fi
  # 4. sims
  for n in "${SIMS[@]}"; do u=$(ensure_sim "$n"); boot_sim "$u"; done
  log "up: backend :$PORT, sims: ${SIMS[*]}"
}

build_ref() { # ref slug -> prints .app path
  local ref="$1" slug="$2" wt="$WORK/builds/$2"
  mkdir -p "$WORK/builds"
  git -C "$REPO" fetch -q origin "+refs/heads/*:refs/remotes/origin/*" "+refs/pull/*/head:refs/remotes/origin/pr/*" 2>/dev/null
  if [ -d "$wt" ]; then git -C "$wt" checkout -q --detach "$ref" 2>&1 >&2; else git -C "$REPO" worktree add -q --detach "$wt" "$ref" >&2; fi
  ( cd "$wt" && xcodebuild -project blnd_ios.xcodeproj -scheme blnd_ios -configuration Debug \
      -destination 'generic/platform=iOS Simulator' -derivedDataPath "$WORK/dd/$slug" \
      "API_BASE_URL=http://localhost:$PORT" build >"$WORK/reports/build-$slug.log" 2>&1 ) \
    || { log "BUILD FAILED, see $WORK/reports/build-$slug.log"; tail -15 "$WORK/reports/build-$slug.log" >&2; return 1; }
  echo "$WORK/dd/$slug/Build/Products/Debug-iphonesimulator/blnd_ios.app"
}

install_and_login() { # udid name app
  local u="$1" n="$2" app="$3" em; em=$(role_email "$n")
  boot_sim "$u"
  xcrun simctl terminate "$u" com.jonathan.blnd-ios >/dev/null 2>&1
  xcrun simctl install "$u" "$app" || return 1
  xcrun simctl privacy "$u" grant all com.jonathan.blnd-ios >/dev/null 2>&1
  ( cd "$REPO" && maestro --device "$u" test -e EMAIL="$em" -e PASSWORD="$PW" \
      --test-output-dir "$WORK/artifacts/warm/$n" .maestro/subflows/warm_login.yaml >"$WORK/reports/warm-login-$n.log" 2>&1 ) \
    && log "$n signed in as $em" || log "$n sign-in FAILED, see $WORK/reports/warm-login-$n.log"
}

cmd_refresh() {
  local ref="${1:-origin/dev}"; cmd_up || return 1
  git -C "$REPO" fetch -q origin 2>/dev/null; local sha; sha=$(git -C "$REPO" rev-parse --short "$ref")
  app=$(build_ref "$ref" "dev") || return 1
  for n in "${SIMS[@]}"; do
    install_and_login "$(udid "$n")" "$n" "$app" &
  done; wait
  echo "$sha $(date '+%F %T')" > "$WORK/warm-build.txt"
  for n in "${SIMS[@]}"; do
    mkdir -p "$WORK/artifacts/warm/$n"; xcrun simctl io "$(udid "$n")" screenshot "$WORK/artifacts/warm/$n/home.png" >/dev/null 2>&1
  done
  log "refreshed all warm sims to $sha. Screenshots: $WORK/artifacts/warm/*/home.png"
}

cmd_pr() {
  local pr="${1:?usage: warm.sh pr <number>}"; cmd_up || return 1
  local n="blnd-pr-$pr" u app; u=$(ensure_sim "$n")
  app=$(build_ref "origin/pr/$pr" "pr-$pr") || return 1
  install_and_login "$u" "blnd-pr-1" "$app"   # role 1 = premium maya
  mkdir -p "$WORK/artifacts/pr-$pr"; xcrun simctl io "$u" screenshot "$WORK/artifacts/pr-$pr/home.png" >/dev/null 2>&1
  open -a Simulator --args -CurrentDeviceUDID "$u"
  log "PR #$pr is on sim '$n' (signed in as maya). Delete it later: xcrun simctl delete $n"
}

cmd_wt() { # build a worktree as-is into its own sim; never modifies the worktree (separate derived data)
  local dir; dir=$(cd "${1:?usage: warm.sh wt <worktree-dir>}" && pwd) || return 1
  [ -d "$dir/blnd_ios.xcodeproj" ] || { log "$dir has no blnd_ios.xcodeproj"; return 1; }
  cmd_up || return 1
  local slug; slug=$(basename "$dir"); local n="blnd-wt-$slug" u; u=$(ensure_sim "$n")
  mkdir -p "$WORK/reports" "$WORK/artifacts/wt-$slug"
  ( cd "$dir" && xcodebuild -project blnd_ios.xcodeproj -scheme blnd_ios -configuration Debug \
      -destination 'generic/platform=iOS Simulator' -derivedDataPath "$WORK/dd/wt-$slug" \
      "API_BASE_URL=http://localhost:$PORT" build >"$WORK/reports/build-wt-$slug.log" 2>&1 ) \
    || { log "BUILD FAILED, see $WORK/reports/build-wt-$slug.log"; tail -15 "$WORK/reports/build-wt-$slug.log" >&2; return 1; }
  install_and_login "$u" "blnd-wt-1" "$WORK/dd/wt-$slug/Build/Products/Debug-iphonesimulator/blnd_ios.app"
  xcrun simctl io "$u" screenshot "$WORK/artifacts/wt-$slug/home.png" >/dev/null 2>&1
  open -a Simulator --args -CurrentDeviceUDID "$u"
  log "worktree '$slug' ($(git -C "$dir" rev-parse --short HEAD 2>/dev/null) + uncommitted) is on sim '$n' (signed in as maya)"
}

cmd_gc() { for n in $(xcrun simctl list devices | grep -oE 'blnd-(pr|wt)-[A-Za-z0-9._-]+' | sort -u); do xcrun simctl delete "$n" && log "deleted sim $n"; done; }

cmd_open() { local n="${1:-blnd-warm-1}"; open -a Simulator --args -CurrentDeviceUDID "$(udid "$n")"; }

cmd_status() {
  echo "backend :$PORT -> $(curl -sS -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT/openapi.json 2>/dev/null)"
  echo "supabase db -> $(docker ps --format '{{.Names}}' 2>/dev/null | grep -c '^supabase_db_blnd_backend$') running"
  echo "last build  -> $(cat "$WORK/warm-build.txt" 2>/dev/null || echo none)"
  xcrun simctl list devices | grep -E "blnd-(warm|pr|wt)" | sed 's/^ *//'
}

PLIST="$HOME/Library/LaunchAgents/com.blnd.warm.plist"
cmd_launchd_install() {
  cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.blnd.warm</string>
<key>ProgramArguments</key><array><string>/bin/bash</string><string>-lc</string><string>$REPO/tools/qa/warm.sh up</string></array>
<key>RunAtLoad</key><true/><key>StartInterval</key><integer>600</integer>
<key>StandardOutPath</key><string>$WORK/reports/warm-launchd.log</string><key>StandardErrorPath</key><string>$WORK/reports/warm-launchd.log</string>
<key>EnvironmentVariables</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.maestro/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
</dict></plist>
PL
  launchctl unload "$PLIST" 2>/dev/null; launchctl load "$PLIST" && log "launchd agent installed: runs 'warm.sh up' at login and every 10 min"
}
cmd_launchd_remove() { launchctl unload "$PLIST" 2>/dev/null; rm -f "$PLIST"; log removed; }

c="${1:-status}"; shift || true
case "$c" in up|refresh|pr|wt|gc|open|status|launchd-install|launchd-remove) "cmd_${c//-/_}" "$@";; *) sed -n 2,20p "$0"; exit 1;; esac
