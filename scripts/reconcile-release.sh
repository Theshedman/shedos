#!/usr/bin/env bash
# Reconcile the release manifest to the live Arch closure, then bump.
# A release tag must point at the result of this: resolve shedos-meta's
# transitive Arch deps, re-render its PKGBUILD, then bump pkgver/pkgrel and
# the hash manifest. cut-release.yml runs it before tagging (in the same
# container that later validates the tag), and the `make release` pre-flight
# runs it to refuse a drifting local cut.
#
# Uses the current VERSION; set the VERSION file first to change it. Needs
# root: resolve-meta-closure.sh runs pacman -Sy against the live repos.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

"$here/resolve-meta-closure.sh"
"$here/render-meta-depends.sh"
"$here/bump-version.sh"
