#!/usr/bin/env bash
# rotate-ceremony.sh; generate a NEW ShedOS signing key for rotation.
#
# Run this yourself, on a trusted machine. Unlike key-ceremony.sh
# (initial generation), this NEVER touches the committed trust files —
# the new public key is merged into the keyring later by
# scripts/rotate-signing-key.sh, which keeps the old key trusted for
# the dual-key window. See docs/key-rotation.md.
#
# This ceremony refuses to finish until the new private key is backed
# up to TWO destinations and both copies verify. That guard exists
# because the previous key was lost to a single un-backed-up copy.
#
# Outputs (to a directory OUTSIDE the repo so they can't be committed):
#   shedos-new.pub            public key  → hand to the staging step
#   <backup1>/shedos-rotation-<fpr>.asc   private key (verified copy)
#   <backup2>/shedos-rotation-<fpr>.asc   private key (verified copy)
#
# Key parameters match the original: RSA 4096, no passphrase (CI signs
# non-interactively), no expiry.

set -euo pipefail

echo "ShedOS signing-key rotation ceremony"
echo "This generates a NEW key. The old key stays trusted until you"
echo "retire it (docs/key-rotation.md, phase 3)."
echo

out=${1:-}
if [[ -z $out ]]; then
    read -r -p "Working directory for outputs (outside the repo) [~/shedos-rotation]: " out
    out=${out:-$HOME/shedos-rotation}
fi
mkdir -p "$out"
case $(realpath "$out") in
    "$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel 2>/dev/null)"/*)
        echo "Refusing: $out is inside the repo. Choose a path outside it." >&2
        exit 2 ;;
esac

tmpgpg=$(mktemp -d)
trap 'rm -rf "$tmpgpg"' EXIT
export GNUPGHOME=$tmpgpg
chmod 700 "$tmpgpg"

cat > "$tmpgpg/keyparams" <<'EOF'
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
[[ ${#fp} -eq 40 ]] || { echo "unexpected fingerprint: $fp" >&2; exit 3; }
echo "New fingerprint: $fp"

# Public half — safe to hand off.
gpg --export repo@shedos.org > "$out/shedos-new.pub"

# Private half — staged in the throwaway home, then copied to two
# backups with verification before the working copy is destroyed.
priv=$tmpgpg/shedos-rotation-$fp.asc
gpg --armor --export-secret-keys repo@shedos.org > "$priv"

_verify_copy() {
    # Re-import the copy into a scratch keyring and confirm the
    # fingerprint round-trips — proves the backup is a usable key,
    # not a truncated/corrupt file.
    local f=$1 scratch got
    scratch=$(mktemp -d); chmod 700 "$scratch"
    got=$(GNUPGHOME=$scratch gpg --import "$f" 2>/dev/null; \
          GNUPGHOME=$scratch gpg --list-secret-keys --with-colons 2>/dev/null \
          | awk -F: '/^fpr:/ {print $10; exit}')
    rm -rf "$scratch"
    [[ $got == "$fp" ]]
}

backups=()
for n in 1 2; do
    while :; do
        read -r -p "Backup destination $n (a mounted USB or a dir on a SEPARATE machine): " dest
        [[ -n $dest ]] || { echo "  required."; continue; }
        mkdir -p "$dest" 2>/dev/null || { echo "  cannot create $dest"; continue; }
        target=$dest/shedos-rotation-$fp.asc
        install -m600 "$priv" "$target"
        if _verify_copy "$target"; then
            echo "  ✓ verified backup at $target"
            backups+=("$target")
            break
        else
            echo "  ✗ copy at $target did not verify; try another destination."
            rm -f "$target"
        fi
    done
done

# Distinct destinations only — two copies on one stick isn't two backups.
if [[ "$(realpath "$(dirname "${backups[0]}")")" == \
      "$(realpath "$(dirname "${backups[1]}")")" ]]; then
    echo "Both backups are in the same directory. That is one backup." >&2
    echo "Re-run and give two SEPARATE destinations." >&2
    exit 2
fi

# Record the fingerprint alongside each backup (paper-equivalent).
for b in "${backups[@]}"; do
    printf '%s  ShedOS repo signing key\n' "$fp" > "${b%.asc}.fingerprint.txt"
done

shred -u "$priv" 2>/dev/null || rm -f "$priv"

cat <<EOF

Done. Two verified backups of the new private key exist:
  ${backups[0]}
  ${backups[1]}

Next, in order (do NOT swap the GitHub secret yet — that is phase 2):
  1. Hand the PUBLIC key to the staging step:
       $out/shedos-new.pub
  2. Keep the private backups offline and unplugged.
  3. When told (after the fleet trusts both keys), paste the armored
     private key from a backup into GitHub → repo Settings → Secrets →
     SHEDOS_REPO_SIGNING_KEY. Upload from the backup, never from here.

Full procedure: docs/key-rotation.md
EOF
