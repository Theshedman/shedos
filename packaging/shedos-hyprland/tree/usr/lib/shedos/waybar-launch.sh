#!/bin/bash
# Wrapper for waybar that guarantees a working locale env. The clock
# module's format-alt uses fmt's L modifier, which constructs a
# std::locale from $LANG at parse time. When the locale archive
# doesn't have that locale (e.g. LANG was set before locale-gen
# completed, or the user's chosen locale never got generated), the
# std::locale constructor throws and waybar disables the entire
# clock module for the lifetime of the bar. C.UTF-8 is built into
# glibc 2.35+ and always available without locale-gen, so falling
# back to it keeps the clock alive even on a half-configured system.

set -u

# pam_env writes /etc/locale.conf into the user's session env, but a
# systemd --user unit started before pam_env runs (or in a session
# where it didn't run at all) won't see LANG. Source the file as a
# best-effort recovery.
if [[ -z "${LANG:-}" ]] && [[ -r /etc/locale.conf ]]; then
    . /etc/locale.conf 2>/dev/null || true
fi

# localedef --list-archive prints names in normalized form
# (en_US.utf8, not en_US.UTF-8); fold the env value to match.
_locale_in_archive() {
    local lang=${LANG:-}
    case "$lang" in
        ''|C|C.*|POSIX) return 0 ;;   # always available, no archive lookup needed
    esac
    local name=${lang%%.*}
    local enc=${lang#*.}
    enc=${enc,,}
    enc=${enc//-/}
    local normalized="${name}.${enc}"
    localedef --list-archive 2>/dev/null | grep -Fxq "$normalized"
}

if ! _locale_in_archive; then
    export LC_ALL=C.UTF-8
    command -v logger >/dev/null 2>&1 && \
        logger -t shedos-waybar-launch -p user.warning \
            "LANG=${LANG:-unset} missing from locale-archive; falling back to LC_ALL=C.UTF-8"
fi

exec /usr/bin/waybar "$@"
