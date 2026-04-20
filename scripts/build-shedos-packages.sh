#!/usr/bin/env bash
# build-shedos-packages.sh — build packaging/shedos-* into archiso/shedos-repo.
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

# Explicit build order (topological — later packages may depend on earlier).
# Alphabetical would put shedos-hyprland before shedos-system, which it
# depends on.
BUILD_ORDER=(
    shedos-keyring
    shedos-system
    shedos-branding
    shedos-hyprland
    shedos-nvim
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
# BUILD_ORDER — build them last, after the canonical set.
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
# ShedOS-native packages (e.g. shedos-branding → catppuccin-sddm-theme-mocha)
# depend on packages that only exist in our build-local repo. Register that
# repo in /etc/pacman.conf for the duration of the build and restore the
# original on exit. Idempotent: on re-entry we strip any prior block first.
_strip_shedos_block() {
    # Remove any previously-appended block delimited by our marker.
    if grep -qF "$PACMAN_CONF_MARKER" /etc/pacman.conf 2>/dev/null; then
        sed -i "/$(printf '%s' "$PACMAN_CONF_MARKER" | sed 's/[][\/.^$*]/\\&/g')/,/# <<< shedos-build-local-repo (temporary) <<</d" /etc/pacman.conf
    fi
}

if [[ $EUID -eq 0 ]]; then
    _strip_shedos_block
    cp /etc/pacman.conf "$PACMAN_CONF_BACKUP"

    # Bind-mount the repo at /srv/shedos-build-repo so the alpm sandbox user
    # can reach it without needing to traverse the invoking user's $HOME.
    mkdir -p "$PUBLIC_REPO_DIR"
    # Clear any stale bind-mount from a prior aborted run.
    mountpoint -q "$PUBLIC_REPO_DIR" && umount "$PUBLIC_REPO_DIR"
    mount --bind "$REPO_DIR" "$PUBLIC_REPO_DIR"

    cat >> /etc/pacman.conf <<EOF

$PACMAN_CONF_MARKER
[shedos-repo]
SigLevel = Optional TrustAll
Server = file://$PUBLIC_REPO_DIR
# <<< shedos-build-local-repo (temporary) <<<
EOF

    _cleanup() {
        if [[ -f "$PACMAN_CONF_BACKUP" ]]; then
            mv "$PACMAN_CONF_BACKUP" /etc/pacman.conf
        fi
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
    local pkg_count
    pkg_count=$(find "$REPO_DIR" -maxdepth 1 -name '*.pkg.tar.zst' | wc -l)
    if (( pkg_count == 0 )); then
        echo "WARNING: no .pkg.tar.zst files in $REPO_DIR — skipping repo-add"
        return 0
    fi

    # repo-add UPDATES existing entries by default — no need to delete the
    # DB first. Running without --quiet so failures produce a visible stack.
    (
        cd "$REPO_DIR"
        repo-add shedos-repo.db.tar.gz ./*.pkg.tar.zst
    )

    # Guard against repo-add silently exiting 0 without producing a DB.
    if [[ ! -e "$REPO_DIR/shedos-repo.db" ]]; then
        echo "ERROR: $REPO_DIR/shedos-repo.db missing after repo-add"
        ls -la "$REPO_DIR" | head -20
        return 1
    fi

    if [[ $EUID -eq 0 ]]; then
        # -y without -u: do NOT upgrade the host system — just resync the
        # local repo DB into pacman's cache so makepkg sees fresh packages.
        pacman -Sy --noconfirm
    fi
}
_refresh_repo_db

BUILT=0
for dir in "${PKG_DIRS[@]}"; do
    pkgname=$(basename "$dir")
    work="$BUILD_ROOT/$pkgname"
    echo ""
    echo "---- makepkg $pkgname ----"

    # Fresh copy each run — makepkg's --cleanbuild only clears src/pkg, not
    # stray artifacts we might have left behind.
    rm -rf "$work"
    cp -a "$dir" "$work"

    # shedos-meta is a pure-metadata package (no build, no payload). Installing
    # its 450+ deps on the build host is noisy, slow, and can hit conflicts
    # with pre-existing host packages (e.g. tealdeer vs. tldr) that pacman
    # can't auto-resolve under --noconfirm. Since there's nothing to build
    # against, --nodeps is the canonical makepkg answer for metapackages.
    if [[ "$pkgname" == "shedos-meta" ]]; then
        mk_flags=(--nodeps --noconfirm --force --cleanbuild)
    else
        mk_flags=(--syncdeps --noconfirm --force --cleanbuild)
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

    BUILT=$((BUILT + 1))
done

echo ""
echo "Final shedos-repo database state:"
ls -lh "$REPO_DIR"/shedos-repo.*

echo ""
echo "=========================================="
echo "Built $BUILT ShedOS package(s) into $REPO_DIR"
echo "=========================================="
