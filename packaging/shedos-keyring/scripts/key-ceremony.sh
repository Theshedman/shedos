#!/usr/bin/env bash
# key-ceremony.sh — generate the ShedOS repo signing key.
#
# Run this ONCE, offline, on a trusted machine. Outputs:
#   - tree/shedos.gpg                (public key, committed)
#   - tree/shedos-trusted            (fingerprint, committed)
#   - ./shedos-private.asc           (private key, DO NOT COMMIT)
#
# After the script finishes:
#   1. cat shedos-private.asc | wl-copy (or xclip)
#   2. Paste into GitHub → Settings → Secrets → SHEDOS_REPO_SIGNING_KEY
#   3. shred -u shedos-private.asc
#   4. git add tree/shedos.gpg tree/shedos-trusted && git commit
#
# Key parameters:
#   - RSA 4096 (compatible with pacman-key and widely-supported GnuPG)
#   - No passphrase (required for non-interactive CI signing)
#   - No expiry (rotation is a manual event we trigger deliberately)

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
pkg_dir=$(cd -- "$here/.." && pwd)

if [[ -d "${GNUPGHOME:-}" ]]; then
    echo "Refusing to pollute existing GNUPGHOME=$GNUPGHOME" >&2
    echo "Run in a temporary shell: GNUPGHOME=\$(mktemp -d) ./$0" >&2
    exit 2
fi

tmpgpg=$(mktemp -d)
trap 'rm -rf "$tmpgpg"' EXIT
export GNUPGHOME=$tmpgpg

cat > "$tmpgpg/keyparams" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign
Name-Real: ShedOS Repository
Name-Email: repo@shedos.org
Expire-Date: 0
%commit
EOF

echo "Generating 4096-bit RSA signing key (no passphrase)…"
gpg --batch --generate-key "$tmpgpg/keyparams"

fp=$(gpg --list-keys --with-colons repo@shedos.org \
    | awk -F: '/^fpr:/ { print $10; exit }')

if [[ ${#fp} -ne 40 ]]; then
    echo "unexpected fingerprint: $fp" >&2
    exit 3
fi

echo "Fingerprint: $fp"

gpg --export repo@shedos.org > "$pkg_dir/tree/shedos.gpg"
echo "$fp" > "$pkg_dir/tree/shedos-trusted"
gpg --armor --export-secret-keys repo@shedos.org > "$pkg_dir/shedos-private.asc"

echo
echo "Public key  → $pkg_dir/tree/shedos.gpg"
echo "Fingerprint → $pkg_dir/tree/shedos-trusted"
echo "Private key → $pkg_dir/shedos-private.asc  (upload and shred)"
echo
echo "Upload shedos-private.asc as SHEDOS_REPO_SIGNING_KEY in GitHub"
echo "repo secrets, then:  shred -u $pkg_dir/shedos-private.asc"
