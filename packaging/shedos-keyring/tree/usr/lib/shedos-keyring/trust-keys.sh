#!/bin/bash
# Initialize pacman's master keyring (if needed) and locally sign every key
# listed in /usr/share/pacman/keyrings/shedos-trusted.
#
# Runs on first boot via shedos-keyring-trust.service (sentinel-gated) and
# can be re-run manually after a key rotation. Must stay idempotent — every
# action should be safe on a system that's already trusted the key.

set -u

KEYRING=/usr/share/pacman/keyrings/shedos.gpg
TRUSTED=/usr/share/pacman/keyrings/shedos-trusted
SENTINEL_DIR=/var/lib/shedos-keyring
SENTINEL=$SENTINEL_DIR/trusted

if [[ ! -f $KEYRING || ! -f $TRUSTED ]]; then
    echo "shedos-keyring: keyring files missing ($KEYRING / $TRUSTED)" >&2
    exit 0
fi

# pacman-key --lsign-key needs the LOCAL master key to exist. In a fresh
# chroot or a system where nothing has initialized the keyring yet, --lsign
# silently no-ops. Running --init first is idempotent.
if ! pacman-key --list-keys >/dev/null 2>&1; then
    pacman-key --init
fi

# archlinux-keyring's own post_install only --populate's if --init already
# worked. If we just ran --init above, we also need to populate the arch
# trust chain so core/extra stay verifiable.
pacman-key --populate archlinux 2>/dev/null || true

pacman-key --add "$KEYRING" >/dev/null

# One fingerprint per line, comments allowed with #.
while IFS= read -r fp; do
    [[ -z $fp || $fp == \#* ]] && continue
    pacman-key --lsign-key "$fp" >/dev/null || {
        echo "shedos-keyring: --lsign-key $fp failed" >&2
        exit 1
    }
done < "$TRUSTED"

install -d -m 755 "$SENTINEL_DIR"
# Record the fingerprint(s) we signed so a future key rotation can detect
# the sentinel is stale and re-trust without manual intervention.
awk 'NF && $1 !~ /^#/' "$TRUSTED" > "$SENTINEL"
