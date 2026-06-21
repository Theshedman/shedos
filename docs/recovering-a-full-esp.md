# Recovering a box whose ESP filled up

## What it looks like

The machine stops booting the default kernel. You see one of:

- Limine prints `PANIC: fread: attempted out of bounds read` and stops at
  the menu.
- The kernel starts but panics with `VFS: Unable to mount root fs on
  unknown-block(0,0)`.

Booting an older entry (the shedos-kernel, or a fallback) may still work.

## Why it happens

Limine reads only FAT, so each kernel's signed boot image — a UKI bundling
the kernel, initramfs, and cmdline in one file — lives on the EFI System
Partition, a small FAT volume, not on the btrfs `/boot`.
On installs from before the firmware-slim fix, the initramfs carried
~145 MiB of GPU firmware, and during the shedos-kernel → linux-zen
migration both kernels' images had to fit at once. On a 512 MiB ESP they
didn't, and the old sync truncated them silently. A truncated initramfs is
an unbootable kernel.

The fix removes the GPU firmware from the initramfs (the `kms` hook), makes
the sync refuse-and-shout instead of truncating, and reaps a retired
kernel's images so the space comes back. New installs also get a 1 GiB ESP.
Once a box has that shedos-system, this can't recur.

## Recovering an affected box

If it still boots *any* entry, the simplest fix is to update in place —
`shedman update` pulls the new shedos-system, which drops `kms`, rebuilds
both kernels slim, and re-syncs the ESP. Reboot into linux-zen afterwards.

If it boots nothing, recover from the live USB:

1. Boot the ShedOS live ISO and open a terminal.
2. Mount the root and the ESP, then chroot in. The root is the `@` subvol;
   the ESP is the FAT partition (the small one):

   ```
   mount -o subvol=@ /dev/sdaN /mnt
   mount /dev/sda1 /mnt/boot/efi
   arch-chroot /mnt
   ```

3. Update shedos-system so the slim-initramfs fix is present:

   ```
   pacman -Syu
   ```

4. Run the recovery helper. It prunes UKIs for retired kernels, rebuilds
   and re-signs every live kernel's signed boot image (UKI), and verifies
   each one before it reports success:

   ```
   /usr/lib/shedos/recover-esp.sh
   ```

5. Exit the chroot and reboot. Pick **ShedOS Linux** (linux-zen) at the
   menu and confirm it reaches the desktop.

Once linux-zen boots cleanly you can retire the old kernel to free its
space for good — `shedman` will do this on its own on the next boots, or
remove `shedos-kernel` by hand.

## If recover-esp.sh still refuses

It prints which image wouldn't fit. That only happens if the ESP is too
small even for the slim images — e.g. a hand-partitioned install reusing a
100 MiB Windows ESP. Free space by removing a kernel you don't need, or
reinstall with the default 1 GiB ESP.
