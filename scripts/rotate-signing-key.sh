#!/usr/bin/env bash
# Stage a signing-key rotation: merge a new PUBLIC key into the
# shipped keyring and append its fingerprint to the trusted list.
# The full sequence (what to do before and after this script) lives
# in docs/key-rotation.md — read it first.
#
# Usage: scripts/rotate-signing-key.sh <new-public-key-file>
#
# This script only touches the repo working tree; review the diff,
# commit through the normal gates, and let the fleet re-trust via the
# keyring upgrade before the CI secret is swapped.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/.." && pwd)
keyring=$root/packaging/shedos-keyring/tree/shedos.gpg
trusted=$root/packaging/shedos-keyring/tree/shedos-trusted

newkey=${1:?usage: $0 <new-public-key-file>}
[[ -f $newkey ]] || { echo "no such file: $newkey" >&2; exit 2; }

# The file must contain exactly one public key and no secret material.
if gpg --show-keys --with-colons "$newkey" 2>/dev/null | grep -q '^sec:'; then
    echo "REFUSING: $newkey contains secret key material" >&2
    exit 2
fi
mapfile -t fps < <(gpg --show-keys --with-colons "$newkey" 2>/dev/null \
    | awk -F: '$1 == "pub" { want=1; next } want && $1 == "fpr" { print $10; want=0 }')
(( ${#fps[@]} == 1 )) || { echo "expected exactly one public key, found ${#fps[@]}" >&2; exit 2; }
fp=${fps[0]}

if grep -qx "$fp" <(awk 'NF && $1 !~ /^#/' "$trusted"); then
    echo "fingerprint $fp already trusted; nothing to do"
    exit 0
fi

# Merge old keyring + new key in a scratch GNUPGHOME so the developer's
# personal keyring never participates.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GNUPGHOME=$tmp/gnupg
mkdir -m700 "$GNUPGHOME"
gpg --batch --import "$keyring" "$newkey" 2>/dev/null
gpg --batch --export > "$tmp/shedos.gpg"
[[ -s $tmp/shedos.gpg ]] || { echo "merged keyring is empty" >&2; exit 1; }

install -m644 "$tmp/shedos.gpg" "$keyring"
printf '%s\n' "$fp" >> "$trusted"

echo "staged: $fp added to shedos.gpg + shedos-trusted"
echo "next:   update SHEDOS_KEY_FPRS in packaging/shedos-migrate-to-packaged/"
echo "        tree/usr/libexec/shedman/migrate, then follow docs/key-rotation.md"
