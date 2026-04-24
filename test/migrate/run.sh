#!/usr/bin/env bash
# run.sh — test harness for shedman migrate.
#
# Each fixture under fixtures/<name>/ models one migration scenario:
#
#   initial-root/    synthetic root filesystem (at minimum
#                    initial-root/etc/pacman.conf, optionally more).
#                    Copied into a tmpdir before the run and pointed
#                    at via SHEDOS_MIGRATE_ROOT.
#   stubs/           optional dir of stub binaries put at the front
#                    of PATH (pacman / snapper / shedman). Each stub
#                    can read PROBE_LOG env to append invocation
#                    traces for assertions.
#   args             arg string passed to the tool (one line)
#   expected-exit    expected exit code (default 0)
#   expected-output  (optional) expected stdout+stderr; diffed if
#                    present, otherwise ignored.
#   expected-probe   (optional) expected trace from the stubs — each
#                    stub appends its name + args to $PROBE_LOG when
#                    invoked, so the fixture can assert "pacman was
#                    called with these exact args".
#   expected-pacman-conf (optional) expected contents of
#                    $SHEDOS_MIGRATE_ROOT/etc/pacman.conf after the run.
#
# Exit: 0 all pass, 1 any failure.

set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)
tool=$repo_root/packaging/shedos-migrate-to-packaged/tree/usr/libexec/shedman/migrate

if [[ ! -x $tool ]]; then
    echo "FATAL: $tool not executable" >&2
    exit 2
fi

if (( $# > 0 )); then
    fixtures=("$@")
else
    fixtures=()
    while IFS= read -r -d '' d; do
        fixtures+=("$(basename "$d")")
    done < <(find "$here/fixtures" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
fi

pass=0
fail=0
failures=()

_diff_file() {
    local label=$1 expected=$2 actual=$3
    if ! diff -u "$expected" "$actual" >/dev/null 2>&1; then
        echo "  $label mismatch:"
        diff -u "$expected" "$actual" | sed 's/^/    /' | head -60
        return 1
    fi
    return 0
}

_run_one() {
    local name=$1
    local fdir=$here/fixtures/$name
    [[ -d $fdir ]] || { echo "skip $name (no such fixture)"; return; }

    local args="--dry-run" exit_code=0
    [[ -f $fdir/args ]] && args=$(<"$fdir/args")
    [[ -f $fdir/expected-exit ]] && exit_code=$(<"$fdir/expected-exit")

    local tmp
    tmp=$(mktemp -d -t shedos-migrate-test.XXXXXX)
    trap 'rm -rf -- "$tmp"' RETURN

    local root=$tmp/root probe=$tmp/probe.log
    mkdir -p "$root"
    if [[ -d $fdir/initial-root ]]; then
        cp -a "$fdir/initial-root/." "$root/"
    fi
    : > "$probe"

    # Prepend the fixture's stub dir to PATH so `pacman`, `snapper`,
    # `shedman` etc. resolve to fixture-controlled stubs.
    local stub_path=""
    if [[ -d $fdir/stubs ]]; then
        stub_path=$fdir/stubs
    fi

    local out rc
    out=$tmp/out
    # shellcheck disable=SC2086  # intentional word-splitting of $args
    PATH="${stub_path:+$stub_path:}$PATH" \
        SHEDOS_MIGRATE_ROOT="$root" \
        PROBE_LOG="$probe" \
        "$tool" $args >"$out" 2>&1
    rc=$?

    local bad=0
    if (( rc != exit_code )); then
        echo "FAIL $name: exit $rc (expected $exit_code)"
        sed 's/^/    /' "$out"
        failures+=("$name")
        ((fail++))
        return
    fi

    if [[ -f $fdir/expected-output ]]; then
        _diff_file "output" "$fdir/expected-output" "$out" || bad=1
    fi
    if [[ -f $fdir/expected-probe ]]; then
        _diff_file "probe" "$fdir/expected-probe" "$probe" || bad=1
    fi
    if [[ -f $fdir/expected-pacman-conf ]]; then
        _diff_file "pacman.conf" "$fdir/expected-pacman-conf" \
            "$root/etc/pacman.conf" || bad=1
    fi

    if (( bad )); then
        echo "FAIL $name"
        failures+=("$name")
        ((fail++))
        return
    fi
    echo "PASS $name"
    ((pass++))
}

for f in "${fixtures[@]}"; do
    _run_one "$f"
done

echo
echo "Summary: $pass passed, $fail failed"
if (( fail > 0 )); then
    printf '  %s\n' "${failures[@]}"
    exit 1
fi
exit 0
