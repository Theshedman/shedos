# ShedOS Build System
# A developer-focused Arch Linux distribution
#
# Usage: sudo make iso

VERSION := $(shell cat VERSION)
ISO_NAME := shedos-$(VERSION)-x86_64.iso
PROFILE_DIR := archiso
BUILD_DIR := build
OUTPUT_DIR := out
WORK_DIR := $(BUILD_DIR)/work
TEST_DIR := test
REPO_DIR := $(PROFILE_DIR)/shedos-repo

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: all iso clean test help check-deps check-root prepare build-aur download-packages

all: iso

help:
	@echo "ShedOS Build System v$(VERSION)"
	@echo ""
	@echo "Usage: sudo make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  download-packages  Download packages & freeze package state (DETERMINISTIC)"
	@echo "  iso                Build the ShedOS ISO image (fully offline, uses frozen packages)"
	@echo "  clean              Remove build artifacts (preserves packages & frozen databases)"
	@echo "  clean-all          Remove all generated files including ISO, packages, and databases"
	@echo "  test               Test the ISO in QEMU (UEFI mode)"
	@echo "  test-bios          Test the ISO in QEMU (BIOS mode)"
	@echo "  test-installed     Boot the installed system in QEMU"
	@echo "  check-deps         Check build dependencies"
	@echo "  prepare            Prepare build environment"
	@echo "  lint               Run linters on installer code"
	@echo "  help               Show this help message"
	@echo ""
	@echo "Deterministic Build Process:"
	@echo "  1. Run 'sudo make download-packages' to download and freeze package state"
	@echo "  2. Run 'sudo make iso' to build ISO using EXACT frozen packages (no network)"
	@echo "  3. ISO build is guaranteed to use same package versions as download time"

check-root:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "$(RED)Error: This target must be run as root (use sudo)$(NC)"; \
		exit 1; \
	fi

check-deps:
	@echo "$(GREEN)Checking dependencies...$(NC)"
	@command -v mkarchiso >/dev/null 2>&1 || { echo "$(RED)Error: archiso is not installed. Run: pacman -S archiso$(NC)"; exit 1; }
	@command -v qemu-system-x86_64 >/dev/null 2>&1 || echo "$(YELLOW)Warning: qemu not installed (needed for testing)$(NC)"
	@command -v repo-add >/dev/null 2>&1 || { echo "$(RED)Error: repo-add is not installed. Run: pacman -S pacman$(NC)"; exit 1; }
	@echo "$(GREEN)All required dependencies found$(NC)"

build-aur:
	@echo "$(GREEN)Building AUR packages...$(NC)"
	@./scripts/build-aur-packages.sh
	@echo "$(GREEN)AUR packages built$(NC)"

download-packages: check-root
	@echo "$(GREEN)Pre-downloading all packages...$(NC)"
	@echo "$(YELLOW)This avoids network issues during ISO build$(NC)"
	@./scripts/download-packages.sh
	@echo "$(GREEN)Packages downloaded and cached$(NC)"

prepare: check-root check-deps
	@echo "$(GREEN)Preparing build environment...$(NC)"
	@# Verify package cache BEFORE starting build
	@echo "$(GREEN)Verifying package cache completeness...$(NC)"
	@./scripts/verify-cache.sh || { \
		echo "$(RED)Cache verification failed!$(NC)"; \
		echo "$(RED)Run 'sudo make download-packages' first$(NC)"; \
		exit 1; \
	}
	@# Check if packages have been downloaded
	@if [ ! -d "$(REPO_DIR)" ]; then \
		echo "$(RED)ERROR: AUR repo directory not found: $(REPO_DIR)$(NC)"; \
		echo "$(RED)Run 'sudo make download-packages' first$(NC)"; \
		exit 1; \
	fi
	@if ! ls $(REPO_DIR)/*.pkg.tar.zst >/dev/null 2>&1; then \
		echo "$(RED)ERROR: No AUR packages found in $(REPO_DIR)$(NC)"; \
		echo "$(RED)Run 'sudo make download-packages' first$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$$(ls -A /var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null)" ]; then \
		echo "$(YELLOW)WARNING: No cached packages found. Run 'sudo make download-packages' first for faster build$(NC)"; \
	fi
	@# Check if database cache exists (for deterministic builds)
	@if [ ! -d "db-cache" ] || [ -z "$$(ls -A db-cache/*.db 2>/dev/null)" ]; then \
		echo "$(RED)ERROR: Frozen package databases not found$(NC)"; \
		echo "$(RED)Run 'sudo make download-packages' to freeze package state$(NC)"; \
		exit 1; \
	fi
	@rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR) $(OUTPUT_DIR)
	@cp -r $(PROFILE_DIR)/* $(BUILD_DIR)/
	@echo "$(GREEN)Restoring frozen package databases for deterministic build...$(NC)"
	@mkdir -p $(BUILD_DIR)/db-cache
	@cp db-cache/*.db $(BUILD_DIR)/db-cache/
	@echo "$(GREEN)Frozen databases restored: $$(ls -1 $(BUILD_DIR)/db-cache/ | wc -l) databases$(NC)"
	@echo "$(GREEN)Copying cached packages to build directory...$(NC)"
	@mkdir -p $(BUILD_DIR)/pkg-cache
	@# Exclude AUR packages - they come from shedos-repo only
	@rsync -a --info=progress2 \
		--exclude='walker-*.pkg.tar.zst' \
		--exclude='calamares-*.pkg.tar.zst' \
		--exclude='yay-*.pkg.tar.zst' \
		--exclude='visual-studio-code-bin-*.pkg.tar.zst' \
		--exclude='google-chrome-*.pkg.tar.zst' \
		--exclude='slack-desktop-*.pkg.tar.zst' \
		--exclude='obsidian-bin-*.pkg.tar.zst' \
		--exclude='hadolint-bin-*.pkg.tar.zst' \
		/var/cache/pacman/pkg/*.pkg.tar.zst $(BUILD_DIR)/pkg-cache/ 2>/dev/null || true
	@echo "$(GREEN)Cached packages copied (AUR packages excluded)$(NC)"
	@echo "$(GREEN)Configuring pacman for offline build...$(NC)"
	@# Copy smart download wrapper
	@mkdir -p $(BUILD_DIR)/scripts
	@cp scripts/pacman-offline-download.sh $(BUILD_DIR)/scripts/
	@chmod +x $(BUILD_DIR)/scripts/pacman-offline-download.sh
	@# Configure pacman: allow DB sync, use cached packages only
	@sed -i '/^\[options\]/a CacheDir = $(shell pwd)/$(BUILD_DIR)/pkg-cache\nCacheDir = /var/cache/pacman/pkg/' $(BUILD_DIR)/pacman.conf
	@# Use smart wrapper: allows DB downloads, blocks package downloads (uses cache)
	@sed -i 's|^XferCommand.*|XferCommand = $(shell pwd)/$(BUILD_DIR)/scripts/pacman-offline-download.sh %o %u|' $(BUILD_DIR)/pacman.conf
	@mkdir -p $(BUILD_DIR)/airootfs/opt/shedos-installer
	@cp -r installer/shedos_installer $(BUILD_DIR)/airootfs/opt/shedos-installer/
	@cp -r configs $(BUILD_DIR)/airootfs/opt/shedos-installer/
	@cp -r packages $(BUILD_DIR)/airootfs/opt/shedos-installer/
	@mkdir -p $(BUILD_DIR)/airootfs/opt/shedos-installer/branding
	@cp -r branding/wallpapers $(BUILD_DIR)/airootfs/opt/shedos-installer/branding/
	@chmod +x configs/system/shedos-first-login.sh
	@# Copy ShedOS branding files
	@mkdir -p $(BUILD_DIR)/airootfs/etc
	@cp branding/os-release $(BUILD_DIR)/airootfs/etc/os-release
	@cp branding/issue $(BUILD_DIR)/airootfs/etc/issue
	@cp branding/motd $(BUILD_DIR)/airootfs/etc/motd
	@mkdir -p $(BUILD_DIR)/airootfs/etc/neofetch
	@cp branding/neofetch/config.conf $(BUILD_DIR)/airootfs/etc/neofetch/
	@# Copy Plymouth theme
	@mkdir -p $(BUILD_DIR)/airootfs/usr/share/plymouth/themes/shedos
	@cp -r branding/plymouth/shedos/* $(BUILD_DIR)/airootfs/usr/share/plymouth/themes/shedos/ 2>/dev/null || true
	@# Calamares installer configuration
	@mkdir -p $(BUILD_DIR)/airootfs/etc/calamares
	@cp installer/calamares/settings.conf $(BUILD_DIR)/airootfs/etc/calamares/ 2>/dev/null || true
	@mkdir -p $(BUILD_DIR)/airootfs/etc/calamares/modules
	@cp -r installer/calamares/modules/*.conf $(BUILD_DIR)/airootfs/etc/calamares/modules/ 2>/dev/null || true
	@cp -r installer/calamares/modules/*.yaml $(BUILD_DIR)/airootfs/etc/calamares/modules/ 2>/dev/null || true
	@mkdir -p $(BUILD_DIR)/airootfs/etc/calamares/branding/shedos
	@cp -r installer/calamares/branding/shedos/* $(BUILD_DIR)/airootfs/etc/calamares/branding/shedos/ 2>/dev/null || true
	@# Update version in Calamares branding from VERSION file
	@sed -i 's/version: "[^"]*"/version: "$(VERSION)"/' $(BUILD_DIR)/airootfs/etc/calamares/branding/shedos/branding.desc
	@sed -i 's/shortVersion: "[^"]*"/shortVersion: "$(VERSION)"/' $(BUILD_DIR)/airootfs/etc/calamares/branding/shedos/branding.desc
	@sed -i 's/versionedName: "[^"]*"/versionedName: "ShedOS $(VERSION)"/' $(BUILD_DIR)/airootfs/etc/calamares/branding/shedos/branding.desc
	@sed -i 's/shortVersionedName: "[^"]*"/shortVersionedName: "ShedOS $(VERSION)"/' $(BUILD_DIR)/airootfs/etc/calamares/branding/shedos/branding.desc
	@mkdir -p $(BUILD_DIR)/airootfs/usr/lib/calamares/modules
	@cp -r installer/calamares/modules-src/* $(BUILD_DIR)/airootfs/usr/lib/calamares/modules/ 2>/dev/null || true
	@chmod +x $(BUILD_DIR)/airootfs/usr/local/bin/*
	@echo "$(GREEN)Build environment ready$(NC)"

iso: prepare
	@echo "$(GREEN)Building ShedOS $(VERSION)...$(NC)"
	@echo "$(YELLOW)This may take 15-30 minutes...$(NC)"
	mkarchiso -v -w $(WORK_DIR) -o $(OUTPUT_DIR) $(BUILD_DIR)
	@echo "$(GREEN)ISO built successfully: $(OUTPUT_DIR)/$(ISO_NAME)$(NC)"
	@cd $(OUTPUT_DIR) && sha256sum *.iso > sha256sums.txt 2>/dev/null || true
	@echo "$(GREEN)Build complete!$(NC)"
	@ls -lh $(OUTPUT_DIR)/*.iso 2>/dev/null || echo "$(RED)No ISO found$(NC)"

clean: check-root
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR) $(WORK_DIR)
	@rm -rf /tmp/shedos-aur-build
	@echo "$(GREEN)Clean complete (packages preserved)$(NC)"

clean-all: check-root
	@echo "$(YELLOW)Removing all generated files...$(NC)"
	@rm -rf $(BUILD_DIR) $(WORK_DIR) $(OUTPUT_DIR)
	@rm -rf packages/aur
	@rm -rf archiso/shedos-repo
	@rm -rf db-cache
	@echo "$(GREEN)Full clean complete (packages and frozen databases removed)$(NC)"

test:
	@if [ ! -f "$(OUTPUT_DIR)/$(ISO_NAME)" ]; then \
		echo "$(RED)Error: ISO not found. Run 'sudo make iso' first$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Testing ISO in QEMU (UEFI mode)...$(NC)"
	./scripts/test-iso.sh "$(OUTPUT_DIR)/$(ISO_NAME)" uefi

test-bios:
	@if [ ! -f "$(OUTPUT_DIR)/$(ISO_NAME)" ]; then \
		echo "$(RED)Error: ISO not found. Run 'sudo make iso' first$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Testing ISO in QEMU (BIOS mode)...$(NC)"
	./scripts/test-iso.sh "$(OUTPUT_DIR)/$(ISO_NAME)" bios

test-installed:
	@if [ ! -f "$(TEST_DIR)/test-disk.qcow2" ]; then \
		echo "$(RED)Error: No installed system found. Run 'make test' and install first$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Booting installed ShedOS...$(NC)"
	./scripts/test-iso.sh --disk-only

lint:
	@echo "$(GREEN)Running linters...$(NC)"
	@cd installer && python -m ruff check shedos_installer/ || true
	@cd installer && python -m mypy shedos_installer/ || true
	@echo "$(GREEN)Lint complete$(NC)"

dev-install:
	@echo "$(GREEN)Installing development dependencies...$(NC)"
	@cd installer && pip install -e ".[dev]"

.PHONY: dev-install lint test test-bios
