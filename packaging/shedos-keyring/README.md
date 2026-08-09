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

Rotation is a staged, dual-key operation — the full runbook lives at
[`docs/key-rotation.md`](../../docs/key-rotation.md). Short form:

1. Generate the new key offline; export only the public half.
2. `scripts/rotate-signing-key.sh <new.pub>` merges it into
   `tree/shedos.gpg` and appends the fingerprint to
   `tree/shedos-trusted` — both keys stay trusted. Also add the
   fingerprint to migrate's `SHEDOS_KEY_FPRS`.
3. Commit, push, release. The fleet re-trusts on upgrade (the
   `.install` sentinel re-fires `trust-keys.sh` when the list
   changes). CI still signs with the old key — its fingerprint is
   still listed, so the publish gate passes.
4. Only after the fleet has absorbed that: swap the GitHub signing
   secret. CI signs with the new key, which machines already trust.
5. A release later, remove the old key from both files and list its
   fingerprint in `tree/shedos-retired` — trust-keys.sh deletes retired
   keys from every machine's pacman keyring on the next upgrade.

Never overwrite `shedos.gpg` with a single new key in one step: the
repo database is re-signed immediately, and any machine that hasn't
absorbed the new trust first can no longer verify updates at all.

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
