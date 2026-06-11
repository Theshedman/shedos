# Ops runbook — actions that need account access

Infrastructure hardening that cannot be done from the repo. Each item
lists why it matters and the exact steps. Check items off here (with a
date) once executed.

## 1. R2 object versioning + lifecycle  — [ ]

The single `shedos-repo` bucket is the only copy of every published
package, db, and ISO. A bad `rclone sync`/`delete` (or a compromised
CI token) is currently unrecoverable.

1. Cloudflare dashboard → R2 → `shedos-repo` → Settings → enable
   **object versioning**.
2. Add a lifecycle rule: expire noncurrent versions after 90 days
   (bounds storage growth while keeping a three-month undo window).
3. Quarterly: spot-check that `rclone lsf --versions` shows history.

## 2. Offline signing-key backup  — [ ]

One passphrase-less repo signing key exists, held only as the
`SHEDOS_REPO_SIGNING_KEY` GitHub secret. If the secret is lost or the
account is compromised, every installed system stops trusting updates
(key rotation across the fleet is K2, deliberately deferred).

1. Export the private key from wherever the ceremony ran:
   `gpg --export-secret-keys --armor <fingerprint> > shedos-repo-key.asc`.
2. Store two offline copies (e.g. encrypted USB + paper/QR in a
   separate physical location). Never store it in the repo or any
   cloud drive.
3. Record the fingerprint and backup locations privately.

## 3. GitHub secret-scope review  — [ ]

`SHEDOS_ENV` holds the signing key and the R2 credentials. Confirm:
the environment is restricted to the `main` branch + tags; no
third-party app has actions read on the repo; R2 API token is scoped
to the `shedos-repo` bucket only (it is — the workflows rely on
`RCLONE_S3_NO_CHECK_BUCKET` because of it).

## Done already (repo-side, for context)

- GitHub Actions pinned by commit SHA (supply-chain; build workflows).
- Stable promotion only ships RC-soaked snapshots (`/rc/<tag>/`).
- ISO publication gated to tag builds (a branch dispatch can no longer
  evict a stable ISO from retention).
