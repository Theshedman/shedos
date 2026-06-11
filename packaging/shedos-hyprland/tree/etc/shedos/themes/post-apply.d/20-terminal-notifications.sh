#!/usr/bin/env bash
# Recolor kitty and mako after `shedman theme apply`. Both read their
# colors from includes under /etc/shedos/themes/current/ — kitty
# re-reads its config on SIGUSR1, mako on `makoctl reload`. Without
# this hook running instances keep the old palette until restarted.

set -u

pkill -u "$(id -u)" -SIGUSR1 -x kitty 2>/dev/null || true

if command -v makoctl >/dev/null 2>&1 \
    && pgrep -u "$(id -u)" -x mako >/dev/null 2>&1; then
    makoctl reload 2>/dev/null || true
fi
