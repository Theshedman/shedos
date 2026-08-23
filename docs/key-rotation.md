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
the `shedos-trusted` the channel's own keyring package carries, and
refuses again unless the `shedos.gpg` in that same package holds
that key — the two lists it gates on are the pair the fleet
installs, so they cannot drift apart. Both gates run before anything
is signed, and they run on every publish in the org: a keyring whose
`shedos-trusted` gains a fingerprint its `shedos.gpg` does not carry
stops every package repository from publishing, not just this one.

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
   `packaging/shedos-migrate-to-packaged/tree/usr/libexec/shedman/migrate`,
   and to `KEY_FPRS` in `shedos-org/shedos-ci`'s
   `scripts/enable-shedos-channels.sh` together with the copy its
   `test/pipeline/run.sh` pins. Every package repository's build and
   test containers verify the channel through that list, so a rotation
   that skips it stops CI across the whole org rather than one repo.
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

Before touching the secret, check that the keyring package the
channel serves already carries the new fingerprint — the gate reads
that package, not the commit. Phase 1's push publishes it, so this
is a confirmation rather than a step, but it is the one to make.

Replace the `SHEDOS_REPO_SIGNING_KEY` GitHub secret with the new
secret key. The next CI run signs everything with the new key; the
fingerprint gate passes because the published keyring already lists
it. The repo database and all new packages now carry new-key
signatures, which the fleet already trusts.

Swapping the secret before the new keyring reaches the channel takes
every package repository in the org down: each publish is refused at
the fingerprint gate, and publishing a fixed keyring is itself a
publish, so there is no way forward through it. Put the old secret
back, let phase 1 finish, and swap again.

The R2 bucket also serves `shedos.gpg` at the root (the migrate
bootstrap fetches it). Every publish rewrites it from the keyring
package the channel already holds, so it refreshes when a new
keyring is published, not when one is committed.

## Phase 3 — retire the old key (window closes)

After every supported machine has had a realistic chance to upgrade
(suggested: the next stable release after phase 2):

1. Remove the old fingerprint from `shedos-trusted` and the old key
   from `shedos.gpg` (re-export without it, same scratch-GNUPGHOME
   technique as the rotation script), and add the fingerprint to
   `shedos-retired`.
2. Remove it from `SHEDOS_KEY_FPRS` in migrate and from `KEY_FPRS` in
   shedos-ci, its harness copy included.
3. Commit, push, release. trust-keys re-runs everywhere and deletes
   every `shedos-retired` fingerprint from pacman's keyring, so the
   old key stops verifying as machines upgrade. Re-trusting alone
   never removes a key; the retired list is what closes the window.

CI's drift check compares two of the anchor lists to each other —
`shedos-trusted` against migrate's `SHEDOS_KEY_FPRS` — and never to
the key that is signing the channel right now. It cannot see shedos-ci's
`KEY_FPRS` at all, which lives in another repository. It goes green on two
lists that agree on a key nothing signs with, which is exactly the
state a retirement can leave behind. Only the publish gates compare
an anchor to the live signer, and they do it when the next publish
runs, so read the signing secret's fingerprint and check it against
both files by hand before pushing this step.

## Once the keyring has its own repository

The phases above name paths in this repository, which is where the
keyring and the migrate verb both still ship from. After the
multi-repo cutover they sit in `shedos-org/shedos-keyring` and
`shedos-org/shedos-migrate`, so the anchors can no longer move in
one commit. shedos-ci's list is already in that position.

The order is decided by migrate: it refuses a downloaded keyring
holding any key its `SHEDOS_KEY_FPRS` does not list, and every
publish refreshes the `shedos.gpg` the channel serves. That list has
to stay a superset of the published keyring, which means the migrate
change leads an addition and trails a retirement.

Both of the publisher's own trust inputs come out of that published
package, so the keyring repository's push is what moves them. A
fingerprint that is committed there but not yet published gates
nothing.

1. Phase 1: push migrate's new fingerprint and shedos-ci's, then the
   keyring repository with `shedos.gpg` and `shedos-trusted` together. The
   stable release and the wait are unchanged, and phase 2 still
   swaps the signer only once the fleet has absorbed it.
2. Phase 3: push the keyring's removal first and migrate's and
   shedos-ci's last, so neither list drops a key the channel is still
   serving.

Between the two pushes the anchors really do disagree, and the drift
check in `shedos-org/shedos-release` says so. That red is expected and
the second push clears it. It is an alarm rather than a gate — the
publisher runs off a repository dispatch, not off that repo's CI —
and reverting the first push to quiet it puts the refusal back.

## Drill

The release soak includes a rotation drill: run phases 1–2 against a
throwaway key in a VM tracking the test channel, confirm the VM
updates cleanly across the signer swap, then revert the staging
commits. Never practice on the production secret.
