# Simulate an "abandoned" merge — Meld dropped conflict markers in.
# The tool must detect and refuse to copy back.
cat > "$YOURS_DIR/.config/hypr/hyprland.conf" <<'EOF'
monitor = , preferred, auto, 1
<<<<<<< YOURS
input { kb_layout = us, kb_options = caps:escape }
=======
input { kb_layout = us }
>>>>>>> THEIRS
exec-once = waybar
EOF
