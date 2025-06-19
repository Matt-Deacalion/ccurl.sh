#!/usr/bin/env bash
#
# ccurl.sh - Extract cookies from Chromium tab and use with cURL
#
# Passes cookies from a Chromium instance and passes them to a cURL command.
#
# Usage:
#   ./ccurl.sh start [chromium-args…]         # start Chromium with debugging
#   ./ccurl.sh <tab-url-prefix> <curl-args…>  # run curl with extracted cookies
#
# Examples:
#   ./ccurl.sh start --incognito
#   ./ccurl.sh "https://example.com" -X GET "https://yandex.com/data"
#
# Requires: fzf, websocat

set -euo pipefail

readonly CHROMIUM_DEBUG_PORT=9222
readonly CHROMIUM_DEBUG_URL="http://127.0.0.1:${CHROMIUM_DEBUG_PORT}/json"

find_chromium() {
    local chromium_cmd
    for chromium_cmd in chromium chromium-browser google-chrome chrome; do
        command -v "${chromium_cmd}" >/dev/null 2>&1 && { printf '%s' "${chromium_cmd}"; return; }
    done
    return 1
}

start_chromium() {
    local chromium_cmd
    chromium_cmd=$(find_chromium) || { printf 'Error: Chrome/Chromium not found\n' >&2; exit 1; }

    printf 'Starting %s on port %d…\n' "${chromium_cmd}" "${CHROMIUM_DEBUG_PORT}"

    nohup "${chromium_cmd}" \
        --remote-debugging-port="${CHROMIUM_DEBUG_PORT}" \
        --user-data-dir="$(mktemp -d)" \
        --no-first-run \
        --no-default-browser-check \
        "$@" >/dev/null 2>&1 &

    while ! curl -sf "${CHROMIUM_DEBUG_URL}" >/dev/null 2>&1; do
        sleep 0.1
    done

    printf 'Chromium started (PID: %d)\n' $!
}

show_usage() {
    printf 'Usage: %s start [chromium-args…]\n' "${0##*/}" >&2
    printf '       %s <tab-url-prefix> <curl-args…>\n' "${0##*/}" >&2
    exit 1
}

# start subcommand
[[ ${1:-} == "start" ]] && { shift; start_chromium "$@"; exit; }

# validate arguments for curl
(( $# < 2 )) && show_usage

# extract arguments
readonly tab_prefix=$1
shift

# grab all tabs or fail
tabs_json=$(curl -sf "${CHROMIUM_DEBUG_URL}" 2>/dev/null) || {
    printf 'Error: Cannot connect to Chromium on port %d\n' "${CHROMIUM_DEBUG_PORT}" >&2
    printf 'Start Chromium with: %s start\n' "${0##*/}" >&2
    exit 1
}

matching_tabs=$(printf '%s' "${tabs_json}" | \
    jq -r --arg prefix "${tab_prefix}" \
    '.[] | select(.url | startswith($prefix)) | "\(.title)\t\(.url)\t\(.webSocketDebuggerUrl)"')

# TODO: show all tabs to select one anyway?
[[ -z ${matching_tabs} ]] && {
    printf 'Error: No tab found with URL prefix: %s\n' "${tab_prefix}" >&2
    exit 1
}

matching_count=$(printf '%s' "${matching_tabs}" | wc -l)

if (( matching_count == 1 )); then
    debug_url=$(printf '%s' "${matching_tabs}" | cut -f3)
else
    selected=$(printf '%s' "${matching_tabs}" | grep -Ev '^Service Worker' | \
        fzf --delimiter=$'\t' \
            --with-nth=1,2 \
            --height=40% \
            --layout=reverse \
            --prompt="Tab> ") || exit 1
    debug_url=$(printf '%s' "${selected}" | cut -f3)
fi

cookies=$(printf '{"id":2,"method":"Network.getCookies","params":{}}\n' | \
    websocat -t - "${debug_url}" | \
    jq -r '.result.cookies[] | "\(.name)=\(.value)"' | \
    paste -sd ';' -)

# …boom, we're off!
exec curl -H "Cookie: ${cookies}" "$@"
