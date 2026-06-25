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

# Claude Code is baked into /etc/skel from the official installer at build
# time (inert bytes in the squashfs, never a signed repo package — see
# aur-norepublish.txt). Pin the version for reproducible ISOs; bump here.
CLAUDE_CODE_VERSION := 2.1.170

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: all iso clean clean-all test help check-deps check-root prepare build-aur download-packages generate-packages shedos-packages regen bump bump-today bump-check release release-rc release-stable _cut push test-review-configs test-sync-configs test-check-health test-tui-logs test-tui-history test-apply test-apply-checkpoint test-doctor test-shedman test-status test-completions test-migrate test-man test-screenrecord test-kernel test-uki test-tpm2 test-secureboot test-key test-encrypt test-installer test-config test-rollback test-update test-install test-screensaver test-screensaver-rust lint-rust

all: iso

help:
	@echo "ShedOS Build System v$(VERSION)"
	@echo ""
	@echo "Usage: sudo make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  regen              Regen closure + archiso/packages.x86_64 + shedos-meta PKGBUILD"
	@echo "  bump               Hash-aware pkgver/pkgrel bump (uses current VERSION)"
	@echo "  bump-today         Set VERSION to today's date and run bump"
	@echo "  bump-check         Validate manifest matches working tree; CI gate"
	@echo "  release-rc         Cut an rc tag in CI (reconcile + tag, drift-proof)"
	@echo "  release-stable     Cut a stable tag in CI"
	@echo "  release TAG=v...   Local cut escape hatch (needs ALLOW_LOCAL_CUT=1)"
	@echo "  push               Fetch + rebase onto origin/main + push (handles CI auto-bumps)"
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
	@echo "  test-tui-logs      Run shedos-logs pilot tests"
	@echo "  test-tui-history   Run shedos-upgrade-history pilot tests"
	@echo "  test-apply         Run shedos-apply fixture tests"
	@echo "  test-apply-checkpoint  Run apply_core StateCheckpoint tests"
	@echo "  test-doctor        Run shedos-doctor pilot tests"
	@echo "  test-shedman       Run shedman dispatcher + shim parity tests"
	@echo "  test-status        Run shedman status aggregated-dashboard tests"
	@echo "  test-completions   Run shedman bash + zsh completion tests"
	@echo "  test-migrate       Run shedman migrate retrofit-tool tests"
	@echo "  test-man           Run shedman man-page sanity tests"
	@echo "  test-screenrecord  Run shedman screenrecord fixture tests"
	@echo "  test-kernel        Run kernel (linux-zen) migration-wiring contract tests"
	@echo "  test-uki           Run UKI build/sign/atomic-place pipeline tests"
	@echo "  test-tpm2          Run shedman tpm2 verb tests"
	@echo "  test-secureboot    Run shedman secureboot verb tests"
	@echo "  test-key           Run shedman key verb tests"
	@echo "  test-encrypt       Run shedman encrypt preflight tests"
	@echo "  test-installer     Run installer pytest suite (Calamares modules + core)"
	@echo "  test-config        Run shedman config umbrella tests"
	@echo "  test-rollback      Run shedman rollback smoke tests"
	@echo "  test-update        Run shedman update smoke tests"
	@echo "  test-install       Run shedman install smoke tests"
	@echo "  test-all           Run every test/*/run.sh via CI's discovery"
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
	@# Hard-required for `make iso`. Tools used only by other targets
	@# (python, ruff/mypy, qemu, yay) are warnings.
	@echo -e "$(GREEN)Checking dependencies...$(NC)"
	@command -v mkarchiso >/dev/null 2>&1 || { echo -e "$(RED)Error: archiso is not installed. Run: pacman -S archiso$(NC)"; exit 1; }
	@command -v repo-add >/dev/null 2>&1 || { echo -e "$(RED)Error: repo-add is not installed. Run: pacman -S pacman$(NC)"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo -e "$(RED)Error: git is not installed. Run: pacman -S git$(NC)"; exit 1; }
	@command -v python >/dev/null 2>&1 || echo -e "$(YELLOW)Warning: python not installed (needed by installer tests). Run: pacman -S python$(NC)"
	@command -v ruff >/dev/null 2>&1 || echo -e "$(YELLOW)Warning: ruff not installed (needed for 'make lint'). Run: cd installer && pip install -e .[dev]$(NC)"
	@command -v mypy >/dev/null 2>&1 || echo -e "$(YELLOW)Warning: mypy not installed (needed for 'make lint'). Run: cd installer && pip install -e .[dev]$(NC)"
	@command -v qemu-system-x86_64 >/dev/null 2>&1 || echo -e "$(YELLOW)Warning: qemu not installed (needed for 'make test')$(NC)"
	@command -v yay >/dev/null 2>&1 || echo -e "$(YELLOW)Warning: yay not installed (needed for AUR builds outside CI)$(NC)"
	@echo -e "$(GREEN)All required dependencies found$(NC)"


generate-packages:
	@echo -e "$(GREEN)Generating package list from packages/ directory...$(NC)"
	@./scripts/generate-package-list.sh
	@echo -e "$(GREEN)Package list generated: archiso/packages.x86_64$(NC)"

regen: check-root
	@echo -e "$(GREEN)Regenerating closure → archiso/packages.x86_64 → shedos-meta PKGBUILD...$(NC)"
	@./scripts/resolve-meta-closure.sh
	@./scripts/generate-package-list.sh
	@./scripts/render-meta-depends.sh
	@echo -e "$(GREEN)Regen complete. Review with: git diff packages/ archiso/packages.x86_64 packaging/shedos-meta/$(NC)"

bump:
	@./scripts/bump-version.sh

bump-today:
	@./scripts/bump-version.sh --today

bump-check:
	@./scripts/bump-version.sh --check

# Local escape hatch for backports / retags on a non-today date. Prefer the
# CI cut (make release-rc); a local cut can drift from CI's closure
# resolution, so it requires ALLOW_LOCAL_CUT=1.
release:
	@if [ -z "$(ALLOW_LOCAL_CUT)" ]; then \
		echo -e "$(YELLOW)Cut in CI: make release-rc / release-stable. Local cuts can drift.$(NC)" >&2; \
		echo -e "$(YELLOW)Force a local cut: make release TAG=$(TAG) ALLOW_LOCAL_CUT=1$(NC)" >&2; \
		exit 1; \
	fi
	@if [ -z "$(TAG)" ]; then \
		echo -e "$(RED)Usage: make release TAG=v<CalVer>[-rcN]$(NC)" >&2; exit 1; \
	fi
	@case "$(TAG)" in \
		v[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]|v[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]-rc[0-9]*) ;; \
		*) echo -e "$(RED)TAG '$(TAG)' is not v<CalVer>[-rcN]$(NC)" >&2; exit 1 ;; \
	esac
	@branch="$$(git rev-parse --abbrev-ref HEAD)"; \
	if [ "$$branch" != "main" ]; then \
		echo -e "$(RED)Must be on main (currently on $$branch)$(NC)" >&2; exit 1; \
	fi
	@if ! git diff --quiet HEAD; then \
		echo -e "$(RED)Working tree has uncommitted changes; commit or stash first$(NC)" >&2; \
		git status --short >&2; exit 1; \
	fi
	@if git rev-parse --verify --quiet "refs/tags/$(TAG)" >/dev/null; then \
		echo -e "$(RED)Tag $(TAG) already exists locally; delete it first if retagging$(NC)" >&2; exit 1; \
	fi
	@if git ls-remote --tags origin "refs/tags/$(TAG)" 2>/dev/null | grep -q "refs/tags/$(TAG)$$"; then \
		echo -e "$(RED)Tag $(TAG) already exists on origin$(NC)" >&2; exit 1; \
	fi
	@echo -e "$(GREEN)→ Pulling latest main...$(NC)"
	@git pull --ff-only origin main
	@expected_ver="$$(echo $(TAG) | sed -E 's/^v//; s/-rc[0-9]+$$//')"; \
	actual_ver="$$(cat VERSION)"; \
	if [ "$$expected_ver" != "$$actual_ver" ]; then \
		echo -e "$(YELLOW)→ VERSION $$actual_ver → $$expected_ver (from TAG)$(NC)"; \
		echo "$$expected_ver" > VERSION; \
	fi
	@if [ "$$(id -u)" = 0 ]; then \
		echo -e "$(GREEN)→ Reconciling closure + manifest...$(NC)"; \
		./scripts/reconcile-release.sh; \
	else \
		echo -e "$(YELLOW)→ not root: closure unresolved, CI's cut is authoritative$(NC)"; \
		./scripts/bump-version.sh "$$(cat VERSION)"; \
	fi
	@if ! git diff --quiet -- packaging/ VERSION; then \
		git add packaging/ VERSION; \
		git commit -m "release: $(TAG)"; \
		echo -e "$(GREEN)→ Committed local bump for $(TAG)$(NC)"; \
	else \
		echo -e "$(GREEN)→ Manifest already in sync; no bump commit needed$(NC)"; \
	fi
	@echo -e "$(GREEN)→ Tagging $(TAG) at HEAD ($$( git rev-parse --short HEAD ))...$(NC)"
	@git tag -a "$(TAG)" -m "release: $(TAG)"
	@echo -e "$(GREEN)→ Atomic push (main + tag in one transaction)...$(NC)"
	@if ! git push --atomic origin main "refs/tags/$(TAG)"; then \
		echo -e "$(RED)Atomic push failed; rolling back local tag$(NC)" >&2; \
		git tag -d "$(TAG)" >/dev/null 2>&1; \
		exit 1; \
	fi
	@echo -e "$(GREEN)Released $(TAG). CI will build and publish.$(NC)"

# Pull-rebase first. CI auto-bumps pkgrel after each push, so a
# bare `git push` is rejected non-ff.
push:
	@branch="$$(git rev-parse --abbrev-ref HEAD)"; \
	if [ "$$branch" != "main" ]; then \
		echo -e "$(RED)Must be on main (currently on $$branch)$(NC)" >&2; exit 1; \
	fi
	@if ! git diff --quiet HEAD; then \
		echo -e "$(RED)Working tree has uncommitted changes; commit or stash first$(NC)" >&2; \
		git status --short >&2; exit 1; \
	fi
	@echo -e "$(GREEN)→ Fetching origin...$(NC)"
	@git fetch origin
	@echo -e "$(GREEN)→ Rebasing local commits onto origin/main...$(NC)"
	@git pull --rebase origin main
	@if [ "$$(git rev-parse HEAD)" = "$$(git rev-parse origin/main)" ]; then \
		echo -e "$(GREEN)→ Already up to date with origin/main; nothing to push.$(NC)"; \
		exit 0; \
	fi
	@echo -e "$(GREEN)→ Guarding against CI-managed release bumps...$(NC)"
	@bash scripts/check-release-bump.sh origin/main..HEAD
	@count=$$(git rev-list --count origin/main..HEAD); \
	echo -e "$(GREEN)→ Pushing $$count commit(s) to origin/main...$(NC)"
	@git push origin main
	@echo -e "$(GREEN)Pushed. CI will build and publish.$(NC)"

# Cut a release in CI. cut-release.yml reconciles main and tags inside the
# same container that validates the tag, so the cut can't land on a drifting
# manifest. Date + rcN are computed there.
release-stable:
	@$(MAKE) _cut KIND=stable

release-rc:
	@$(MAKE) _cut KIND=rc

_cut:
	@gh workflow run cut-release.yml -f kind=$(KIND)
	@echo -e "$(GREEN)→ dispatched cut-release ($(KIND)); watching...$(NC)"
	@sleep 5
	@id="$$(gh run list --workflow=cut-release.yml --limit 1 --json databaseId --jq '.[0].databaseId')"; \
	gh run watch "$$id" --exit-status

build-aur:
	@echo -e "$(GREEN)Building AUR packages...$(NC)"
	@./scripts/build-aur-packages.sh
	@echo -e "$(GREEN)AUR packages built$(NC)"

shedos-packages:
	@echo -e "$(GREEN)Building ShedOS native packages...$(NC)"
	@./scripts/build-shedos-packages.sh
	@echo -e "$(GREEN)ShedOS packages built into $(REPO_DIR)$(NC)"

download-packages: check-root generate-packages
	@# generate-packages first: never trust the committed packages.x86_64.
	@echo -e "$(GREEN)Pre-downloading all packages...$(NC)"
	@echo -e "$(YELLOW)This avoids network issues during ISO build$(NC)"
	@./scripts/download-packages.sh
	@echo -e "$(GREEN)Packages downloaded and cached$(NC)"

prepare: check-root check-deps generate-packages
	@echo -e "$(GREEN)Preparing build environment...$(NC)"
	@echo -e "$(GREEN)Verifying shedos-* PKGBUILD deps are covered by source lists...$(NC)"
	@./scripts/verify-shedos-deps.sh
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
	@sed "s|@SHEDOS_REPO@|$(abspath $(PROFILE_DIR)/shedos-repo)|g" \
		$(PROFILE_DIR)/pacman.conf.in > $(BUILD_DIR)/pacman.conf
	@rm -f $(BUILD_DIR)/pacman.conf.in
	@# Channel marker: installs from this ISO read it via shedos-system's
	@# install fence to pick /test vs /stable. CI bakes stable on stable
	@# tags (build-iso.yml); local builds always go test.
	@if [ ! -f "$(BUILD_DIR)/airootfs/etc/pacman.conf.in" ]; then \
		echo -e "$(RED)ERROR: missing $(BUILD_DIR)/airootfs/etc/pacman.conf.in$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(BUILD_DIR)/airootfs/etc/shedos/channel" ]; then \
		mkdir -p $(BUILD_DIR)/airootfs/etc/shedos; \
		printf 'test\n' > $(BUILD_DIR)/airootfs/etc/shedos/channel; \
	fi
	@cp $(BUILD_DIR)/airootfs/etc/pacman.conf.in \
		$(BUILD_DIR)/airootfs/etc/pacman.conf
	@rm -f $(BUILD_DIR)/airootfs/etc/pacman.conf.in
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
	@# Stale-package guard: keep only .pkg.tar.zst whose pkgname appears
	@# in archiso/packages.x86_64. Removed-from-packages/* entries with
	@# old cached binaries cannot leak into pacstrap.
	@awk '!/^#/ && NF {print $$1}' archiso/packages.x86_64 \
		| sort -u > $(abspath $(BUILD_DIR))/_keep_pkgs.txt
	@cd $(BUILD_DIR)/pkg-cache && \
	for f in *.pkg.tar.zst; do \
		[ -f "$$f" ] || continue; \
		base=$$(basename "$$f"); \
		pkgname=$${base%-*-*-*.pkg.tar.zst}; \
		grep -Fxq "$$pkgname" $(abspath $(BUILD_DIR))/_keep_pkgs.txt || rm -f "$$f"; \
	done
	@rm -f $(abspath $(BUILD_DIR))/_keep_pkgs.txt
	@echo -e "$(GREEN)Cached packages copied (AUR packages excluded; stale entries pruned)$(NC)"
	@echo -e "$(GREEN)Configuring pacman for offline build...$(NC)"
	@# Copy smart download wrapper
	@mkdir -p $(BUILD_DIR)/scripts
	@cp scripts/pacman-offline-download.sh $(BUILD_DIR)/scripts/
	@chmod +x $(BUILD_DIR)/scripts/pacman-offline-download.sh
	@# Configure pacman: use ONLY our controlled pkg-cache (not system cache which may have wrong builds)
	@sed -i '/^\\[options\\]/a CacheDir = $(abspath $(BUILD_DIR))/pkg-cache/' $(BUILD_DIR)/pacman.conf
	@# Use smart wrapper: allows DB downloads, blocks package downloads (uses cache)
	@sed -i 's|^XferCommand.*|XferCommand = $(abspath $(BUILD_DIR))/scripts/pacman-offline-download.sh %o %u|' $(BUILD_DIR)/pacman.conf
	@mkdir -p $(BUILD_DIR)/airootfs/opt/shedos-installer
	@cp -r installer/shedos_installer $(BUILD_DIR)/airootfs/opt/shedos-installer/
	@cp -r packages $(BUILD_DIR)/airootfs/opt/shedos-installer/
	@# Ensure npm-cache is copied inside packages (it should be automatic if inside packages/, but explicit check helps)
	@mkdir -p $(BUILD_DIR)/airootfs/opt/shedos-installer/branding
	@cp -r branding/wallpapers $(BUILD_DIR)/airootfs/opt/shedos-installer/branding/
	@# Copy ShedOS branding files. Note: /etc/os-release and /etc/shedos-ascii.txt
	@# are now owned by shedos-system / shedos-branding packages respectively — do
	@# not copy them here or pacstrap will fail with "exists in filesystem".
	@mkdir -p $(BUILD_DIR)/airootfs/etc
	@cp branding/issue $(BUILD_DIR)/airootfs/etc/issue
	@cp branding/motd $(BUILD_DIR)/airootfs/etc/motd
	@echo -e "$(GREEN)Baking Claude Code $(CLAUDE_CODE_VERSION) into /etc/skel...$(NC)"
	@bash scripts/bake-claude-code.sh $(CLAUDE_CODE_VERSION) $(BUILD_DIR)/airootfs/etc/skel
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
	@echo -e "$(GREEN)Build environment ready$(NC)"

iso: prepare
	@echo -e "$(GREEN)Building ShedOS $(VERSION)...$(NC)"
	@echo -e "$(YELLOW)This may take 15-30 minutes...$(NC)"
	mkarchiso -v -w $(WORK_DIR) -o $(OUTPUT_DIR) $(BUILD_DIR)
	@iso_path="$(OUTPUT_DIR)/$(ISO_NAME)"; \
	if [ ! -f "$$iso_path" ]; then \
		iso_path=$$(ls -1t $(OUTPUT_DIR)/shedos-*.iso | head -1); \
	fi; \
	iso_size=$$(stat -c %s "$$iso_path"); \
	echo -e "$(GREEN)ISO size: $$(numfmt --to=iec --suffix=B $$iso_size)$(NC)"
	@echo -e "$(GREEN)ISO built successfully: $(OUTPUT_DIR)/$(ISO_NAME)$(NC)"
	@cd $(OUTPUT_DIR) && sha256sum *.iso > sha256sums.txt 2>/dev/null || true
	@echo -e "$(GREEN)Build complete!$(NC)"
	@ls -lh $(OUTPUT_DIR)/*.iso 2>/dev/null || echo -e "$(RED)No ISO found$(NC)"

# One-command local ISO build. Runs the same sequence CI does before
# mkarchiso (.github/workflows/build-iso.yml) so `make iso` never runs against
# a stale or empty archiso/shedos-repo: build the AUR deps, build the ShedOS
# native packages (each repo-add's into shedos-repo), then the ISO. The bare
# `make iso` deliberately stays a leaf that only assembles + mkarchiso, since
# CI invokes it after running those steps itself.
#
# Channel is always 'test' on a local build (CI bakes 'stable' only on a
# stable tag). If you changed shedos-meta's dependency closure, run
# `sudo make regen` first and commit the diff — CI re-resolves the closure on
# every build; locally it's a deliberate, reviewable step.
iso-local: check-root
	@$(MAKE) download-packages
	@$(MAKE) shedos-packages
	@$(MAKE) iso
	@echo -e "$(GREEN)Local ISO built. Boot it with: make test$(NC)"

clean: check-root
	@echo -e "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR) $(WORK_DIR)
	@rm -rf /var/tmp/shedos-aur-build /tmp/shedos-aur-build /var/tmp/shedos-pkgbuild /tmp/shedos-pkgbuild
	@echo -e "$(GREEN)Clean complete (packages preserved)$(NC)"

clean-all: check-root
	@echo -e "$(YELLOW)Removing all generated files...$(NC)"
	@rm -rf $(BUILD_DIR) $(WORK_DIR) $(OUTPUT_DIR)
	@rm -rf packages/aur
	@rm -rf archiso/shedos-repo
	@rm -rf db-cache
	@echo -e "$(GREEN)Full clean complete (packages and frozen databases removed)$(NC)"

# test / test-bios pick: ISO=… > out/<current-VERSION>.iso > newest out/*.iso.
ISO ?=

test:
	@if [ -n "$(ISO)" ] && [ ! -f "$(ISO)" ]; then \
		echo -e "$(RED)Error: ISO=$(ISO) not found.$(NC)" >&2; \
		exit 1; \
	fi
	@iso="$(ISO)"; \
	if [ -z "$$iso" ] && [ -f "$(OUTPUT_DIR)/$(ISO_NAME)" ]; then \
		iso="$(OUTPUT_DIR)/$(ISO_NAME)"; \
	fi; \
	if [ -z "$$iso" ]; then \
		iso=$$(ls -1t $(OUTPUT_DIR)/shedos-*.iso 2>/dev/null | head -n1); \
		if [ -n "$$iso" ]; then \
			echo -e "$(YELLOW)Note: $(ISO_NAME) not in $(OUTPUT_DIR)/; using newest ISO: $$iso$(NC)"; \
		fi; \
	fi; \
	if [ -z "$$iso" ]; then \
		echo -e "$(RED)Error: no ISO found in $(OUTPUT_DIR)/. Run 'sudo make iso' or pass ISO=path/to/file.iso.$(NC)" >&2; \
		exit 1; \
	fi; \
	echo -e "$(GREEN)Testing $$iso in QEMU (UEFI mode)...$(NC)"; \
	./scripts/test-iso.sh "$$iso" uefi

test-bios:
	@if [ -n "$(ISO)" ] && [ ! -f "$(ISO)" ]; then \
		echo -e "$(RED)Error: ISO=$(ISO) not found.$(NC)" >&2; \
		exit 1; \
	fi
	@iso="$(ISO)"; \
	if [ -z "$$iso" ] && [ -f "$(OUTPUT_DIR)/$(ISO_NAME)" ]; then \
		iso="$(OUTPUT_DIR)/$(ISO_NAME)"; \
	fi; \
	if [ -z "$$iso" ]; then \
		iso=$$(ls -1t $(OUTPUT_DIR)/shedos-*.iso 2>/dev/null | head -n1); \
		if [ -n "$$iso" ]; then \
			echo -e "$(YELLOW)Note: $(ISO_NAME) not in $(OUTPUT_DIR)/; using newest ISO: $$iso$(NC)"; \
		fi; \
	fi; \
	if [ -z "$$iso" ]; then \
		echo -e "$(RED)Error: no ISO found in $(OUTPUT_DIR)/. Run 'sudo make iso' or pass ISO=path/to/file.iso.$(NC)" >&2; \
		exit 1; \
	fi; \
	echo -e "$(GREEN)Testing $$iso in QEMU (BIOS mode)...$(NC)"; \
	./scripts/test-iso.sh "$$iso" bios

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

test-tui-logs:
	@echo -e "$(GREEN)Running shedos-logs pilot tests...$(NC)"
	@bash $(TEST_DIR)/logs/run.sh

test-tui-history:
	@echo -e "$(GREEN)Running shedos-upgrade-history pilot tests...$(NC)"
	@bash $(TEST_DIR)/upgrade-history/run.sh

test-apply:
	@echo -e "$(GREEN)Running shedos-apply fixture tests...$(NC)"
	@bash $(TEST_DIR)/apply/run.sh

check:
	@bash scripts/run-shell-tests.sh

# Every test/*/run.sh via the same discovery CI uses (tests.yml →
# run-shell-tests.sh), so a suite can never go dark again by missing
# its individual Makefile target.
test-all: check

test-apply-checkpoint:
	@echo -e "$(GREEN)Running apply_core StateCheckpoint tests...$(NC)"
	@bash $(TEST_DIR)/apply-checkpoint/run.sh

test-doctor:
	@echo -e "$(GREEN)Running shedos-doctor pilot tests...$(NC)"
	@bash $(TEST_DIR)/doctor/run.sh

test-shedman:
	@echo -e "$(GREEN)Running shedman dispatcher + shim parity tests...$(NC)"
	@bash $(TEST_DIR)/shedman/run.sh

test-status:
	@echo -e "$(GREEN)Running shedman status aggregated-dashboard tests...$(NC)"
	@bash $(TEST_DIR)/status/run.sh

test-completions:
	@echo -e "$(GREEN)Running shedman bash + zsh completion tests...$(NC)"
	@bash $(TEST_DIR)/completions/run.sh

test-migrate:
	@echo -e "$(GREEN)Running shedman migrate retrofit-tool tests...$(NC)"
	@bash $(TEST_DIR)/migrate/run.sh

test-man:
	@echo -e "$(GREEN)Running shedman man-page sanity tests...$(NC)"
	@bash $(TEST_DIR)/man/run.sh

test-screenrecord:
	@echo -e "$(GREEN)Running shedman screenrecord fixture tests...$(NC)"
	@bash $(TEST_DIR)/screenrecord/run.sh

test-kernel:
	@echo -e "$(GREEN)Running kernel (linux-zen) migration-wiring contract tests...$(NC)"
	@bash $(TEST_DIR)/kernel/run.sh

test-uki:
	@echo -e "$(GREEN)Running UKI build/sign/atomic-place pipeline tests...$(NC)"
	@bash $(TEST_DIR)/uki/run.sh

test-tpm2:
	@echo -e "$(GREEN)Running shedman tpm2 verb tests...$(NC)"
	@bash $(TEST_DIR)/tpm2/run.sh

test-secureboot:
	@echo -e "$(GREEN)Running shedman secureboot verb tests...$(NC)"
	@bash $(TEST_DIR)/secureboot/run.sh

test-key:
	@echo -e "$(GREEN)Running shedman key verb tests...$(NC)"
	@bash $(TEST_DIR)/key/run.sh

test-encrypt:
	@echo -e "$(GREEN)Running shedman encrypt tests...$(NC)"
	@bash $(TEST_DIR)/encrypt/run.sh
	@bash $(TEST_DIR)/encrypt/arm.sh
	@bash $(TEST_DIR)/encrypt/enroll.sh
	@bash $(TEST_DIR)/encrypt/reconfigure.sh
	@bash $(TEST_DIR)/encrypt/finalize.sh
	@bash $(TEST_DIR)/encrypt/loop-e2e.sh
	@bash $(TEST_DIR)/encrypt/swap-loop-e2e.sh

test-installer:
	@echo -e "$(GREEN)Running installer pytest suite...$(NC)"
	@cd installer && python -m pytest tests/ -v

test-config:
	@echo -e "$(GREEN)Running shedman config umbrella tests...$(NC)"
	@bash $(TEST_DIR)/config/run.sh

test-rollback:
	@echo -e "$(GREEN)Running shedman rollback smoke tests...$(NC)"
	@bash $(TEST_DIR)/rollback/run.sh

test-update:
	@echo -e "$(GREEN)Running shedman update smoke tests...$(NC)"
	@bash $(TEST_DIR)/update/run.sh

test-install:
	@echo -e "$(GREEN)Running shedman install smoke tests...$(NC)"
	@bash $(TEST_DIR)/install/run.sh

test-screensaver:
	@echo -e "$(GREEN)Running shedos-screensaver shell tests...$(NC)"
	@bash $(TEST_DIR)/screensaver/run.sh

test-screensaver-rust:
	@echo -e "$(GREEN)Running shedos-screensaver cargo tests...$(NC)"
	@cd packaging/shedos-screensaver && cargo test --workspace --locked

lint-rust:
	@echo -e "$(GREEN)Running cargo clippy + rustfmt --check...$(NC)"
	@cd packaging/shedos-screensaver && cargo clippy --workspace --locked -- -D warnings
	@cd packaging/shedos-screensaver && cargo fmt --all -- --check

dev-install:
	@echo -e "$(GREEN)Installing development dependencies...$(NC)"
	@cd installer && pip install -e ".[dev]"

.PHONY: dev-install lint test test-bios check test-all
