#!/usr/bin/env bash
# run.sh — integration tests for the Meld backend (--gui) in
# _config-review.
#
# Each fixture under fixtures/<name>/ holds a Meld scenario:
#
#   fixture.sh        shell vars: PKG=<pkg-name>  RELPATH=<path> (single
#                     file), or PKGS=(...) RELPATHS=(...) for multi-file
#                     fixtures. May also set:
#
#                       EXPECT_SAVED=1            yours updated, .shedosnew gone
#                       EXPECT_UNCHANGED=1        yours kept, .shedosnew kept
#                       EXPECT_MARKER_SKIPPED=1   marker detected, .shedosnew kept
#                       EXPECT_ARGV_LINES=N       fake-meld invoked N times
#                       EXPECT_ARGV_PANES=3|2     each invocation has N pane args
#                       EXPECT_STDERR_PATTERN=…   grep -E pattern that must match
#
#   src               pristine default shipped by the package
#   base              last-seen BASE snapshot (3-way; omit for 2-way)
#   yours             the user's live $HOME copy
#   theirs            the upstream .shedosnew content
#   expected          (only if EXPECT_SAVED=1) expected merged content after
#                     copy-back
#   action.sh         (optional) bash snippet sourced by fake-meld with
#                     YOURS_DIR / BASE_DIR / THEIRS_DIR set; simulates
#                     the user editing files in the yours/ staging tree
#
# Multi-file fixtures use {src,base,yours,theirs,expected}.<idx> files
# keyed off PKGS[i]/RELPATHS[i].
#
# Usage: test/review-meld/run.sh [fixture-name ...]
# Exit:  0 all pass, 1 any failure.

set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)
tool=$repo_root/packaging/shedos-system/tree/usr/libexec/shedman/_config-review
fake_meld=$here/fake-meld

if [[ ! -x $tool ]]; then
    echo "FATAL: $tool not executable" >&2
    exit 2
fi
if [[ ! -x $fake_meld ]]; then
    echo "FATAL: $fake_meld not executable" >&2
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

_stage_one() {
    # Args: home defaults state pkg relpath src yours theirs [base]
    local home=$1 defaults=$2 state=$3 pkg=$4 relpath=$5
    local src=$6 yours=$7 theirs=$8 base=${9:-}
    install -Dm644 "$yours"   "$home/$relpath"
    install -Dm644 "$theirs"  "$home/$relpath.shedosnew"
    install -Dm644 "$src"     "$defaults/$pkg/defaults/$relpath"
    if [[ -n $base ]]; then
        local sha
        sha=$(sha256sum "$base" | awk '{print $1}')
        install -Dm600 /dev/null "$state/shedos/last-seen/$relpath.sha256"
        printf '%s' "$sha" > "$state/shedos/last-seen/$relpath.sha256"
        install -Dm600 "$base" "$state/shedos/last-seen-content/$relpath"
    fi
}

_run_one() {
    local name=$1
    local fdir=$here/fixtures/$name
    [[ -d $fdir ]] || { echo "skip $name (no such fixture)"; return; }
    [[ -f $fdir/fixture.sh ]] || { echo "skip $name (no fixture.sh)"; return; }

    # Defaults
    local PKG="" RELPATH=""
    local PKGS=() RELPATHS=()
    local EXPECT_SAVED="" EXPECT_UNCHANGED="" EXPECT_MARKER_SKIPPED=""
    local EXPECT_ARGV_LINES="" EXPECT_ARGV_PANES=""
    local EXPECT_STDERR_PATTERN=""
    # shellcheck disable=SC1090
    source "$fdir/fixture.sh"

    # Single-file fixtures populate PKG/RELPATH; multi-file use arrays.
    if [[ -n $PKG && -n $RELPATH && ${#PKGS[@]} -eq 0 ]]; then
        PKGS=("$PKG")
        RELPATHS=("$RELPATH")
    fi
    if [[ ${#PKGS[@]} -eq 0 || ${#RELPATHS[@]} -eq 0 ]]; then
        echo "FAIL $name: fixture.sh must set PKG/RELPATH or PKGS/RELPATHS"
        failures+=("$name"); ((fail++)); return
    fi

    local tmp
    tmp=$(mktemp -d -t shedos-review-meld-test.XXXXXX)
    trap 'rm -rf -- "$tmp"' RETURN

    local home=$tmp/home
    local state=$tmp/state
    local defaults=$tmp/defaults
    local argv_log=$tmp/argv.log
    mkdir -p "$home" "$state" "$defaults"
    : > "$argv_log"

    local i count=${#PKGS[@]}
    for ((i=0; i<count; i++)); do
        local suffix=""
        (( count > 1 )) && suffix=".$i"
        local fbase=$fdir/base$suffix
        [[ -f $fbase ]] || fbase=""
        _stage_one "$home" "$defaults" "$state" \
            "${PKGS[i]}" "${RELPATHS[i]}" \
            "$fdir/src$suffix" "$fdir/yours$suffix" "$fdir/theirs$suffix" \
            "$fbase"
    done

    local extra_action=()
    if [[ -f $fdir/action.sh ]]; then
        extra_action=("SHEDOS_FAKE_MELD_ACTION=$fdir/action.sh")
    fi

    local stderr_file=$tmp/stderr
    if ! HOME=$home \
        XDG_STATE_HOME=$state \
        SHEDOS_DEFAULTS_ROOT=$defaults \
        SHEDOS_MELD_BIN=$fake_meld \
        SHEDOS_FAKE_MELD_ARGV_FILE=$argv_log \
        env "${extra_action[@]}" \
        "$tool" --gui 2> "$stderr_file" > /dev/null
    then
        echo "FAIL $name: tool exited non-zero"
        sed 's/^/    /' "$stderr_file" | head -20
        failures+=("$name"); ((fail++)); return
    fi

    # Per-file assertions.
    for ((i=0; i<count; i++)); do
        local suffix=""
        (( count > 1 )) && suffix=".$i"
        local rel=${RELPATHS[i]}
        local live=$home/$rel
        local theirs=$home/$rel.shedosnew
        local bak=$home/$rel.shedosbak

        if [[ ${EXPECT_SAVED:-0} == "1" ]]; then
            if ! cmp -s "$live" "$fdir/expected$suffix"; then
                echo "FAIL $name [$rel]: live does not match expected"
                diff -u "$fdir/expected$suffix" "$live" 2>&1 \
                    | sed 's/^/    /' | head -20
                failures+=("$name"); ((fail++)); return
            fi
            if [[ -e $theirs ]]; then
                echo "FAIL $name [$rel]: .shedosnew should have been removed"
                failures+=("$name"); ((fail++)); return
            fi
            if [[ ! -f $bak ]] || ! cmp -s "$bak" "$fdir/yours$suffix"; then
                echo "FAIL $name [$rel]: .shedosbak missing or wrong content"
                failures+=("$name"); ((fail++)); return
            fi
            local src_sha stored_sha
            src_sha=$(sha256sum "$fdir/src$suffix" | awk '{print $1}')
            stored_sha=$(tr -d '[:space:]' < "$state/shedos/last-seen/$rel.sha256" 2>/dev/null || echo "")
            if [[ $stored_sha != "$src_sha" ]]; then
                echo "FAIL $name [$rel]: manifest sha not advanced to sha(src)"
                failures+=("$name"); ((fail++)); return
            fi
        elif [[ ${EXPECT_UNCHANGED:-0} == "1" || ${EXPECT_MARKER_SKIPPED:-0} == "1" ]]; then
            if ! cmp -s "$live" "$fdir/yours$suffix"; then
                echo "FAIL $name [$rel]: live should be untouched"
                failures+=("$name"); ((fail++)); return
            fi
            if [[ ! -e $theirs ]]; then
                echo "FAIL $name [$rel]: .shedosnew should remain"
                failures+=("$name"); ((fail++)); return
            fi
            if [[ -e $bak ]]; then
                echo "FAIL $name [$rel]: .shedosbak should NOT exist"
                failures+=("$name"); ((fail++)); return
            fi
        fi
    done

    if [[ -n $EXPECT_ARGV_LINES ]]; then
        local actual_lines
        actual_lines=$(wc -l < "$argv_log")
        if (( actual_lines != EXPECT_ARGV_LINES )); then
            echo "FAIL $name: argv lines expected=$EXPECT_ARGV_LINES got=$actual_lines"
            sed 's/^/    /' "$argv_log"
            failures+=("$name"); ((fail++)); return
        fi
    fi

    if [[ -n $EXPECT_ARGV_PANES ]]; then
        # Each line of argv_log is "yours base theirs" or "yours theirs";
        # word count = pane count.
        while IFS= read -r line; do
            local panes
            panes=$(echo "$line" | wc -w)
            if (( panes != EXPECT_ARGV_PANES )); then
                echo "FAIL $name: argv panes expected=$EXPECT_ARGV_PANES got=$panes line='$line'"
                failures+=("$name"); ((fail++)); return
            fi
        done < "$argv_log"
    fi

    if [[ -n $EXPECT_STDERR_PATTERN ]]; then
        if ! grep -Eq -- "$EXPECT_STDERR_PATTERN" "$stderr_file"; then
            echo "FAIL $name: stderr pattern '$EXPECT_STDERR_PATTERN' not found"
            sed 's/^/    /' "$stderr_file" | head -20
            failures+=("$name"); ((fail++)); return
        fi
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
