#!/usr/bin/env bash
# run.sh — tests for the waybar-workspace custom-button state script: the
# active/occupied/empty classes, and the urgent flag raised by Hyprland's
# `urgent>>ADDR` event when a window opens on an unfocused workspace (a link
# from another workspace's terminal), sticky until the workspace is visited.

set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)
script=$repo_root/packaging/shedos-hyprland/tree/usr/lib/shedos/waybar-workspace

fail=0
_ok()  { echo "ok: $1"; }
_bad() { echo "FAIL: $1" >&2; fail=1; }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

td=$(mktemp -d)
trap 'exec 9>&- 2>/dev/null; rm -rf "$td"' EXIT

# Fake hyprctl reading harness-staged state.
export STATE=$td/state
mkdir -p "$STATE" "$td/bin"
cat > "$td/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    activeworkspace) printf '{"id": %s}\n' "$(cat "$STATE/active")" ;;
    workspaces)      printf '[{"id": 2, "windows": %s}]\n' "$(cat "$STATE/ws2windows")" ;;
    clients)         cat "$STATE/clients.json" ;;
esac
EOF
chmod +x "$td/bin/hyprctl"

# Initial state: on workspace 1, workspace 2 empty; one client parked on
# workspace 2 and another on workspace 3 for the urgent-resolution cases.
echo 1 > "$STATE/active"
echo 0 > "$STATE/ws2windows"
cat > "$STATE/clients.json" <<'EOF'
[
  {"address": "0xaabb", "workspace": {"id": 2}},
  {"address": "0xdead", "workspace": {"id": 3}}
]
EOF

out=$td/out
fifo=$td/events
mkfifo "$fifo"

SHEDOS_WS_EVENTS_FILE=$fifo PATH=$td/bin:$PATH bash "$script" 2 > "$out" &
script_pid=$!
exec 9>"$fifo"

_wait_lines() {
    local n=$1 tries=0
    while [ "$(wc -l < "$out")" -lt "$n" ]; do
        sleep 0.1
        tries=$((tries + 1))
        if [ "$tries" -gt 50 ]; then return 1; fi
    done
    return 0
}

_class_of() { sed -n "${1}p" "$out" | jq -r '.class'; }

# T1: first emit — not active, no windows → empty.
if _wait_lines 1 && [ "$(_class_of 1)" = empty ]; then
    _ok "T1 initial state is empty"
else
    _bad "T1 initial emit wrong: $(cat "$out")"
fi

# T2: a window on THIS workspace turns urgent → class urgent.
echo 'urgent>>aabb' >&9
if _wait_lines 2 && [ "$(_class_of 2)" = urgent ]; then
    _ok "T2 urgent window on this workspace raises the flag"
else
    _bad "T2 urgent not raised: $(cat "$out")"
fi

# T3: an urgent window on ANOTHER workspace is ignored (no new emit).
echo 'urgent>>dead' >&9
sleep 0.4
if [ "$(wc -l < "$out")" -eq 2 ]; then
    _ok "T3 urgent on another workspace is ignored"
else
    _bad "T3 unexpected emit: $(cat "$out")"
fi

# T4: visiting the workspace clears urgency → active.
echo 2 > "$STATE/active"
echo 'workspace>>2' >&9
if _wait_lines 3 && [ "$(_class_of 3)" = active ]; then
    _ok "T4 visiting clears urgency (active)"
else
    _bad "T4 wrong class on visit: $(cat "$out")"
fi

# T5: leaving again with a window present → occupied, urgency stays cleared.
echo 1 > "$STATE/active"
echo 1 > "$STATE/ws2windows"
echo 'workspace>>1' >&9
if _wait_lines 4 && [ "$(_class_of 4)" = occupied ]; then
    _ok "T5 urgency stays cleared after the visit (occupied)"
else
    _bad "T5 wrong class after leaving: $(cat "$out")"
fi

exec 9>&-
wait "$script_pid" 2>/dev/null

if (( fail )); then
    echo "waybar-workspace: FAILURES" >&2
    exit 1
fi
echo "waybar-workspace: all tests passed"
