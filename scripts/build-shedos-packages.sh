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
    shedos-hyprland-plugin-hyprspace
    shedos-hyprland
    shedos-nvim
    shedos-greeter
    shedos-screensaver
    shedos-migrate-to-packaged
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

# Build under a world-traversable scratch area so the unprivileged `builduser`
# can cd into the tree even when the invoking user's $HOME is 0700 (makepkg
# refuses to run as root, and granting builduser rights on the real home would
# be invasive). /var/tmp, not /tmp: the Rust packages compile with LTO and
# debuginfo=2, which overflows a RAM-backed /tmp. /var/tmp is disk-backed and,
# like /tmp, 1777 so builduser can reach it. Override with SHEDOS_PKGBUILD_DIR.
BUILD_ROOT="${SHEDOS_PKGBUILD_DIR:-/var/tmp/shedos-pkgbuild}"
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
        -e '/^# >>> shedostest <<<$/,/^# <<< shedostest >>>$/d' \
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
    # An interrupted run can leave the group behind after userdel; useradd
    # then refuses the name, so clear it and let a real failure surface.
    if ! getent passwd builduser >/dev/null; then
        groupdel builduser 2>/dev/null || true
        useradd -m -G wheel builduser
    fi
    echo "builduser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builduser-shedos
    chmod 440 /etc/sudoers.d/builduser-shedos
    # shedos-screensaver/greeter/power are Rust; the fresh build user has no
    # default toolchain, so cargo errors "no default is configured" the moment
    # one of them actually rebuilds (it stays hidden while they cache-hit).
    # The version pin was dropped on purpose, so build against current stable.
    if command -v rustup &> /dev/null; then
        sudo -u builduser rustup default stable 2>/dev/null || true
    fi
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
    # The version key alone can't see working-tree edits (local builds
    # never bump pkgrel), so a content-hash sidecar guards the cache.
    tree_hash=$("$SCRIPT_DIR/compute-pkg-hash.sh" "$pkgname")
    hash_file="$REPO_DIR/.hash-$pkgname"
    if (( ${#cached[@]} > 0 )) && [[ $(cat "$hash_file" 2>/dev/null) != "$tree_hash" ]]; then
        echo "✗ $pkgname: package tree changed since the cached build; rebuilding"
        for c in "${cached[@]}"; do
            rm -f "$c" "$c.sig"
        done
        cached=()
    fi
    if (( ${#cached[@]} > 0 )); then
        echo "✓ $pkgname $pkgver-$pkgrel cached; skipping rebuild"
        printf '    %s\n' "${cached[@]##*/}"
        _refresh_repo_db
        continue
    fi

    # Most shedos-* packages are pure-copy: no compile step, no
    # makedepends, just `cp -a tree/… $pkgdir`. Runtime depends=() are
    # needed on the INSTALLED system, not on the build host. Using
    # --syncdeps for those installs runtime deps into the build container
    # for no benefit; and is actively harmful when the installed dep
    # mutates build-host state via its .install scriptlet (shedos-system's
    # post_install appends [shedos] to /etc/pacman.conf; the next
    # `pacman -Sy` then 404s because the prod repo doesn't exist yet inside
    # CI). --nodeps sidesteps the whole problem.
    #
    # shedos-screensaver + shedos-greeter + shedos-power actually compile
    # code and need their makedepends + depends pulled in. Everything else
    # is pure cp -a payload; --nodeps avoids running runtime install
    # scriptlets (e.g. shedos-system's pacman.conf rewrite) inside the
    # build chroot.
    #
    # Single-crate Rust packages (greeter, power, tour, switcher, …)
    # keep their sources at packaging/<pkg>/src/, which collides with
    # makepkg's $srcdir convention: --cleanbuild would rm -rf the
    # sources before build() runs. Detect them by Cargo.toml instead
    # of naming them — the old explicit list silently dropped every
    # new crate into the --nodeps branch (no cargo, then a cleanbuild
    # deleting src/). The outer rm -rf + cp -a already gives a fresh
    # per-run copy, so skipping --cleanbuild is safe. Workspace-style
    # builds that DO want cleanbuild stay on the explicit list.
    case "$pkgname" in
        shedos-screensaver|calamares|shedos-hyprland-plugin-hyprspace|cage)
            mk_flags=(--syncdeps --noconfirm --force --cleanbuild)
            ;;
        *)
            if [[ -f $dir/Cargo.toml ]]; then
                mk_flags=(--syncdeps --noconfirm --force)
            else
                mk_flags=(--nodeps --noconfirm --force --cleanbuild)
            fi
            ;;
    esac

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
    printf '%s\n' "$tree_hash" > "$hash_file"

    BUILT_PKGS+=("$pkgname")
done

# Prune superseded versions of locally-built packages. Dev repos keep
# one file per historic pkgver, and the AUR-dep extraction in
# download-packages.sh reads files rather than the db, so stale
# versions leak retired dependencies back into the download set.
for dir in "${PKG_DIRS[@]}"; do
    pkgname=$(basename "$dir")
    pkgver=$(awk -F= '/^pkgver=/ {print $2; exit}' "$dir/PKGBUILD")
    pkgrel=$(awk -F= '/^pkgrel=/ {print $2; exit}' "$dir/PKGBUILD")
    shopt -s nullglob
    for f in "$REPO_DIR/$pkgname"-*.pkg.tar.zst; do
        base=${f##*/}
        inferred=${base%-*-*-*.pkg.tar.zst}
        [[ $inferred == "$pkgname" ]] || continue
        [[ $base == "$pkgname-$pkgver-$pkgrel-"*.pkg.tar.zst ]] && continue
        rm -fv "$f" "$f.sig"
    done
    shopt -u nullglob
done
_refresh_repo_db

# Evict same-named files from the host pacman cache; a rebuilt package
# keeps its version, so a stale cache copy would fail pacstrap's
# checksum check against the refreshed repo db.
if [[ $EUID -eq 0 && -d /var/cache/pacman/pkg ]]; then
    shopt -s nullglob
    for f in "$REPO_DIR"/*.pkg.tar.zst; do
        rm -f "/var/cache/pacman/pkg/${f##*/}"
    done
    shopt -u nullglob
fi

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
