# shedos-keyring

The trust anchor for `[shedos]`. Every other ShedOS package is signed against
this key; losing it means every installed system stops accepting upgrades
until the new key is manually trusted.

## First-time setup (run once, offline, before the first release)

```
cd packaging/shedos-keyring
./scripts/key-ceremony.sh
```

The script:
1. Creates a throwaway `$GNUPGHOME` (doesn't touch your personal keyring).
2. Generates a 4096-bit RSA signing key with no passphrase and no expiry.
3. Writes `tree/shedos.gpg` (public, to be committed).
4. Writes `tree/shedos-trusted` (fingerprint list, to be committed).
5. Writes `./shedos-private.asc` (private, **must not** be committed).

Then:
1. Paste `shedos-private.asc` contents into the GitHub secret
   `SHEDOS_REPO_SIGNING_KEY` (org- or repo-level).
2. `shred -u shedos-private.asc`.
3. `git add tree/shedos.gpg tree/shedos-trusted`.
4. Commit and push.

CI refuses to publish a repo signed with the placeholder key — the published
fingerprint must match the committed `tree/shedos-trusted`.

## Key rotation

Rotation is a deliberate operation:

1. Run `./scripts/key-ceremony.sh` again — this overwrites `tree/shedos.gpg`
   and `tree/shedos-trusted` with the new key.
2. Bump `pkgver` in the PKGBUILD.
3. Replace `SHEDOS_REPO_SIGNING_KEY` in GitHub secrets.
4. Commit + push. CI rebuilds the repo with the new key.
5. Existing installs receive the new `shedos-keyring` package on their next
   `pacman -Syu`; the `.install` scriptlet runs `pacman-key --lsign-key` on
   the new fingerprint. Old signatures continue to verify against the old
   key already in the user's keyring, so there is no flag-day.

## Why the fingerprint lives in a file, not hard-coded

The install scriptlet reads fingerprints from `shedos-trusted`, one per line.
This mirrors how `archlinux-keyring` ships its `.trusted` file. Rotation is a
single-file change — no scriptlet edits needed.

## How trust actually lands on a fresh install

Trust is split between two entry points:

1. **`.install` scriptlet.** Runs `trust-keys.sh` best-effort at install time.
   During a running-system upgrade the master keyring already exists, so
   `--lsign-key` succeeds immediately. During `pacstrap` the target chroot's
   master keyring may not be initialized yet — in that case the lsign is
   either a no-op (nothing to sign with) or creates a fresh master key in
   the pacstrap chroot. Either way, the scriptlet also enables the oneshot
   unit below so the first real boot picks up the slack.
2. **`shedos-keyring-trust.service`** (oneshot, sentinel-gated, enabled by
   the scriptlet). On first boot it calls `trust-keys.sh` which: initializes
   pacman's master keyring if missing, populates `archlinux`, adds
   `shedos.gpg`, and `--lsign`s every fingerprint in `shedos-trusted`.
   Writes `/var/lib/shedos-keyring/trusted` as a sentinel.

The sentinel file contains the fingerprints that have been signed. On key
rotation, `post_upgrade` detects that the shipped `shedos-trusted` no longer
matches the sentinel and deletes the sentinel, so the boot unit re-trusts on
next reboot without manual intervention.
