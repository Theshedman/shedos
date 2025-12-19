#!/usr/bin/env bash
# Pre-download all ShedOS packages for offline installation
# This script downloads all packages to a cache that's included in the ISO

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PACKAGE_DIR="$PROJECT_DIR/installer/shedos_installer/packages"
# Use /opt location - mkarchiso doesn't clean this unlike /var/cache/
CACHE_DIR="${1:-$PROJECT_DIR/build/airootfs/opt/shedos-pkg-cache}"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Collect all packages from package lists
collect_packages() {
    local packages=()

    # Package files used by the DEVELOPER profile (most common)
    local pkg_files=(
        "base.txt"
        "audio.txt"
        "fonts.txt"
        "desktop.txt"
        "system-programming.txt"
        "development.txt"
        "devops.txt"
        "databases.txt"
        "tui-tools.txt"
        "nvidia.txt"
    )

    for pkg_file in "${pkg_files[@]}"; do
        local file_path="$PACKAGE_DIR/$pkg_file"
        if [[ -f "$file_path" ]]; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                # Skip comments and empty lines
                line="${line%%#*}"
                line="${line// /}"
                if [[ -n "$line" ]]; then
                    packages+=("$line")
                fi
            done < "$file_path"
        fi
    done

    # Remove duplicates and sort
    printf '%s\n' "${packages[@]}" | sort -u
}

download_packages() {
    log_info "Creating package cache directory: $CACHE_DIR"
    mkdir -p "$CACHE_DIR"

    # Check available space (simple check)
    local free_space_mb
    free_space_mb=$(df -m "$CACHE_DIR" | awk 'NR==2 {print $4}')
    log_info "Free space in build directory: ${free_space_mb}MB"
    
    if [[ "$free_space_mb" -lt 4000 ]]; then
        log_warning "Less than 4GB free space detected. Download might fail."
    fi

    log_info "Collecting package list..."
    local packages
    packages=$(collect_packages)
    local pkg_count
    pkg_count=$(echo "$packages" | wc -l)

    log_info "Found $pkg_count unique packages to download"

    # Create a temp pacman config that ignores disk space checking
    # This fixes "not enough free disk space" errors in chroots/containers
    local temp_conf
    temp_conf=$(mktemp)
    grep -v "CheckSpace" /etc/pacman.conf > "$temp_conf" || cp /etc/pacman.conf "$temp_conf"
    
    log_info "Downloading packages and dependencies (skipping disk space check)..."

    # Use pacman to download packages to cache (download only, no install)
    # shellcheck disable=SC2086
    if pacman --config "$temp_conf" -Syw --noconfirm --cachedir "$CACHE_DIR" $packages; then
        log_success "Packages downloaded successfully"
    else
        log_error "Package download failed"
        rm -f "$temp_conf"
        exit 1
    fi
    rm -f "$temp_conf"

    # Also sync the database files
    log_info "Syncing package databases..."
    mkdir -p "$CACHE_DIR/sync"
    cp -r /var/lib/pacman/sync/* "$CACHE_DIR/sync/" 2>/dev/null || true

    local cache_size
    cache_size=$(du -sh "$CACHE_DIR" | cut -f1)
    local pkg_files_count
    pkg_files_count=$(find "$CACHE_DIR" -name "*.pkg.tar.*" 2>/dev/null | wc -l)

    log_success "Downloaded $pkg_files_count package files ($cache_size)"
}

main() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    log_info "ShedOS Package Pre-loader"
    log_info "========================="

    # Sync pacman databases first
    log_info "Syncing pacman databases..."
    pacman -Sy

    download_packages

    log_success "Package preloading complete!"
    log_info "Cache location: $CACHE_DIR"
}

main "$@"
