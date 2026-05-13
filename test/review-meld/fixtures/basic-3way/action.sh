# Simulate the user merging both edits: their kb_options + theirs's mako.
cat > "$YOURS_DIR/.config/hypr/hyprland.conf" <<'EOF'
monitor = , preferred, auto, 1
input { kb_layout = us, kb_options = caps:escape }
exec-once = waybar
exec-once = mako
EOF
