# ShedOS Wallpapers

Custom wallpapers for ShedOS featuring geometric patterns and Catppuccin Mocha color scheme.

## Wallpapers

### shedos-default.png (4K - 3840x2160)
**Primary wallpaper** with gentle geometric circles in the desktop
theme palette. (The BRAND colors are defined in
`branding/new_assets/ShedOS-Color palette.pdf` — Electric Blue
`#007FFF` primary, Pure White, Alert Red, Classic Black; the colors
below are the Catppuccin Mocha *theme* accents the desktop ships
with, not the brand palette.)
- Base gradient: `#1e1e2e` → `#11111b` (Catppuccin Mocha base/crust)
- Accent colors:
  - Catppuccin Blue (#89b4fa) - default theme accent
  - Sapphire (#74c7ec) - complementary
  - Lavender (#b4befe) - complementary

**Design:** Diagonal gradient with three soft, blurred circular patterns positioned asymmetrically for visual interest. Modern, minimal aesthetic that doesn't distract from desktop content.

### shedos-dark.png (4K - 3840x2160)
**Darker variant** for users who prefer deeper blacks:
- Base gradient: `#11111b` → `#0d0d13` (darker Catppuccin tones)
- More subtle blue accents with increased blur

## Generation

These wallpapers were generated using ImageMagick with the following approach:

1. **Base gradient:** Diagonal gradient from Catppuccin Mocha colors
2. **Geometric elements:** Circular shapes with transparency and Gaussian blur
3. **Color palette:** ShedOS brand colors with opacity for subtlety

### Regenerating Wallpapers

If you want to customize or regenerate:

```bash
# Default wallpaper
magick -size 3840x2160 \
  -define gradient:angle=135 \
  gradient:'#1e1e2e-#11111b' \
  \( -size 3840x2160 xc:none \
     -fill '#89b4fa33' -draw 'circle 960,540 1200,540' \
     -fill '#74c7ec22' -draw 'circle 2880,1080 3120,1080' \
     -fill '#b4befe22' -draw 'circle 1920,1620 2160,1620' \
     -blur 0x80 \) \
  -composite \
  shedos-default.png

# Dark variant
magick -size 3840x2160 \
  -define gradient:angle=135 \
  gradient:'#11111b-#0d0d13' \
  \( -size 3840x2160 xc:none \
     -fill '#89b4fa22' -draw 'circle 1440,810 1680,810' \
     -fill '#74c7ec11' -draw 'circle 2400,1350 2640,1350' \
     -blur 0x100 \) \
  -composite \
  shedos-dark.png
```

## Color Reference

**Catppuccin Mocha Palette:**
- Base: `#1e1e2e`
- Mantle: `#181825`
- Crust: `#11111b`
- Blue (ShedOS): `#89b4fa`
- Sapphire: `#74c7ec`
- Lavender: `#b4befe`
- Text: `#cdd6f4`

## Usage in Hyprland

Set in `~/.config/hypr/hyprland.conf`:

```
exec-once = swww-daemon
exec = swww img ~/.config/hypr/wallpaper.png --transition-type fade --transition-fps 60
```

Link the desired wallpaper:
```bash
ln -sf /usr/share/shedos/wallpapers/shedos-default.png ~/.config/hypr/wallpaper.png
```

## License

Part of ShedOS - https://github.com/Theshedman/shedos
