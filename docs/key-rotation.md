# Signing-key rotation

How to rotate the ShedOS package-signing key without ever leaving a
machine unable to verify updates. The design is a staged dual-key
window: ship trust in the new key first, sign with it second, retire
the old key last.

Every machine learns new trust through the `shedos-keyring` package:
`shedos.gpg` (the keys) plus `shedos-trusted` (the fingerprints to
locally sign). `trust-keys.sh` lsigns every listed fingerprint on
upgrade and at boot, and the sentinel comparison in
`shedos-keyring.install` re-fires it whenever the list changes. CI
refuses to publish unless its signing key's fingerprint appears in
the committed `shedos-trusted`.

## Phase 0 — generate (offline)

Generate the new key on the offline machine (see `docs/ops-runbook.md`
for storage discipline). Export only the public half:

    gpg --export --armor <NEW_FPR> > shedos-new.pub

The secret key never enters the repo, CI logs, or any online machine
other than the GitHub secret in phase 2.

## Phase 1 — ship trust (dual-key window opens)

    scripts/rotate-signing-key.sh shedos-new.pub

This merges the public key into `shedos.gpg` and appends the
fingerprint to `shedos-trusted`. Then:

1. Add the new fingerprint to `SHEDOS_KEY_FPRS` in
   `packaging/shedos-migrate-to-packaged/tree/usr/libexec/shedman/migrate`.
2. Commit through the normal gates and push. CI still signs with the
   OLD key — its fingerprint is still listed, so the gate passes.
3. Ship a release (or let the fleet pick the keyring up from the
   stable channel). Every machine that upgrades now trusts BOTH keys.

Wait for the fleet to absorb this — at minimum one full stable
release cycle, because **stable-tracking machines only receive the
dual-trust keyring through a stable release** (pushes to main land
on /test alone). Concretely: phase 1 → cut the next rc + stable
normally (still old-key-signed) → stable machines absorb both keys
via a regular `shedman update` → only then phase 2.

A machine that misses the window does NOT converge on its own:
pacman verifies the repo *database* signature before it can see any
package, so an unknown signer means the whole [shedos] repo is
refused — the keyring upgrade cannot ride through. Recovery is
manual (`pacman -U` the keyring package by URL, or pacman-key --add
the published shedos.gpg). That is the failure phase 1's patience
exists to prevent.

## Phase 2 — swap the signer

Replace the `SHEDOS_REPO_SIGNING_KEY` GitHub secret with the new
secret key. The next CI run signs everything with the new key; the
fingerprint gate passes because phase 1 committed it. The repo
database and all new packages now carry new-key signatures, which
the fleet already trusts.

The R2 bucket also serves `shedos.gpg` at the root (the migrate
bootstrap fetches it); CI publishes the committed keyring on every
push, so phase 1 already refreshed it.

## Phase 3 — retire the old key (window closes)

After every supported machine has had a realistic chance to upgrade
(suggested: the next stable release after phase 2):

1. Remove the old fingerprint from `shedos-trusted` and the old key
   from `shedos.gpg` (re-export without it, same scratch-GNUPGHOME
   technique as the rotation script).
2. Remove it from `SHEDOS_KEY_FPRS` in migrate.
3. Commit, push, release. The sentinel mismatch re-runs trust-keys
   everywhere; the old key stops being honored as machines upgrade.

## Drill

The release soak includes a rotation drill: run phases 1–2 against a
throwaway key in a VM tracking the test channel, confirm the VM
updates cleanly across the signer swap, then revert the staging
commits. Never practice on the production secret.
