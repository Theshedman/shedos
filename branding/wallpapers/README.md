# ShedOS Wallpapers

The shipped wallpaper set lives in
`packaging/shedos-branding/tree/usr/share/shedos/wallpapers/`. Each
wallpaper is 4K (3840×2160, 16:9) and ships with a `*-blurred`
companion the greeter and lock screen render behind their UI. Switch
between them with `shedman theme set wallpaper <path>`.

## Default

**lumen** — a luminous violet-and-magenta light ribbon. Set as the
default in `system.toml [theme]` and as the renderer fallback. Smooth
gradient, so it ships as PNG to avoid banding.

## The set

| Name | Scene |
|---|---|
| lumen (default) | violet/magenta light ribbon (abstract) |
| drift | floating geometric cubes, dark teal (abstract) |
| horizon | calm sunset over water |
| alpenglow | mountain peaks at last light |
| solstice | deep red sun low on the horizon |
| stillwater | a misty pier on still water |
| afterglow | warm sunset reflected on water |
| shoreline | turquoise coastline from above |
| headland | coastal mountains across a bay |

Abstracts (lumen, drift) ship as PNG; the photographs ship as
quality-92 JPEG — appropriate to the content and far smaller.

## Licensing & credit

Every photograph is from **Unsplash**, under the
[Unsplash License](https://unsplash.com/license): free to use,
including commercially and in redistributed software, with no
permission or attribution required. We credit the photographers
regardless — they earned it:

- horizon — Anders Jilden
- alpenglow — Aneesh Matcha
- solstice — Aperture Vintage
- stillwater — Jack B
- lumen — Milad Fakurian
- afterglow — Peter F
- drift — Sebastian Svenson
- shoreline — Wade Meng
- headland — Gerhard Venter (centre crop of a portrait original)

This record also keeps the provenance of GPL-distributed image
assets clear.

## Existing installs

`system.toml` is a backup file, so a changed shipped default reaches
fresh installs only. `/usr/lib/shedos/backfill-default-wallpaper.py`
(run from the upgrade scriptlet, stamp-gated) advances installs still
on the previous default to lumen and never touches a custom choice;
it takes effect at the next login.

## Earlier set

The original geometric wallpapers (`shedos-default.png`,
`shedos-dark.png`, `dusk.png`, `eclipse.png`, …) remain available in
the picker. The BRAND colors are defined in
`branding/new_assets/ShedOS-Color palette.pdf` (Electric Blue
`#007FFF`, Pure White, Alert Red, Classic Black).
