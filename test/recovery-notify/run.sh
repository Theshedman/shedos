#!/usr/bin/env bash
# Assert recovery-notify renders the right message per marker kind: no-kind
# and kind=rollback give today's rollback notice, kind=fstab gives the
# missing-disk notice. Drives the real script via a stubbed notify-send.
# Hermetic + root-less.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd -- "$here/../.." && pwd)
tool=$repo/packaging/shedos-hyprland/tree/usr/libexec/shedos-hyprland/recovery-notify

[[ -f $tool ]] || { echo "FATAL: $tool missing" >&2; exit 2; }

pass=0
fail=0
failures=()
_ok()   { printf 'ok: %s\n' "$1"; ((pass++)); }
_fail() { printf 'FAIL: %s — %s\n' "$1" "$2" >&2; failures+=("$1"); ((fail++)); }

# _run <marker-contents> — run recovery-notify against a throwaway marker with
# a stubbed notify-send, and echo the captured argv (one arg per line).
_run() {
    local body=$1
    local tmp; tmp=$(mktemp -d)
    local marker=$tmp/recovered-from stamp=$tmp/stamp log=$tmp/notify.log
    printf '%s' "$body" > "$marker"
    mkdir -p "$tmp/bin"
    cat > "$tmp/bin/notify-send" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "$log"
STUB
    chmod +x "$tmp/bin/notify-send"
    PATH="$tmp/bin:$PATH" SHEDOS_RECOVERED_FROM=$marker SHEDOS_RECOVERY_STAMP=$stamp \
        bash "$tool" || true
    [[ -f $log ]] && cat "$log"
    rm -rf "$tmp"
}

out=$(_run $'snapshot=42\nclone=@recovery-x\nfailed_boots=3\n')
if grep -qF 'ShedOS recovered from a failed update' <<<"$out" \
   && grep -qF 'sudo shedman rollback 42' <<<"$out"; then
    _ok RN1_legacy_no_kind_rollback
else
    _fail RN1_legacy_no_kind_rollback "no-kind marker did not render rollback: $out"
fi

out=$(_run $'kind=rollback\nsnapshot=7\n')
if grep -qF 'safe copy of snapshot #7' <<<"$out"; then
    _ok RN2_kind_rollback
else
    _fail RN2_kind_rollback "kind=rollback did not render rollback: $out"
fi

out=$(_run $'kind=fstab\ntargets=/mnt/backup\nbackup=/etc/fstab.shedos-emergency-bak-x\n')
if grep -qF 'ShedOS recovered your boot' <<<"$out" \
   && grep -qF '/mnt/backup' <<<"$out" \
   && grep -qF 'shedman doctor' <<<"$out"; then
    _ok RN3_kind_fstab
else
    _fail RN3_kind_fstab "kind=fstab did not render the fstab message: $out"
fi

echo
echo "recovery-notify: $pass/$((pass + fail)) passed"
(( fail == 0 )) || { printf '  %s\n' "${failures[@]}"; exit 1; }
