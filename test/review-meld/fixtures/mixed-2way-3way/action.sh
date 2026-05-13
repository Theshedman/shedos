# Both groups are launched in sequence. Each YOURS_DIR holds the files
# of one group; write the merged content into whichever path exists.

if [[ -f "$YOURS_DIR/.config/hypr/hyprland.conf" ]]; then
    cat > "$YOURS_DIR/.config/hypr/hyprland.conf" <<'EOF'
monitor = , preferred, auto, 1
input { kb_layout = us, kb_options = caps:escape }
exec-once = waybar
exec-once = mako
EOF
fi

if [[ -f "$YOURS_DIR/.config/kitty/kitty.conf" ]]; then
    cat > "$YOURS_DIR/.config/kitty/kitty.conf" <<'EOF'
font_size 12.0
enable_audio_bell no
cursor_blink_interval 0.5
EOF
fi
