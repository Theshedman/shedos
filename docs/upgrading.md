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

## The conflict indicator

Next to the updates badge, waybar shows a warning triangle with a count
any time `.shedosnew` files are sitting unresolved under `$HOME`. These
are upstream versions of dotfiles you've also edited locally — the config
sync tool won't clobber your edits, so it leaves them for you to reconcile.

- Empty → no unresolved conflicts.
- ` N` → `N` conflicts waiting. Tooltip reminds you to open
  `shedos-review-configs`.
- Click → opens a kitty window running `shedos-review-configs`.

The count is driven by `shedos-check-conflicts`. It's refreshed at three
known touchpoints: after `shedos-sync-configs` finishes, after
`shedos-review-configs` saves a merge, and at the end of `shedos-update`.
A mako notification also fires the first time the count climbs — same
"silent unless the number went up" semantics as the updates notifier.

## Desktop notifications

The same hourly check also fires a mako notification the first time new
updates land — so you find out even when waybar is off-screen or on another
workspace.

- Fires on the transition from 0 → N, and again when the count goes **up**.
- Does **not** re-fire for the same count you've already been told about.
- Count drops to 0 (e.g. you just ran `shedos-update`) → the "already
  notified" marker resets, so the next fresh batch notifies you again.
- Quiet channels: notifications are skipped on TTY logins, SSH sessions,
  and any environment without a DBus session. Mako DND mode (`makoctl
  mode dnd`) also silences them.

State lives at `$XDG_STATE_HOME/shedos/last-notified-count` (one integer).
If you want to force a re-notification at the next tick, run
`shedos-check-updates --reset-notify-state`.

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

### Unattended mode: `--yes`

For cron- or timer-driven upgrades on trusted systems:

```bash
shedos-update --yes
```

`--yes` skips every prompt and threads `--noconfirm` into pacman, yay,
and `shedos-sync-configs`. **But it does not auto-resolve config
conflicts** — a conflict means you *and* upstream edited the same file,
and silently picking a side is exactly the data loss the sync tool
exists to prevent. Conflicts in `--yes` mode still produce `.shedosnew`
files for you to reconcile later. Run `find ~ -name '*.shedosnew'` on
whatever schedule suits you.

Recommended wrapper for a user-scope systemd timer or cron:

```bash
# logs to journal via systemd-cat
shedos-update --yes 2>&1 | systemd-cat -t shedos-update
```

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

After an upgrade that produced conflicts, `shedos-update` offers:

```
3 config conflict(s) remain. Review now with shedos-review-configs? [Y/n]
```

Answering `Y` (or just Enter) launches `shedos-review-configs`, a
full-screen TUI that handles every conflict in one sitting. It's the
recommended path.

#### `shedos-review-configs` (IDE-style merge TUI)

- **File list** — one row per `.shedosnew`, with conflict kind (text /
  binary / symlink / orphan), hunk count, size, and whether a BASE
  snapshot is available (3-way vs 2-way merge).
- **Merge screen** — three panes (YOURS ▸ BASE ▸ THEIRS) when a BASE is
  available, otherwise two. Diff colors follow git conventions (green
  additions, red deletions). A dot-strip at the bottom shows hunk
  decisions at a glance.
- **Per-hunk controls**:
  - `y` — take YOURS (keep your edit)
  - `t` — take THEIRS (accept upstream)
  - `b` — take BOTH, YOURS first then THEIRS
  - `B` — take BOTH, THEIRS first then YOURS
  - `x` — skip this hunk (keep YOURS)
  - `u` — undo last decision
  - `n` / `p` — next / previous hunk
- **Whole-file shortcuts**:
  - `A` — take YOURS for every hunk
  - `Shift-T` — take THEIRS for every hunk
- **Save**:
  - `s` — write the merged result. YOURS is backed up to `.shedosbak`,
    the `.shedosnew` is removed, and the manifest is advanced. Atomic:
    a crash mid-save cannot corrupt the live file.
- **Quit**:
  - `q` — save a draft and return to the file list. Re-running the tool
    resumes where you left off, as long as none of the underlying files
    changed under it.

Hunks where only one side changed are pre-marked (YOURS-only ▸ YOURS,
THEIRS-only ▸ THEIRS), so trivial conflicts collapse to a single `s`.
Only genuine both-sides-changed hunks require a user decision.

Binary files, symlinks, and orphans (`.shedosnew` with no live file) use
dedicated modals — the TUI never tries to line-merge things it can't.

#### Alternative: manual resolution

If you'd rather not use the TUI, the old flow still works:

- **Diff and merge by hand**:
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

After writing the manifest, it also scans `$HOME` for leftover
`.shedosnew` and `.shedosbak` files and reports them. Any `.shedosnew`
surviving past a `--rebuild-manifest` is, by definition, an unreviewed
upstream version — the tool points at them so they don't accumulate
silently. `.shedosbak` files are harmless rolling backups from past
auto-updates; clean them up whenever you like.

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
| `shedos-update --yes` | Unattended variant. Conflicts still produce `.shedosnew`, never overwrite. |
| `shedos-check-updates` | Waybar JSON emitter. Run manually with `--refresh-waybar` to force an immediate poll. |
| `shedos-sync-configs` | Print a plan and interactively apply 3-way merge. |
| `shedos-sync-configs --dry-run` | Print the plan, change nothing. |
| `shedos-sync-configs --yes` | Apply the plan without the interactive prompt (same conflict semantics). |
| `shedos-sync-configs --rebuild-manifest` | Reset last-seen state to current defaults. Use after manually resolving conflicts. Reports any leftover `.shedosnew`/`.shedosbak`. |
| `shedos-review-configs` | IDE-style merge TUI for `.shedosnew` conflicts. Per-hunk y/t/b/B/x/u, whole-file A/T, atomic save, draft/resume. |
| `shedos-review-configs --list` | Tab-separated machine-readable conflict list. |
| `shedos-review-configs --file PATH` | Open merge UI on one file (path relative to `$HOME`). |

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
