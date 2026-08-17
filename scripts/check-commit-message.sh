#!/usr/bin/env bash
# Refuse a commit message that breaks the house voice. The rules it holds are
# the owner's, collected from real rejections: subjects state the edit in a
# plain verb with no comma, bodies are prose wrapped at 74 columns, and
# nothing in the message may read as machine-written or carry attribution.
# Wired as the commit-msg hook via .githooks; `bash scripts/check-commit-message.sh <file>`
# runs it standalone.
set -euo pipefail

msg_file=${1:?usage: check-commit-message.sh <message-file>}

mapfile -t lines < <(grep -v '^#' "$msg_file")
subject=${lines[0]:-}

fail=0
red=$'\033[0;31m'; nc=$'\033[0m'
refuse() {
    printf '%s✗ %s%s\n' "$red" "$1" "$nc" >&2
    [[ -n ${2:-} ]] && printf '    %s\n' "$2" >&2
    fail=1
}

if [[ ! $subject =~ ^(build|chore|ci|docs|feat|fix|perf|refactor|test)(\([a-z0-9._-]+\))?:\ [a-z0-9] ]]; then
    refuse "subject is not 'type(scope): lowercase edit'" "$subject"
fi

[[ $subject == *,* ]] && refuse "subject carries a comma — one clause only" "$subject"

(( ${#subject} > 72 )) && refuse "subject is ${#subject} chars — cap is 72" "$subject"

[[ $subject =~ ^Merge\ (branch|remote-tracking) ]] &&
    refuse "merge commits need a real subject, not git's default" "$subject"

# Openers the owner has rejected by name: they direct the software instead of
# stating the edit. Extend this list from real rejections only.
verb=$(sed -E 's/^[a-z]+(\([^)]*\))?: //' <<<"$subject" | awk '{print $1}')
case $verb in
    stop|point|answer|ask|say)
        refuse "subject opens with '$verb' — state the edit, do not direct the code" "$subject" ;;
esac

if (( ${#lines[@]} > 1 )) && [[ -n ${lines[1]:-} ]]; then
    refuse "subject and body need a blank line between them" "${lines[1]}"
fi

for ((i = 2; i < ${#lines[@]}; i++)); do
    line=${lines[$i]}
    (( ${#line} > 74 )) && refuse "body line is ${#line} chars — wrap at 74" "$line"
    [[ $line =~ ^[[:space:]]*[-*•][[:space:]] ]] &&
        refuse "body carries a bullet — write prose" "$line"
    [[ $line =~ ^#+[[:space:]] ]] &&
        refuse "body carries a heading — write prose" "$line"
done

whole=$(printf '%s\n' "${lines[@]}")
if grep -qiE 'co-authored-by|generated with|noreply@anthropic|claude' <<<"$whole" ||
   grep -qP '[\x{1F300}-\x{1FAFF}\x{2700}-\x{27BF}]' <<<"$whole"; then
    refuse "message carries attribution or an emoji"
fi
if grep -qwiE 'comprehensive(ly)?|seamless(ly)?|leverage[sd]?|utilize[sd]?|streamline[sd]?|delve[sd]?|furthermore|moreover' <<<"$whole"; then
    refuse "message uses a word off the machine-tone list" \
        "$(grep -wiE -o 'comprehensive(ly)?|seamless(ly)?|leverage[sd]?|utilize[sd]?|streamline[sd]?|delve[sd]?|furthermore|moreover' <<<"$whole" | sort -u | tr '\n' ' ')"
fi

exit $fail
