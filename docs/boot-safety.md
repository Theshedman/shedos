# Boot safety

ShedOS treats "the machine still boots" as non-negotiable. A few mechanisms
keep a missing disk, a corrupt ESP, or a bad fstab line from locking you out
of your own system. Here is what they are and what to do when one fires.

## The failure they prevent

A non-root mount in `/etc/fstab` without `nofail` is a trap: if that disk is
ever missing at boot — unplugged, dead, renumbered — systemd can't satisfy
`local-fs.target`, and the boot drops to emergency mode. On a stock Arch box
that lands you at a root shell; on ShedOS the root account is locked, so for
a long time that was a dead end you couldn't type your way out of.

## Prevention: apply and the installer

- The installer and `shedman apply` write every managed non-root mount with
  `nofail` and a short device-timeout, so a missing disk is skipped instead
  of fatal. Mark a mount `required = true` in `system.toml` to opt a specific
  one back into "must be present to boot".
- New installs get the ESP (`/boot/efi`) with `nofail` too — a corrupt ESP
  can't strand a fresh box.

## Detection: shedman doctor

- `shedman doctor` audits `/etc/fstab` for hand-added non-root mounts that
  still lack `nofail` and could wedge boot. `sudo shedman doctor --fix-mounts`
  adds it, with a confirmation and a timestamped backup.
- After boot, if a `nofail` disk was missing and got skipped, doctor reports
  it ("a disk did not mount this boot") and a critical notification fires, so
  a silently-absent disk doesn't stay invisible.

## Recovery: the guided emergency screen

If a box does drop to emergency mode over a missing-disk mount, ShedOS no
longer leaves you at an unusable password prompt. The guided screen names the
mount that stopped boot and offers:

    [f] make optional and continue   [s] root shell   [r] reboot

Pressing `f` adds `nofail` to the offending mount (backing up fstab first)
and continues the boot. A mount you marked `required = true` is never touched
— if its disk is gone, stopping is the intended behaviour, and `[s]` gives
you a shell to fix it by hand.

## Doing it by hand

From the emergency shell:

    journalctl -xb            # see what failed
    mount -o remount,rw /     # make root writable
    nano /etc/fstab           # add `nofail` to the offending line, or remove it
    systemctl daemon-reload
    systemctl default         # continue boot

## What the snapshot rollback can't do

ShedOS auto-rolls-back to the last good snapshot after three failed boots.
That recovers a broken update — but it cannot recover an fstab emergency,
because every snapshot carries the same `/etc/fstab`. The bad mount line is
in the snapshot too, so rolling back lands you in the same emergency. That is
exactly the gap the guided screen and the doctor audit close.

## Secure Boot and full-disk encryption

Encryption and Secure Boot add their own ways to be stopped at boot. All of
them are recoverable, and the defaults are chosen so you can't lock yourself
out by accident.

- **The encrypted disk asks for a passphrase.** A fresh encrypted install
  prompts for it every boot. If you forget it, the recovery key shown at
  install time unlocks the disk — keep it somewhere off the machine.
- **Passwordless unlock falls back, it never locks out.** After
  `sudo shedman tpm2 enroll` the disk opens with nothing typed on a trusted
  boot. If the boot chain changes — a firmware update, a kernel the TPM hasn't
  measured — the TPM declines and you type the passphrase instead. The
  passphrase and recovery key are never removed. The passwordless-versus-PIN
  tradeoff is in `shedman-tpm2`(1).
- **Secure Boot rejects unsigned media.** Once you run
  `sudo shedman secureboot enroll`, firmware refuses to boot anything this box
  hasn't signed, including a stock install USB. To boot rescue media, turn
  Secure Boot off in firmware setup (or run `shedman secureboot disable`),
  recover, then re-enroll. The signed recovery entry in the boot menu still
  works under Secure Boot, but it unlocks the disk with the passphrase, not
  the TPM.
- **enroll only runs in Setup Mode.** `secureboot enroll` refuses unless you
  have first cleared the platform keys in firmware setup. That is deliberate:
  a box boots its unsigned images fine until you opt in, so enrollment can
  never silently strand you. See `shedman-secureboot`(1).

The recovery paths above are unaffected by Secure Boot: the snapshot
auto-rollback boots a signed snapshot, and the guided emergency screen runs
from the signed initramfs, so both still work with Secure Boot on.
