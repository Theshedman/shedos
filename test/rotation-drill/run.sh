#!/usr/bin/env bash
# test/rotation-drill/run.sh — offline signer-swap drill for the package-signing
# key rotation (docs/key-rotation.md, phase 2).
#
# It proves the one thing that can lock the fleet out of [shedos]: that while the
# keyring trusts BOTH the old and new signing keys (the dual-trust window opened
# by phase 1), a `pacman -Sy` stays clean across the moment CI swaps the repo
# signer from the old key to the new one — and that pacman still REFUSES a
# database signed by a key the keyring does not trust, so a green run is never
# vacuous.
#
# Everything runs in a scratch tmpdir against a file:// repo: it never touches
# the real SHEDOS_REPO_SIGNING_KEY secret, the R2 repo, or the system keyring.
# Run it before phase 2 to de-risk the real swap; never practise on production.
#
# Needs root — pacman-key --init and pacman -Sy both require it. SKIPs otherwise
# (like the cryptsetup e2e), so it runs locally and in a root CI job.
set -uo pipefail

for t in pacman pacman-key repo-add gpg bsdtar; do
    command -v "$t" >/dev/null 2>&1 || { echo "rotation-drill: SKIP (missing $t)"; exit 0; }
done
if [[ $(id -u) -ne 0 ]]; then
    echo "rotation-drill: SKIP (needs root: pacman-key --init and pacman -Sy)"
    exit 0
fi

pass=0 fail=0
_ok()   { echo "ok: $1"; pass=$((pass + 1)); }
_fail() { echo "FAIL: $1${2:+ — $2}"; fail=$((fail + 1)); }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

signgpg="$work/signing"                       # holds the throwaway private keys
pkdir="$work/keyring"                          # the pacman keyring under test
repo="$work/repo"                              # the file:// [drill] repo
mkdir -p "$signgpg" "$pkdir" "$repo" "$work/root" "$work/db" "$work/cache"
chmod 700 "$signgpg"
export GNUPGHOME="$signgpg"

# Three throwaway keys: A = current signer, B = the new signer (phase 2), C = an
# attacker/untrusted key. 2048-bit for test speed — the trust flow is key-size
# agnostic; the real ceremony uses 4096 (scripts/rotate-ceremony.sh).
_genkey() {
    gpg --batch --generate-key /dev/stdin >/dev/null 2>&1 <<EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Key-Usage: sign
Name-Real: drill-$1
Expire-Date: 0
%commit
EOF
    gpg --list-keys --with-colons "drill-$1" | awk -F: '/^fpr/{print $10; exit}'
}
fpr_a=$(_genkey A); fpr_b=$(_genkey B); fpr_c=$(_genkey C)
for who in a b c; do
    eval "fpr=\$fpr_$who"
    gpg --batch --yes --export --armor "$fpr" > "$work/key-$who.pub"
done

# A minimal package and a repo database over it. Fabricated by hand rather than
# built with makepkg — makepkg refuses to run as root and this harness must be
# root; repo-add only needs the package's .PKGINFO to index it.
mkdir -p "$work/pkgstage"
cat > "$work/pkgstage/.PKGINFO" <<'EOF'
pkgname = drill
pkgver = 1-1
pkgdesc = rotation-drill fixture
arch = any
size = 0
EOF
( cd "$work/pkgstage" && bsdtar --zstd -cf "$repo/drill-1-1-any.pkg.tar.zst" .PKGINFO )
( cd "$repo" && repo-add drill.db.tar.gz drill-1-1-any.pkg.tar.zst >/dev/null 2>&1 )

# The pacman keyring trusts A and B only — never C.
pacman-key --gpgdir "$pkdir" --init >/dev/null 2>&1
pacman-key --gpgdir "$pkdir" --add "$work/key-a.pub" "$work/key-b.pub" >/dev/null 2>&1
pacman-key --gpgdir "$pkdir" --lsign-key "$fpr_a" >/dev/null 2>&1
pacman-key --gpgdir "$pkdir" --lsign-key "$fpr_b" >/dev/null 2>&1

cat > "$work/pacman.conf" <<EOF
[options]
Architecture = auto
SigLevel = Required DatabaseRequired
[drill]
Server = file://$repo
EOF

# Detach-sign the database with the given key (the same bytes back both the
# repo.db symlink and repo.db.tar.gz, so one signature covers what pacman fetches).
_sign_db() {
    local fpr=$1
    rm -f "$repo"/drill.db.sig "$repo"/drill.db.tar.gz.sig
    gpg --batch --yes --detach-sign --no-armor -u "$fpr" \
        -o "$repo/drill.db.tar.gz.sig" "$repo/drill.db.tar.gz" 2>/dev/null
    cp "$repo/drill.db.tar.gz.sig" "$repo/drill.db.sig"
}

# Force a real re-fetch + re-verify every time (clear the synced copy first).
_sy() {
    rm -rf "$work/db/sync"
    pacman --config "$work/pacman.conf" --root "$work/root" --dbpath "$work/db" \
        --cachedir "$work/cache" --gpgdir "$pkdir" --logfile "$work/pacman.log" \
        -Syy --noconfirm >/dev/null 2>&1
}

# 1) Old key (A) signs the DB — pacman trusts it, sync is clean.
_sign_db "$fpr_a"
if _sy; then _ok D1_old_key_syncs_clean; else _fail D1_old_key_syncs_clean "pacman rejected an A-signed db"; fi

# 2) The phase-2 swap: the NEW key (B) now signs the DB. Because the keyring
#    already trusts B, the sync must stay clean — this is the whole point.
_sign_db "$fpr_b"
if _sy; then _ok D2_new_key_survives_swap; else _fail D2_new_key_survives_swap "pacman rejected a B-signed db across the swap"; fi

# 3) Negative control: an untrusted key (C) signs the DB — pacman MUST refuse the
#    whole repo, or the pass above proves nothing.
_sign_db "$fpr_c"
if _sy; then _fail D3_untrusted_key_refused "pacman accepted a db signed by an untrusted key"; else _ok D3_untrusted_key_refused; fi

echo "rotation-drill: $pass passed, $fail failed"
(( fail == 0 ))
