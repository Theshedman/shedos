#!/usr/bin/env bash
# Emit a canonical SHA-256 of packaging/<pkgname>/. Used by
# bump-version.sh and build-shedos-packages.sh to skip rebuilds when
# source content is unchanged. LC_ALL=C sort makes the digest
# runner-agnostic; the exclusion list filters makepkg byproducts and
# the artifact files themselves (which would self-feedback into the
# hash on a successive build).
#
# Cargo.lock IS hashed (for Rust packages: shedos-greeter,
# shedos-screensaver). It pins transitive dep versions and is the
# source of truth for reproducible Rust builds, so a `cargo update`
# legitimately means "the build inputs have changed → bump pkgrel".
# If you're trying to update Rust deps, run `cargo update` in the
# package dir, then `make bump` to record the new state — don't
# treat the resulting pkgrel bump as spurious.

set -euo pipefail

pkg=${1:?usage: $(basename "$0") <pkgname>}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)
dir=$root/packaging/$pkg
[[ -d $dir ]] || { echo "no such package dir: $dir" >&2; exit 1; }

cd "$root"
{
    find "packaging/$pkg" -type f \
        -not -path "packaging/$pkg/target/*" \
        -not -path "packaging/$pkg/pkg/*" \
        -not -path "packaging/$pkg/src/*.tar.*" \
        -not -name '.gitignore' \
        -not -name '*.pkg.tar.zst' \
        -not -name '*.pkg.tar.zst.sig' \
        -print0 \
    | LC_ALL=C sort -z \
    | while IFS= read -r -d '' f; do
        printf '%s\n' "$f"
        cat "$f"
    done
} | sha256sum | awk '{print $1}'
