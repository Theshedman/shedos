# Upgrading an installed ShedOS system

ShedOS is a **rolling release**. Once you install from an ISO, you never
need to reinstall to move to a newer release — `pacman -Syu` pulls signed
updates directly from `https://repo.shedos.org`.

This doc walks through the upgrade experience: how you're notified,
what happens when you accept an update, and how the system protects your
dotfiles.

## TL;DR

1. Waybar shows `󰚰 N` when `N` updates are waiting.
2. Click it (or run `shedos-update` in a terminal).
3. Review the list, type `y`.
4. Pacman and yay prompt again with their own lists — type `y` once more each.
5. `shedos-sync-configs` prints a plan for any ShedOS dotfile changes. Review, type `y`.
6. Done. Any file you had personally edited is untouched; upstream's version is sitting next to it as `<file>.shedosnew`.

Nothing is ever applied without an explicit `y`.

## The waybar indicator

`shedos-check-updates` runs in the background (user-scope systemd timer,
hourly). It uses pacman's `checkupdates` tool against a sandboxed temp DB —
safe to run as your user, doesn't race with pacman's own transactions.

The waybar module:

- `󰚰 0` / empty → system is up to date.
- `󰚰 N` → `N` pacman + AUR updates available. Tooltip lists the first few.
- Click → opens a kitty window running `shedos-update`.

After a successful upgrade, `shedos-update` signals waybar to refresh
immediately so you don't wait up to an hour for the icon to clear.

## `shedos-update` (interactive)

```
------------------------------------------------------------
ShedOS update
------------------------------------------------------------
Checking for pacman updates…
Checking for AUR updates…

Pacman updates (3):
  firefox 125.0-1 -> 126.0-1
  linux 6.8.7.arch1-1 -> 6.8.8.arch1-1
  shedos-hyprland 2026.04.21-1 -> 2026.04.28-1

AUR updates (1):
  yay 12.3.5-1 -> 12.4.0-1

Proceed with upgrade? [y/N]
```

- **Default is N.** Just pressing Enter cancels.
- On `y`, `pacman -Syu` runs next. Pacman **prompts again** with the full
  list. You're confirming twice on purpose — once that you want to start,
  and once with pacman's own transaction view so you can still back out
  after seeing the real package set (including dependency pulls).
- If AUR updates exist and `yay` is installed, it runs `yay -Sua` after
  pacman. Yay prompts again too.
- Finally, `shedos-sync-configs` runs to reconcile `$HOME` dotfiles.

The script never uses `--noconfirm`. If you want unattended upgrades,
that's a future opt-in flag (not available yet).

## `shedos-sync-configs` (dotfile 3-way merge)

This is the part most distros get wrong. Pacman does not touch user
home directories — everything in `$HOME` is ShedOS's responsibility.

### Three states per file

For every file ShedOS ships under `/etc/skel` (via `shedos-hyprland`,
`shedos-nvim`, …), there are three things to track:

| State | Where | Owner |
|---|---|---|
| Pristine default | `/usr/share/shedos/<pkg>/defaults/<relpath>` | pacman (updated on package upgrade) |
| Your live copy | `$HOME/<relpath>` | you |
| Last-seen hash | `$XDG_STATE_HOME/shedos/last-seen/<relpath>.sha256` | `shedos-sync-configs` |

### The four cases

Per-file, after comparing those three:

| Case | Condition | Action |
|---|---|---|
| **seed** | No `$HOME` copy yet | Copy default → `$HOME`, record hash. |
| **noop** | Upstream hasn't changed since last sync | Do nothing. |
| **auto** | You haven't edited the file since last sync | Back up `→ .shedosbak`, write new default, update hash. |
| **conflict** | Both you and upstream changed the file | Drop `<file>.shedosnew` alongside, **don't touch your copy**, **don't** update hash. |

Properties that fall out:

- A file you edited is never overwritten. The only write to your live
  copy is in the `auto` case, which requires byte-identical match with
  the last recorded hash.
- On `conflict`, the hash is intentionally *not* updated — the next sync
  will re-offer the same resolution until you resolve it.
- If the state directory is ever lost, every file looks "modified" and
  drops a `.shedosnew`. Worst case is noise, never data loss.

### Resolving a `.shedosnew`

After an upgrade that produced conflicts, you'll see:

```
Sync complete. Conflicts (if any) landed as <path>.shedosnew alongside
your files — inspect with: find ~ -name '*.shedosnew'
```

To resolve each one, pick one of:

- **Diff and merge by hand** (most common):
  ```bash
  diff -u ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.shedosnew
  # edit the live file to taste, then:
  rm ~/.config/hypr/hyprland.conf.shedosnew
  shedos-sync-configs --rebuild-manifest  # mark as aligned
  ```
- **Take upstream**:
  ```bash
  mv ~/.config/hypr/hyprland.conf.shedosnew ~/.config/hypr/hyprland.conf
  shedos-sync-configs --rebuild-manifest
  ```
- **Keep yours, ignore upstream**:
  ```bash
  rm ~/.config/hypr/hyprland.conf.shedosnew
  shedos-sync-configs --rebuild-manifest
  ```

`--rebuild-manifest` tells the sync tool "trust me, my current files are
aligned with the current defaults." It hashes each default and writes it
as the new last-seen entry. It does *not* copy any files.

### Why `shedos-nvim` behaves differently

Neovim lua configs are small, personal, and a bad auto-merge can break
the editor on next launch. So `shedos-nvim` ships a policy file
(`/usr/share/shedos/shedos-nvim/sync-policy` containing
`always-conflict`) that promotes the **auto** case to **conflict** for
every file it owns. Even files you haven't touched drop `.shedosnew`
instead of auto-updating. You'll be pasting more often, but you'll
never wake up to a broken editor.

## Commands reference

| Command | Purpose |
|---|---|
| `shedos-update` | Interactive upgrade flow (pacman + yay + config sync). |
| `shedos-check-updates` | Waybar JSON emitter. Run manually with `--refresh-waybar` to force an immediate poll. |
| `shedos-sync-configs` | Print a plan and interactively apply 3-way merge. |
| `shedos-sync-configs --dry-run` | Print the plan, change nothing. |
| `shedos-sync-configs --rebuild-manifest` | Reset last-seen state to current defaults. Use after manually resolving conflicts. |

## What about kernel upgrades?

Kernel updates arrive via regular `pacman -Syu` (Arch ships them in the
`core` repo). After a kernel upgrade, reboot when convenient — the old
kernel is still available via the boot menu until `mkinitcpio` replaces
it, which happens automatically on the next upgrade.

## FAQ

**Does `shedos-update` modify my system without asking?** No. Every
destructive step has a `y/N` gate (default N). Pacman and yay re-prompt
with their own package lists.

**Can I skip the config sync?** Yes — press `N` at the sync prompt.
Packages stay upgraded; your dotfiles aren't touched. You can run
`shedos-sync-configs` later whenever you're ready.

**I deleted my `$XDG_STATE_HOME/shedos/` directory. Am I stuck with
conflicts forever?** Run `shedos-sync-configs --rebuild-manifest`.

**I want to opt out of ShedOS-managed dotfiles entirely for some file.**
Delete the `$HOME` copy and the state entry:
```bash
rm ~/.config/<app>/<file>
rm ~/.local/state/shedos/last-seen/.config/<app>/<file>.sha256
```
Next sync will treat the file as excluded-by-absence (no `$HOME` copy →
seed case). If you want to *never* regenerate it, add a matcher to
`$HOME/.config/shedos/sync-exclude` (future feature — file-level opt-out
is a Phase 2 item).

**Do I need to trust a new key to install updates?** No — the repo key
lives in `shedos-keyring`, which is itself part of every ShedOS install
and gets updated through the same signed channel. Key rotation is a
no-touch event for you.
