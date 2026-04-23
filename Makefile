# ShedOS Build System
# A developer-focused Arch Linux distribution
#
# Usage: sudo make iso

VERSION := $(shell cat VERSION)
# ISO filename stamping: CI sets SHEDOS_ISO_TAG to the pushed git tag minus its
# "v" prefix (e.g. 2026.04.21-rc2) so RCs and stables cut from the same CalVer
# produce distinct ISO filenames — otherwise v2026.04.21-rc1 and v2026.04.21
# would both emit shedos-2026.04.21-x86_64.iso and collide on R2. Local `make
# iso` without the env var falls back to VERSION (matches what packages ship).
ISO_VER  := $(if $(SHEDOS_ISO_TAG),$(SHEDOS_ISO_TAG),$(VERSION))
ISO_NAME := shedos-$(ISO_VER)-x86_64.iso
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

.PHONY: all iso clean test help check-deps check-root prepare build-aur download-packages generate-packages shedos-packages test-review-configs

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
	@echo "  test-review-configs Run shedos-review-configs fixture tests"
	@echo "  test-sync-configs  Run shedos-sync-configs fixture tests"
	@echo "  test-check-health  Run shedos-check-health fixture tests"
	@echo "  check-deps         Check build dependencies"
	@echo "  prepare            Prepare build environment"
	@echo "  generate-packages  Regenerate archiso/packages.x86_64 from packages/"
	@echo "  shedos-packages    Build ShedOS native packages (packaging/shedos-*) into shedos-repo"
	@echo "  lint               Run linters on installer code"
	@echo "  help               Show this help message"
	@echo ""
	@echo "Deterministic Build Process:"
	@echo "  1. Run 'sudo make download-packages' to download and freeze package state"
	@echo "  2. Run 'sudo make shedos-packages' to build ShedOS native packages"
	@echo "  3. Run 'sudo make iso' to build ISO using EXACT frozen packages (no network)"
	@echo "  4. ISO build is guaranteed to use same package versions as download time"

check-root:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "$(RED)Error: This target must be run as root (use sudo)$(NC)"; \
		exit 1; \
	fi

check-deps:
	@echo -e "$(GREEN)Checking dependencies...$(NC)"
	@command -v mkarchiso >/dev/null 2>&1 || { echo -e "$(RED)Error: archiso is not installed. Run: pacman -S archiso$(NC)"; exit 1; }
	@command -v qemu-system-x86_64 >/dev/null 2>&1 || echo -e "$(YELLOW)Warning: qemu not installed (needed for testing)$(NC)"
	@command -v repo-add >/dev/null 2>&1 || { echo -e "$(RED)Error: repo-add is not installed. Run: pacman -S pacman$(NC)"; exit 1; }
	@echo -e "$(GREEN)All required dependencies found$(NC)"


generate-packages:
	@echo -e "$(GREEN)Generating package list from packages/ directory...$(NC)"
	@./scripts/generate-package-list.sh
	@echo -e "$(GREEN)Package list generated: archiso/packages.x86_64$(NC)"

build-aur:
	@echo -e "$(GREEN)Building AUR packages...$(NC)"
	@./scripts/build-aur-packages.sh
	@echo -e "$(GREEN)AUR packages built$(NC)"

shedos-packages:
	@echo -e "$(GREEN)Building ShedOS native packages...$(NC)"
	@./scripts/build-shedos-packages.sh
	@echo -e "$(GREEN)ShedOS packages built into $(REPO_DIR)$(NC)"

download-packages: check-root
	@# NOTE: intentionally does NOT depend on `generate-packages`. That target
	@# regenerates archiso/packages.x86_64 to include EVERY package in
	@# packages/official/*.txt + packages/aur.txt, which blows past the
	@# "shedos-meta + 5 live-boot essentials" design and pacstraps proprietary
	@# AUR packages (VS Code, Chrome, Slack, …) straight into the ISO. The
	@# committed archiso/packages.x86_64 is the minimal one; keep it that way.
	@# download-packages.sh reads packages/official/*.txt + aur.txt directly.
	@echo -e "$(GREEN)Pre-downloading all packages...$(NC)"
	@echo -e "$(YELLOW)This avoids network issues during ISO build$(NC)"
	@./scripts/download-packages.sh
	@echo -e "$(GREEN)Packages downloaded and cached$(NC)"

prepare: check-root check-deps
	@echo -e "$(GREEN)Preparing build environment...$(NC)"
	@# Verify package cache BEFORE starting build
	@echo -e "$(GREEN)Verifying package cache completeness...$(NC)"
	@./scripts/verify-cache.sh || { \
		echo -e "$(RED)Cache verification failed!$(NC)"; \
		echo -e "$(RED)Run 'sudo make download-packages' first$(NC)"; \
		exit 1; \
	}
	@# Check if packages have been downloaded
	@if [ ! -d "$(REPO_DIR)" ]; then \
		echo -e "$(RED)ERROR: AUR repo directory not found: $(REPO_DIR)$(NC)"; \
		echo -e "$(RED)Run 'sudo make download-packages' first$(NC)"; \
		exit 1; \
	fi
	@if ! ls $(REPO_DIR)/*.pkg.tar.zst >/dev/null 2>&1; then \
		echo -e "$(RED)ERROR: No AUR packages found in $(REPO_DIR)$(NC)"; \
		echo -e "$(RED)Run 'sudo make download-packages' first$(NC)"; \
		exit 1; \
	fi
	@if ! ls $(REPO_DIR)/shedos-meta-*.pkg.tar.zst >/dev/null 2>&1; then \
		echo -e "$(RED)ERROR: ShedOS native packages not built in $(REPO_DIR)$(NC)"; \
		echo -e "$(RED)Run 'sudo make shedos-packages' first$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$$(ls -A /var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null)" ]; then \
		echo -e "$(YELLOW)WARNING: No cached packages found. Run 'sudo make download-packages' first for faster build$(NC)"; \
	fi
	@# Check if database cache exists (for deterministic builds)
	@if [ ! -d "db-cache" ] || [ -z "$$(ls -A db-cache/*.db 2>/dev/null)" ]; then \
		echo -e "$(RED)ERROR: Frozen package databases not found$(NC)"; \
		echo -e "$(RED)Run 'sudo make download-packages' to freeze package state$(NC)"; \
		exit 1; \
	fi
	@rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR) $(OUTPUT_DIR)
	@cp -r $(PROFILE_DIR)/* $(BUILD_DIR)/
	@# Render pacman.conf from template (path-independent build)
	@if [ ! -f "$(PROFILE_DIR)/pacman.conf.in" ]; then \
		echo -e "$(RED)ERROR: Missing template: $(PROFILE_DIR)/pacman.conf.in$(NC)"; \
		exit 1; \
	fi
	@sed "s|@SHEDOS_REPO@|$(shell pwd)/$(PROFILE_DIR)/shedos-repo|g" \
		$(PROFILE_DIR)/pacman.conf.in > $(BUILD_DIR)/pacman.conf
	@rm -f $(BUILD_DIR)/pacman.conf.in
	@# Stamp ISO_VER into profiledef.sh so iso_version in the built ISO's
	@# filename matches whatever CI (or a local build) picked via the
	@# SHEDOS_ISO_TAG env / VERSION fallback above.
	@sed -i "s|@SHEDOS_VERSION@|$(ISO_VER)|g" $(BUILD_DIR)/profiledef.sh
	@echo -e "$(GREEN)Restoring frozen package databases for deterministic build...$(NC)"
	@mkdir -p $(BUILD_DIR)/db-cache
	@cp db-cache/*.db $(BUILD_DIR)/db-cache/
	@echo -e "$(GREEN)Frozen databases restored: $$(ls -1 $(BUILD_DIR)/db-cache/ | wc -l) databases$(NC)"
	@echo -e "$(GREEN)Copying cached packages to build directory...$(NC)"
	@mkdir -p $(BUILD_DIR)/pkg-cache
	@# Exclude AUR packages - they come from shedos-repo only
	@# Generate exclude list from packages/aur.txt to avoid copying AUR packages
	@echo "Generating rsync excludes from packages/aur.txt..."
	@grep -v '^#' packages/aur.txt | grep -v '^$$' | awk '{print $$1"-*.pkg.tar.zst"}' > $(BUILD_DIR)/aur_excludes.txt
	@echo "Excluding $$(wc -l < $(BUILD_DIR)/aur_excludes.txt) AUR patterns"
	@rsync -a --info=progress2 \
		--exclude-from='$(BUILD_DIR)/aur_excludes.txt' \
		/var/cache/pacman/pkg/*.pkg.tar.zst $(BUILD_DIR)/pkg-cache/ 2>/dev/null || true
	@echo -e "$(GREEN)Cached packages copied (AUR packages excluded)$(NC)"
	@echo -e "$(GREEN)Configuring pacman for offline build...$(NC)"
	@# Copy smart download wrapper
	@mkdir -p $(BUILD_DIR)/scripts
	@cp scripts/pacman-offline-download.sh $(BUILD_DIR)/scripts/
	@chmod +x $(BUILD_DIR)/scripts/pacman-offline-download.sh
	@# Configure pacman: use ONLY our controlled pkg-cache (not system cache which may have wrong builds)
	@sed -i '/^\\[options\\]/a CacheDir = $(shell pwd)/$(BUILD_DIR)/pkg-cache/' $(BUILD_DIR)/pacman.conf
	@# Use smart wrapper: allows DB downloads, blocks package downloads (uses cache)
	@sed -i 's|^XferCommand.*|XferCommand = $(shell pwd)/$(BUILD_DIR)/scripts/pacman-offline-download.sh %o %u|' $(BUILD_DIR)/pacman.conf
	@mkdir -p $(BUILD_DIR)/airootfs/opt/shedos-installer
	@cp -r installer/shedos_installer $(BUILD_DIR)/airootfs/opt/shedos-installer/
	@cp -r packages $(BUILD_DIR)/airootfs/opt/shedos-installer/
	@# Ensure npm-cache is copied inside packages (it should be automatic if inside packages/, but explicit check helps)
	@mkdir -p $(BUILD_DIR)/airootfs/opt/shedos-installer/branding
	@cp -r branding/wallpapers $(BUILD_DIR)/airootfs/opt/shedos-installer/branding/
	@# Copy user configs for Calamares deployment
	@mkdir -p $(BUILD_DIR)/airootfs/opt/shedos-installer/configs
	@cp -r archiso/airootfs/etc/skel/.config/hypr $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/hyprland 2>/dev/null || true
	@cp -r archiso/airootfs/etc/skel/.config/waybar $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/waybar 2>/dev/null || true
	@cp -r archiso/airootfs/etc/skel/.config/kitty $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/kitty 2>/dev/null || true
	@cp -r archiso/airootfs/etc/skel/.config/mako $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/mako 2>/dev/null || true
	@cp -r archiso/airootfs/etc/skel/.config/walker $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/walker 2>/dev/null || true
	@cp -r archiso/airootfs/etc/skel/.config/rofi $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/rofi 2>/dev/null || true
	@cp -r archiso/airootfs/etc/skel/.config/nvim $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/nvim 2>/dev/null || true
	@cp -r archiso/airootfs/etc/skel/.config/git $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/git 2>/dev/null || true
	@cp -r archiso/airootfs/etc/skel/.config/mise $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/mise 2>/dev/null || true
	@mkdir -p $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/starship
	@cp archiso/airootfs/etc/skel/.config/starship.toml $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/starship/starship.toml 2>/dev/null || true
	@mkdir -p $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/zsh
	@cp archiso/airootfs/etc/skel/.zshrc $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/zsh/.zshrc 2>/dev/null || true
	@cp archiso/airootfs/etc/skel/.p10k.zsh $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/zsh/.p10k.zsh 2>/dev/null || true
	@cp -r archiso/airootfs/etc/skel/.config/fastfetch $(BUILD_DIR)/airootfs/opt/shedos-installer/configs/fastfetch 2>/dev/null || true
	@# Copy ShedOS branding files. Note: /etc/os-release and /etc/shedos-ascii.txt
	@# are now owned by shedos-system / shedos-branding packages respectively — do
	@# not copy them here or pacstrap will fail with "exists in filesystem".
	@mkdir -p $(BUILD_DIR)/airootfs/etc
	@cp branding/issue $(BUILD_DIR)/airootfs/etc/issue
	@cp branding/motd $(BUILD_DIR)/airootfs/etc/motd
	@mkdir -p $(BUILD_DIR)/airootfs/etc/neofetch
	@cp branding/neofetch/config.conf $(BUILD_DIR)/airootfs/etc/neofetch/
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
	@# rsync --exclude __pycache__: stale .pyc files from a prior local run can
	@# ship alongside the fresh .py and make Python load old bytecode on a
	@# read-only squashfs filesystem where it cannot recompile cleanly.
	@rsync -a --delete --exclude='__pycache__' \
		installer/calamares/modules-src/ \
		$(BUILD_DIR)/airootfs/usr/lib/calamares/modules/
	@chmod +x $(BUILD_DIR)/airootfs/usr/local/bin/*
	@chmod +x $(BUILD_DIR)/airootfs/root/customize_airootfs.sh
	@echo -e "$(GREEN)Build environment ready$(NC)"

iso: prepare
	@echo -e "$(GREEN)Building ShedOS $(VERSION)...$(NC)"
	@echo -e "$(YELLOW)This may take 15-30 minutes...$(NC)"
	mkarchiso -v -w $(WORK_DIR) -o $(OUTPUT_DIR) $(BUILD_DIR)
	@echo -e "$(GREEN)ISO built successfully: $(OUTPUT_DIR)/$(ISO_NAME)$(NC)"
	@cd $(OUTPUT_DIR) && sha256sum *.iso > sha256sums.txt 2>/dev/null || true
	@echo -e "$(GREEN)Build complete!$(NC)"
	@ls -lh $(OUTPUT_DIR)/*.iso 2>/dev/null || echo -e "$(RED)No ISO found$(NC)"

clean: check-root
	@echo -e "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR) $(WORK_DIR)
	@rm -rf /tmp/shedos-aur-build
	@echo -e "$(GREEN)Clean complete (packages preserved)$(NC)"

clean-all: check-root
	@echo -e "$(YELLOW)Removing all generated files...$(NC)"
	@rm -rf $(BUILD_DIR) $(WORK_DIR) $(OUTPUT_DIR)
	@rm -rf packages/aur
	@rm -rf archiso/shedos-repo
	@rm -rf db-cache
	@echo -e "$(GREEN)Full clean complete (packages and frozen databases removed)$(NC)"

test:
	@if [ ! -f "$(OUTPUT_DIR)/$(ISO_NAME)" ]; then \
		echo -e "$(RED)Error: ISO not found. Run 'sudo make iso' first$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)Testing ISO in QEMU (UEFI mode)...$(NC)"
	./scripts/test-iso.sh "$(OUTPUT_DIR)/$(ISO_NAME)" uefi

test-bios:
	@if [ ! -f "$(OUTPUT_DIR)/$(ISO_NAME)" ]; then \
		echo -e "$(RED)Error: ISO not found. Run 'sudo make iso' first$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)Testing ISO in QEMU (BIOS mode)...$(NC)"
	./scripts/test-iso.sh "$(OUTPUT_DIR)/$(ISO_NAME)" bios

test-installed:
	@if [ ! -f "$(TEST_DIR)/test-disk.qcow2" ]; then \
		echo -e "$(RED)Error: No installed system found. Run 'make test' and install first$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)Booting installed ShedOS...$(NC)"
	./scripts/test-iso.sh --disk-only

lint:
	@echo -e "$(GREEN)Running linters...$(NC)"
	@cd installer && python -m ruff check shedos_installer/ || true
	@cd installer && python -m mypy shedos_installer/ || true
	@echo -e "$(GREEN)Lint complete$(NC)"

test-review-configs:
	@echo -e "$(GREEN)Running shedos-review-configs fixture tests...$(NC)"
	@bash $(TEST_DIR)/review-configs/run.sh

test-sync-configs:
	@echo -e "$(GREEN)Running shedos-sync-configs fixture tests...$(NC)"
	@bash $(TEST_DIR)/sync-configs/run.sh

test-check-health:
	@echo -e "$(GREEN)Running shedos-check-health fixture tests...$(NC)"
	@bash $(TEST_DIR)/check-health/run.sh

dev-install:
	@echo -e "$(GREEN)Installing development dependencies...$(NC)"
	@cd installer && pip install -e ".[dev]"

.PHONY: dev-install lint test test-bios
