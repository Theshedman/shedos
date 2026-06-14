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
