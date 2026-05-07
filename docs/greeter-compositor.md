# Greeter compositor — cage today, labwc when needed

`greetd` runs `shedos-greeter` inside a Wayland compositor on a free
VT. Today that compositor is **cage**: a tiny single-window kiosk
compositor (~500 KB) built on wlroots. cage launches the greeter
fullscreen, captures keyboard + mouse, exits when the greeter exits.
For an authenticate-and-step-aside surface that's exactly enough.

Where cage starts to bite:

- It does not advertise `zwlr_layer_shell_v1`. The greeter falls
  back to `xdg_toplevel` and gets one window spanning all outputs.
  The Phase 12 fix works around that by computing a "primary rect"
  inside the spanned canvas, but the architecturally clean answer
  for multi-monitor is one layer surface per output.
- It does not advertise `xdg-decoration-manager`, `presentation-time`,
  or other niceties any "real" wlroots compositor exposes. Not a
  problem for the greeter today, but if we ever add features that
  need them we'd be stuck.

## Replacement candidate: labwc

`labwc` is a stacking wlroots compositor (~5 MB binary, ~1 MB on
disk after stripping). It supports the protocol set that the
wlroots ecosystem expects, including `wlr-layer-shell`. Configured
as a kiosk it can mimic cage's "one fullscreen client, no chrome"
behavior.

What switching would require:

- **`/etc/greetd/config.toml`**: replace
  `cage -s -- /usr/bin/shedos-greeter` with the labwc invocation,
  pointing at a stripped labwc config that auto-starts the greeter
  fullscreen and exits when it exits.
- **`/etc/labwc/`** (new): a minimal `rc.xml` (or whatever labwc's
  current format is) plus a `autostart` shipping `shedos-greeter`.
  Themes, keybindings, decoration — all stripped.
- **Greeter source**: replace the xdg-shell surface with one
  `zwlr_layer_surface_v1` per `wl_output`, with `keyboard
  interactivity = exclusive` so the password input always has
  focus. Removes the spanned-canvas + dim-rect workaround from
  Phase 12.
- **`packaging/shedos-greeter/PKGBUILD`**: add `labwc` to depends;
  drop `cage`. Update the comment block in `src/render.rs`
  describing the layer-shell migration.
- **Calamares fresh-install QEMU test**: confirm labwc starts on
  the live ISO without a `/etc/labwc/` from `/etc/skel`.

What it would buy us:

- One layer surface per output → real per-output rendering with
  no canvas-spanning hack. Each surface is the size of its output,
  so the dimming logic disappears entirely.
- Keyboard interactivity becomes a protocol-level property, not a
  cage-imposed behavior. We can mark non-primary surfaces as
  `keyboard interactivity = none` and primary as `exclusive`.
- Future-proofing for any greeter feature that needs a real
  compositor (notifications during greeter, password-reveal
  toggle, biometric handoff UI, etc.).

What it would cost:

- ~4 MB on the ISO (labwc binary + a few transitive libs already
  pulled in).
- A new config file under `packaging/shedos-system/tree/etc/labwc/`
  that we have to maintain.
- A risk of regressions during the cutover — cage is "boring"
  precisely because it does so little. labwc has more surface area
  for a misconfiguration to leak through.

## Decision

Keep cage today. Revisit when one of these forces it:

- Multi-monitor greeter complaints persist after Phase 12's fix.
- We want a feature in the greeter that needs layer-shell or
  another protocol cage doesn't expose.
- cage upstream stagnates beyond "patches accepted" (its release
  cadence is already slow; the project is stable, not active).

When we do flip, the work above is the rough scope.
