#!/usr/bin/env bash
# Emit a canonical SHA-256 of packaging/<pkgname>/. Used by
# bump-version.sh and build-shedos-packages.sh to skip rebuilds when
# source content is unchanged. Hashes tracked files only; git ls-files
# naturally excludes makepkg byproducts (target/, pkg/, *.pkg.tar.zst,
# man/build/, __pycache__) via .gitignore, keeping the digest identical
# between any clean clone and a working tree with local build artifacts.
#
# Cargo.lock IS hashed (for Rust packages: shedos-greeter,
# shedos-screensaver). It pins transitive dep versions and is the
# source of truth for reproducible Rust builds, so a `cargo update`
# legitimately means "the build inputs have changed → bump pkgrel".
# If you're trying to update Rust deps, run `cargo update` in the
# package dir, then `make bump` to record the new state; don't
# treat the resulting pkgrel bump as spurious.

set -euo pipefail

pkg=${1:?usage: $(basename "$0") <pkgname>}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)
dir=$root/packaging/$pkg
[[ -d $dir ]] || { echo "no such package dir: $dir" >&2; exit 1; }

# Workspace path siblings: any `path = "../<sibling>"` reference in this
# package's Cargo.toml(s) makes the sibling's source files a build input.
# Without folding them into the hash, editing e.g. shedos-prompt-ui would
# leave shedos-greeter's hash unchanged and CI would serve a stale cached
# package compiled against the OLD prompt-ui; silent regression.
sibling_paths=()
if compgen -G "$dir/Cargo.toml" >/dev/null; then
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        [[ "$name" == "$pkg" ]] && continue   # self-reference, skip
        sib="$root/packaging/$name"
        [[ -d "$sib" ]] || continue
        sibling_paths+=("packaging/$name/")
    done < <(
        find "$dir" -maxdepth 3 -name 'Cargo.toml' \
            -exec grep -hE 'path[[:space:]]*=[[:space:]]*"\.\./[a-zA-Z0-9_-]+"' {} \; |
        sed -E 's|.*path[[:space:]]*=[[:space:]]*"\.\./([a-zA-Z0-9_-]+)".*|\1|' |
        LC_ALL=C sort -u
    )
fi

# Emit a PKGBUILD for hashing with its top-of-file metadata comments and
# blank lines normalized away, so editing a doc comment no longer bumps
# pkgrel and rebuilds the package. Everything from the first build function
# onward is emitted verbatim, so any change to prepare()/build()/package()
# — down to text inside a heredoc that happens to start with '#' — still
# changes the hash. Only the PKGBUILD gets this; the tree/ files that
# actually ship stay byte-for-byte (cat, below), because a comment edit
# there changes the installed file and a rebuild is correct.
_emit_pkgbuild() {
    awk '
        !in_code && ($0 ~ /^[A-Za-z_][A-Za-z0-9_+-]*[ \t]*\(\)[ \t]*\{?[ \t]*$/ || $0 ~ /^function[ \t]/) { in_code = 1 }
        in_code { print; next }
        /^[ \t]*#/ { next }
        { sub(/[ \t]+$/, "") }
        /^[ \t]*$/ { next }
        { print }
    ' "$1"
}

cd "$root"
{
    # Hash the package itself plus any workspace path-dep siblings.
    # `git ls-files` over the union deterministically orders entries.
    git ls-files -z -- "packaging/$pkg/" "${sibling_paths[@]}" \
    | LC_ALL=C sort -z \
    | while IFS= read -r -d '' f; do
        case "$f" in
            "packaging/$pkg/.gitignore") continue ;;
            packaging/*/.gitignore) continue ;;
        esac
        printf '%s\n' "$f"
        if [ -L "$f" ]; then
            # Symlinks ship as-is (the link target string is the
            # contract). Following them with `cat` would error in CI
            # when the target points at an installed-system path
            # (e.g. /usr/lib/systemd/user/foo.service) that doesn't
            # exist in the checkout.
            readlink "$f"
        elif [[ $f == */PKGBUILD ]]; then
            _emit_pkgbuild "$f"
        else
            cat "$f"
        fi
    done
} | sha256sum | awk '{print $1}'
