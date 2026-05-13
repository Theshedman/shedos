PKGS=(hypr kitty)
RELPATHS=(.config/hypr/hyprland.conf .config/kitty/kitty.conf)

# File 0 has BASE (3-way); file 1 doesn't (2-way). Both get edited.
EXPECT_SAVED=1
EXPECT_ARGV_LINES=2
