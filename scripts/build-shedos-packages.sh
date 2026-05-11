#!/usr/bin/env bash
# build-shedos-packages.sh; build packaging/shedos-* into archiso/shedos-repo.
#
# Parallels scripts/build-aur-packages.sh: output goes to the same local repo
# so a single `mkarchiso` pacstrap pulls both AUR-sourced packages (e.g.
# calamares) and ShedOS-native packages (shedos-system, shedos-meta, …).
#
# Unlike the AUR script we don't sign here; the ISO build consumes these
# through pacman.conf.in's [shedos-repo] section which is SigLevel = TrustAll.
# CI signs separately when publishing to repo.shedos.org (see
# .github/workflows/build-packages.yml).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PACKAGING_DIR="$PROJECT_ROOT/packaging"
REPO_DIR="$PROJECT_ROOT/archiso/shedos-repo"

echo "=========================================="
echo "Building ShedOS packages"
echo "=========================================="

mkdir -p "$REPO_DIR"

# Regenerate shedos-meta depends= from packages/ so the metapackage reflects
# current state.
"$SCRIPT_DIR/render-meta-depends.sh"

# Topological order; shedos-meta last (it depends on every other
# shedos-* package and version-pins them). Alphabetical sort would
# break shedos-hyprland → shedos-system.
BUILD_ORDER=(
    shedos-keyring
    shedos-system
    shedos-branding
    shedos-hyprland
    shedos-nvim
    shedos-greeter
    shedos-screensaver
    shedos-migrate-to-packaged
    shedos-kernel
    shedos-meta
)

PKG_DIRS=()
for name in "${BUILD_ORDER[@]}"; do
    d="$PACKAGING_DIR/$name"
    if [[ -f "$d/PKGBUILD" ]]; then
        PKG_DIRS+=("$d")
    else
        echo "WARNING: $name listed in BUILD_ORDER but $d/PKGBUILD not found — skipping"
    fi
done

# Catch any new packages that got added to packaging/ without being put in
# BUILD_ORDER; build them last, after the canonical set.
while IFS= read -r d; do
    name=$(basename "$d")
    # shellcheck disable=SC2076
    if ! [[ " ${BUILD_ORDER[*]} " =~ " $name " ]]; then
        echo "NOTE: $name is not in BUILD_ORDER; appending at end"
        PKG_DIRS+=("$d")
    fi
done < <(find "$PACKAGING_DIR" -mindepth 2 -maxdepth 2 -name PKGBUILD -printf '%h\n' | sort)

if [[ ${#PKG_DIRS[@]} -eq 0 ]]; then
    echo "No PKGBUILDs found under $PACKAGING_DIR"
    exit 1
fi

# Build under /tmp so the unprivileged `builduser` can actually cd into the
# build tree even when the invoking user's $HOME is 0700. makepkg refuses to
# run as root, and granting builduser traversal rights on the real user's
# home would be invasive. Copying the package dir (PKGBUILD + tree/) into a
# world-readable scratch area is the standard workaround.
BUILD_ROOT="/tmp/shedos-pkgbuild"
PACMAN_CONF_BACKUP="/tmp/shedos-pacman.conf.bak"
PACMAN_CONF_MARKER="# >>> shedos-build-local-repo (temporary) >>>"

# Pacman's DownloadUser sandbox (default `alpm` user in modern Arch) reads
# file:// URLs as alpm, which cannot traverse a 0700 home directory. Bind-
# mounting the repo into /srv sidesteps this without weakening sandboxing
# or loosening $HOME perms. /srv is typically 755 on Arch and untouched.
PUBLIC_REPO_DIR="/srv/shedos-build-repo"

# makepkg --syncdeps invokes `pacman -S` against /etc/pacman.conf. Several
# ShedOS-native packages (e.g. shedos-meta → catppuccin-gtk-theme-mocha)
# depend on packages that only exist in our build-local repo. Register that
# repo in /etc/pacman.conf for the duration of the build and restore the
# original on exit. Idempotent: on re-entry we strip any prior block first.
_strip_shedos_block() {
    # Remove any previously-appended block delimited by our marker.
    if grep -qF "$PACMAN_CONF_MARKER" /etc/pacman.conf 2>/dev/null; then
        sed -i "/$(printf '%s' "$PACMAN_CONF_MARKER" | sed 's/[][\/.^$*]/\\&/g')/,/# <<< shedos-build-local-repo (temporary) <<</d" /etc/pacman.conf
    fi
}

# Reverse shedos-system's _add_shedos_repo scriptlet inside the build
# chroot; without this, the next `pacman -Sy` 404s on the prod repo.
_strip_shedos_prod_blocks() {
    [[ $EUID -eq 0 ]] || return 0
    [[ -f /etc/pacman.conf ]] || return 0
    sed -i \
        -e '/^# >>> shedos <<<$/,/^# <<< shedos >>>$/d' \
        -e '/^# >>> shedos-testing <<<$/,/^# <<< shedos-testing >>>$/d' \
        /etc/pacman.conf
}

if [[ $EUID -eq 0 ]]; then
    _strip_shedos_block
    cp /etc/pacman.conf "$PACMAN_CONF_BACKUP"

    # Marker read by shedos-system.install :: _add_shedos_repo to skip
    # adding the production [shedos] block to /etc/pacman.conf when the
    # scriptlet runs as a transitive --syncdeps install during this build.
    touch /.shedos-build-environment

    # Bind-mount the repo at /srv/shedos-build-repo so the alpm sandbox user
    # can reach it without needing to traverse the invoking user's $HOME.
    mkdir -p "$PUBLIC_REPO_DIR"
    # Clear any stale bind-mount from a prior aborted run.
    mountpoint -q "$PUBLIC_REPO_DIR" && umount "$PUBLIC_REPO_DIR"
    mount --bind "$REPO_DIR" "$PUBLIC_REPO_DIR"

    cat >> /etc/pacman.conf <<EOF

$PACMAN_CONF_MARKER
[shedos-repo]
SigLevel = Never
Server = file://$PUBLIC_REPO_DIR
# <<< shedos-build-local-repo (temporary) <<<
EOF

    _cleanup() {
        if [[ -f "$PACMAN_CONF_BACKUP" ]]; then
            mv "$PACMAN_CONF_BACKUP" /etc/pacman.conf
        fi
        rm -f /.shedos-build-environment
        mountpoint -q "$PUBLIC_REPO_DIR" 2>/dev/null && umount "$PUBLIC_REPO_DIR"
        rmdir "$PUBLIC_REPO_DIR" 2>/dev/null || true
        userdel -r builduser 2>/dev/null || true
        rm -f /etc/sudoers.d/builduser-shedos
        rm -rf "$BUILD_ROOT"
    }
    trap _cleanup EXIT
    useradd -m -G wheel builduser 2>/dev/null || true
    echo "builduser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builduser-shedos
    chmod 440 /etc/sudoers.d/builduser-shedos
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"
chmod 755 "$BUILD_ROOT"

# Seed the repo DB with existing .pkg.tar.zst files (AUR-built deps from
# build-aur-packages.sh plus anything left over from a prior run). We'll
# rebuild it incrementally after each makepkg so later packages can resolve
# earlier ones via pacman.
_refresh_repo_db() {
    _strip_shedos_prod_blocks
    local pkg_count
    pkg_count=$(find "$REPO_DIR" -maxdepth 1 -name '*.pkg.tar.zst' | wc -l)
    if (( pkg_count == 0 )); then
        echo "WARNING: no .pkg.tar.zst files in $REPO_DIR — skipping repo-add"
        return 0
    fi

    # `-p` (prevent-downgrade) makes the highest version always win, even
    # when the glob expands in lex order (where pkgrel "10" sorts before "7").
    (
        cd "$REPO_DIR"
        repo-add -p shedos-repo.db.tar.gz ./*.pkg.tar.zst
    )

    # Guard against repo-add silently exiting 0 without producing a DB.
    if [[ ! -e "$REPO_DIR/shedos-repo.db" ]]; then
        echo "ERROR: $REPO_DIR/shedos-repo.db missing after repo-add"
        ls -la "$REPO_DIR" | head -20
        return 1
    fi

    if [[ $EUID -eq 0 ]]; then
        # -y without -u: do NOT upgrade the host system; just resync the
        # local repo DB into pacman's cache so makepkg sees fresh packages.
        pacman -Sy --noconfirm
    fi
}
_refresh_repo_db

# Drop cached packages whose packaging/<pkgname>/ directory is gone.
# The per-package stale-version sweep below only walks directories
# that exist; a fully-removed package would otherwise survive in
# REPO_DIR, get re-signed, and end up as a 404 in published shedos.db.
declare -A keep_shedos=()
for d in "$PACKAGING_DIR"/*/; do
    [[ -f "$d/PKGBUILD" ]] || continue
    keep_shedos[$(basename "$d")]=1
done
[[ -n ${keep_shedos[shedos-kernel]:-} ]] && keep_shedos[shedos-kernel-headers]=1
phantom_count=0
shopt -s nullglob
for f in "$REPO_DIR"/shedos-*.pkg.tar.zst; do
    base=$(basename "$f")
    pkgname=${base%-*-*-*.pkg.tar.zst}
    [[ "$pkgname" == *-debug ]] && continue
    if [[ -z ${keep_shedos[$pkgname]:-} ]]; then
        echo "  prune phantom shedos: $base"
        rm -f "$f" "${f}.sig"
        phantom_count=$((phantom_count + 1))
    fi
done
shopt -u nullglob
if (( phantom_count > 0 )); then
    echo "Phantom sweep: removed $phantom_count stale shedos-* package file(s)"
fi

# Strip stale .pkg.tar.zst left over from prior cache states (the
# shedos-pkgs cache accumulates files across builds; without this
# pass, REPO_DIR can hold every shedos-system pkgrel ever cached).
# Keep only the version named by each package's current PKGBUILD.
for dir in "$PACKAGING_DIR"/shedos-*/; do
    pkgname=$(basename "$dir")
    [[ -f "$dir/PKGBUILD" ]] || continue
    [[ "$pkgname" == "shedos-kernel" ]] && continue   # dedicated kernel cache
    pkgver=$(awk -F= '/^pkgver=/ {print $2; exit}' "$dir/PKGBUILD")
    pkgrel=$(awk -F= '/^pkgrel=/ {print $2; exit}' "$dir/PKGBUILD")
    shopt -s nullglob
    for stale in "$REPO_DIR/${pkgname}"-*.pkg.tar.zst; do
        base=$(basename "$stale")
        [[ "$base" == "${pkgname}-${pkgver}-${pkgrel}-"*.pkg.tar.zst ]] && continue
        echo "  removing stale: $base"
        rm -f "$stale" "${stale}.sig"
    done
    shopt -u nullglob
done
_refresh_repo_db

# Pre-stage every package dir under BUILD_ROOT before any builds start.
# shedos-screensaver's Rust source uses a sibling-relative include
# (`include_str!("../../../../shedos-branding/tree/etc/shedos-ascii.txt")`)
# that resolves to $BUILD_ROOT/shedos-branding/. If shedos-branding's
# build is cache-hit and skipped, its $work dir would never get created
# and shedos-screensaver's compile would fail with "no such file".
# Pre-staging guarantees every package's tree is on disk under
# BUILD_ROOT regardless of cache state.
for dir in "${PKG_DIRS[@]}"; do
    pkgname=$(basename "$dir")
    work="$BUILD_ROOT/$pkgname"
    rm -rf "$work"
    cp -a "$dir" "$work"
done

# Pre-stage workspace library crates that ship as Cargo `path = "../<name>"`
# deps but have no PKGBUILD of their own (e.g. shedos-prompt-ui; the
# shared lock-surface renderer used by shedos-greeter and, soon,
# shedos-screensaver). Same precedent as shedos-screensaver's
# include_str! reach into shedos-branding: the consuming package's
# `cargo build` resolves `../shedos-prompt-ui` against BUILD_ROOT, so
# the sibling has to physically exist there.
for crate in shedos-prompt-ui; do
    src="$PACKAGING_DIR/$crate"
    [[ -d "$src" ]] || continue
    [[ -f "$src/Cargo.toml" ]] || continue
    dst="$BUILD_ROOT/$crate"
    rm -rf "$dst"
    cp -a "$src" "$dst"
done

[[ $EUID -eq 0 ]] && chown -R builduser:builduser "$BUILD_ROOT"

BUILT_PKGS=()
for dir in "${PKG_DIRS[@]}"; do
    pkgname=$(basename "$dir")
    work="$BUILD_ROOT/$pkgname"
    echo ""
    echo "---- makepkg $pkgname ----"

    # Cache pre-flight: skip if pkgver-pkgrel.pkg.tar.zst already in REPO_DIR.
    pkgver=$(awk -F= '/^pkgver=/ {print $2; exit}' "$dir/PKGBUILD")
    pkgrel=$(awk -F= '/^pkgrel=/ {print $2; exit}' "$dir/PKGBUILD")
    cached=()
    for a in x86_64 any; do
        f="$REPO_DIR/${pkgname}-${pkgver}-${pkgrel}-${a}.pkg.tar.zst"
        [[ -f $f ]] && cached+=("$f")
    done
    if [[ $pkgname == shedos-kernel ]]; then
        h="$REPO_DIR/${pkgname}-headers-${pkgver}-${pkgrel}-x86_64.pkg.tar.zst"
        [[ -f $h ]] && cached+=("$h") || cached=()
    fi
    if (( ${#cached[@]} > 0 )); then
        echo "✓ $pkgname $pkgver-$pkgrel cached; skipping rebuild"
        printf '    %s\n' "${cached[@]##*/}"
        _refresh_repo_db
        continue
    fi

    # Every shedos-* package except shedos-kernel is a pure-copy package: no
    # compile step, no makedepends, just `cp -a tree/… $pkgdir`. Runtime
    # depends=() are needed on the INSTALLED system, not on the build host.
    # Using --syncdeps for those installs runtime deps into the build
    # container for no benefit; and is actively harmful when the installed
    # dep mutates build-host state via its .install scriptlet
    # (shedos-system's post_install appends [shedos] to /etc/pacman.conf;
    # the next `pacman -Sy` then 404s because the prod repo doesn't exist
    # yet inside CI). --nodeps sidesteps the whole problem.
    #
    # shedos-kernel + shedos-screensaver + shedos-greeter actually compile
    # code and need their makedepends + depends pulled in. Everything else
    # is pure cp -a payload; --nodeps avoids running runtime install
    # scriptlets (e.g. shedos-system's pacman.conf rewrite) inside the
    # build chroot.
    #
    # shedos-greeter and shedos-power are single-crate Rust packages:
    # their actual Rust sources live at packaging/<pkg>/src/ which
    # collides with makepkg's $srcdir convention. --cleanbuild would
    # rm -rf $srcdir before build() runs and delete our sources. The
    # outer `rm -rf $work && cp -a $dir $work` above already gives a
    # fresh per-run copy, so dropping --cleanbuild for these is safe.
    case "$pkgname" in
        shedos-greeter|shedos-power)
            mk_flags=(--syncdeps --noconfirm --force)
            ;;
        shedos-kernel|shedos-screensaver)
            mk_flags=(--syncdeps --noconfirm --force --cleanbuild)
            ;;
        *)
            mk_flags=(--nodeps --noconfirm --force --cleanbuild)
            ;;
    esac

    # validpgpkeys=() only whitelists trust; it doesn't fetch keys, so
    # on a fresh CI runner the kernel source-sig check fails. Pull fp
    # list from the PKGBUILD itself to track bump-kernel.sh updates.
    if [[ $pkgname == shedos-kernel ]]; then
        mapfile -t kfps < <(awk '
            /^validpgpkeys=\(/ { seen=1; next }
            seen && /^\)/      { exit }
            seen               { sub(/#.*/, ""); for (i=1;i<=NF;i++) if ($i ~ /^[A-F0-9]{40}$/) print $i }
        ' "$dir/PKGBUILD")
        if (( ${#kfps[@]} == 0 )); then
            echo "FATAL: shedos-kernel PKGBUILD has no parseable validpgpkeys" >&2
            exit 1
        fi
        echo "→ Importing ${#kfps[@]} kernel-source signing key(s) into builduser keyring..."
        _recv_kernel_keys() {
            local user_prefix=()
            [[ $EUID -eq 0 ]] && user_prefix=(sudo -u builduser)
            "${user_prefix[@]}" gpg --batch --keyserver hkps://keyserver.ubuntu.com \
                --recv-keys "${kfps[@]}" 2>&1 \
                || "${user_prefix[@]}" gpg --batch --keyserver hkps://keys.openpgp.org \
                    --recv-keys "${kfps[@]}" 2>&1 \
                || "${user_prefix[@]}" gpg --batch --keyserver hkps://pgp.mit.edu \
                    --recv-keys "${kfps[@]}" 2>&1
        }
        if ! _recv_kernel_keys; then
            echo "FATAL: could not retrieve kernel signing keys from any keyserver" >&2
            exit 1
        fi
    fi

    if [[ $EUID -eq 0 ]]; then
        chown -R builduser:builduser "$work"
        sudo -u builduser bash -c "
            cd '$work' &&
            makepkg ${mk_flags[*]}
        "
    else
        (cd "$work" && makepkg "${mk_flags[@]}")
    fi

    # Sweep freshly-built packages into the repo and refresh DB so the next
    # iteration's makepkg --syncdeps can find what we just built (e.g.
    # shedos-hyprland → shedos-system; shedos-meta → everything else).
    find "$work" -maxdepth 1 -name "*.pkg.tar.zst" -exec cp -v {} "$REPO_DIR/" \;
    _refresh_repo_db

    BUILT_PKGS+=("$pkgname")
done

# Strip -debug splits before mkarchiso (mirrors CI build-iso.yml).
echo ""
echo "Stripping -debug packages from $REPO_DIR/ ..."
shopt -s nullglob
debug_pkgs=( "$REPO_DIR"/*-debug-*.pkg.tar.zst )
if (( ${#debug_pkgs[@]} > 0 )); then
    rm -f "$REPO_DIR"/*-debug-*.pkg.tar.zst "$REPO_DIR"/*-debug-*.pkg.tar.zst.sig
    echo "  removed ${#debug_pkgs[@]} debug split(s)"
    _refresh_repo_db
else
    echo "  no -debug splits present; nothing to do"
fi
shopt -u nullglob

echo ""
echo "Final shedos-repo database state:"
ls -lh "$REPO_DIR"/shedos-repo.*

# Persist the freshly-built package list so downstream CI steps know
# which packages need re-signing + repo-add. Cached packages are
# excluded; the file is left untouched (or empty) on a no-op build.
# Append rather than overwrite; build-aur-packages.sh writes its own
# rebuild entries to the same file, and we don't want to clobber them.
if (( ${#BUILT_PKGS[@]} > 0 )); then
    printf '%s\n' "${BUILT_PKGS[@]}" >> /tmp/built-pkgs.txt
fi
touch /tmp/built-pkgs.txt

echo ""
echo "=========================================="
echo "Built ${#BUILT_PKGS[@]} ShedOS package(s) into $REPO_DIR"
echo "Manifest: /tmp/built-pkgs.txt (${#BUILT_PKGS[@]} entries)"
echo "=========================================="
