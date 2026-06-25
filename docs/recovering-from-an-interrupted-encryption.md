# Recovering from an interrupted in-place encryption

`shedman encrypt` rewrites the disk offline, across a reboot, while nothing is
mounted. That rewrite can take a while, and the one real risk is losing power
part-way through. This is what happens when that occurs, and how to finish.

## The short version

Almost always, you just turn the machine back on. The rewrite is resumable: the
LUKS header records how far it got, and the next boot continues from there. It
stops at the normal disk passphrase prompt — type your passphrase and it picks the
rewrite back up. Do not power off again until it finishes.

Once you reach the desktop, `sudo shedman encrypt --status` confirms where it
landed.

## What it looks like

You armed the encryption, the machine rebooted, and power was lost (or it crashed)
while it was rewriting the disk. On the next boot you may see it resume the
encryption, or stop at a passphrase prompt, or — rarely — fail to come up far
enough to continue on its own.

## Why it's usually fine

Where the power cut lands decides what you do, and none of the cases lose your
data on their own:

- **Before the header was written** (still shrinking the filesystem): the disk is
  not yet encrypted, btrfs never leaves a half-shrunk filesystem, and the old
  unencrypted boot still works. Re-run `shedman encrypt`, or leave it as it was.
- **During the rewrite** (the disk is already LUKS): the header carries the
  progress. The next boot detects the in-progress rewrite and resumes it after you
  enter the passphrase. It is *auto-detected, not unattended* — it waits at the
  passphrase prompt, it does not continue on its own.
- **After the rewrite, before the recovery key was enrolled**: the disk is
  encrypted and boots; the recovery-key step is not a boot step and simply re-runs.

## If it won't resume on its own

A machine that can't boot far enough to continue is recovered from a ShedOS live
USB. Boot the USB, then unlock and resume the rewrite by hand:

```
# Find the root partition (the large LUKS one), e.g. /dev/nvme0n1p2 or /dev/sda2:
lsblk -f

# Unlocking it triggers the resume machinery:
sudo cryptsetup open /dev/<root-partition> recover

# Continue the rewrite from where it stopped:
sudo cryptsetup reencrypt --resume-only /dev/<root-partition>
```

When it completes, reboot into the installed system normally.

If `cryptsetup open` reports damaged metadata, repair the header first, then
resume:

```
sudo cryptsetup repair /dev/<root-partition>
sudo cryptsetup reencrypt --resume-only /dev/<root-partition>
```

## What not to do

- Don't power off mid-rewrite once it has started, if you can avoid it — each
  interruption just makes you resume again.
- Don't run `shedman encrypt` a second time on a disk that is already LUKS. The
  way forward on a started conversion is to resume it (above), never to start
  over. `sudo shedman encrypt --status` tells you which state you are in.

## See also

- *shedman-encrypt*(1) — the command and its options.
- `docs/boot-safety.md` — the full-disk-encryption and boot-recovery model.
- `docs/recovering-a-full-esp.md` — a different boot failure, on the EFI partition.
