#!/usr/bin/env bash
# ShedOS ISO Build Script

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_DIR="$PROJECT_DIR/out"
WORK_DIR="$BUILD_DIR/work"
PROFILE_DIR="$PROJECT_DIR/archiso"

# Load version
VERSION=$(cat "$PROJECT_DIR/VERSION" 2>/dev/null || echo "0.1.0")
ISO_NAME="shedos-${VERSION}-x86_64.iso"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."

    local deps=("mkarchiso" "pacstrap" "genfstab")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install archiso: pacman -S archiso"
        exit 1
    fi

    # Check disk space (need at least 20GB)
    local free_space
    free_space=$(df -BG "$PROJECT_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ $free_space -lt 20 ]]; then
        log_warning "Low disk space: ${free_space}GB free (recommend 20GB+)"
    fi

    log_success "All dependencies found"
}

prepare_build() {
    log_info "Preparing build environment..."

    # Clean previous build
    rm -rf "$BUILD_DIR" "$WORK_DIR"
    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

    # Copy archiso profile
    cp -r "$PROFILE_DIR"/* "$BUILD_DIR/"

    # Render pacman.conf from template (path-independent build)
    if [[ ! -f "$PROFILE_DIR/pacman.conf.in" ]]; then
        log_error "Missing template: $PROFILE_DIR/pacman.conf.in"
        exit 1
    fi
    sed "s|@SHEDOS_REPO@|${PROFILE_DIR}/shedos-repo|g" \
        "$PROFILE_DIR/pacman.conf.in" > "$BUILD_DIR/pacman.conf"
    # Remove the template copy that cp -r brought in
    rm -f "$BUILD_DIR/pacman.conf.in"

    # Copy installer
    mkdir -p "$BUILD_DIR/airootfs/opt/shedos-installer"
    cp -r "$PROJECT_DIR/installer/shedos_installer" "$BUILD_DIR/airootfs/opt/shedos-installer/"
    cp -r "$PROJECT_DIR/configs" "$BUILD_DIR/airootfs/opt/shedos-installer/"
    cp -r "$PROJECT_DIR/packages" "$BUILD_DIR/airootfs/opt/shedos-installer/"

    # Copy branding
    cp "$PROJECT_DIR/branding/os-release" "$BUILD_DIR/airootfs/etc/os-release"
    mkdir -p "$BUILD_DIR/airootfs/etc/neofetch"
    cp "$PROJECT_DIR/branding/neofetch/config.conf" "$BUILD_DIR/airootfs/etc/neofetch/"
    cp "$PROJECT_DIR/branding/issue" "$BUILD_DIR/airootfs/etc/issue"
    cp "$PROJECT_DIR/branding/motd" "$BUILD_DIR/airootfs/etc/motd"

    # Set version in profiledef.sh
    sed -i "s/\$(cat \${script_path}\/\.\.\/VERSION 2>\/dev\/null || echo '0.1.0')/$VERSION/" \
        "$BUILD_DIR/profiledef.sh"

    # Ensure customize script is executable
    chmod +x "$BUILD_DIR/airootfs/root/customize_airootfs.sh"

    log_success "Build environment prepared"
}

build_iso() {
    log_info "Building ShedOS ${VERSION}..."
    log_info "This may take a while..."

    mkarchiso -v -w "$WORK_DIR" -o "$OUTPUT_DIR" "$BUILD_DIR"

    if [[ -f "$OUTPUT_DIR/$ISO_NAME" ]]; then
        log_success "ISO built successfully!"

        # Generate checksums
        log_info "Generating checksums..."
        cd "$OUTPUT_DIR"
        sha256sum "$ISO_NAME" > "${ISO_NAME}.sha256"
        md5sum "$ISO_NAME" > "${ISO_NAME}.md5"

        log_success "Build complete!"
        echo ""
        log_info "ISO: $OUTPUT_DIR/$ISO_NAME"
        log_info "Size: $(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1)"
        log_info "SHA256: $(cat "${ISO_NAME}.sha256" | cut -d' ' -f1)"
    else
        log_error "ISO build failed!"
        exit 1
    fi
}

clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR" "$WORK_DIR"
    log_success "Clean complete"
}

show_help() {
    echo "ShedOS ISO Build Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build    Build the ISO (default)"
    echo "  clean    Clean build artifacts"
    echo "  help     Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  BUILD_DIR   Build directory (default: ./build)"
    echo "  OUTPUT_DIR  Output directory (default: ./out)"
}

main() {
    local command="${1:-build}"

    case "$command" in
        build)
            check_root
            check_dependencies
            prepare_build
            build_iso
            ;;
        clean)
            check_root
            clean_build
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
