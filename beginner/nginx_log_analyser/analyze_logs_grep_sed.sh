#!/usr/bin/env bash
#
# analyze_logs_grep_sed.sh - Stretch-goal alternative to analyze_logs.sh.
#
# Same output as analyze_logs.sh (top 5 IPs, paths, status codes, user
# agents) but extracts every field with grep/sed/cut instead of awk, to
# show a different way of solving the same problem.
#
# Usage:
#   ./analyze_logs_grep_sed.sh [path/to/nginx-access.log]

set -eu
# Note: pipefail is deliberately left off. `head` exits after reading the
# top N lines, which makes the upstream grep/sed/sort commands receive
# SIGPIPE and exit non-zero even though the pipeline worked correctly -
# pipefail would turn that expected SIGPIPE into a script-ending error.

LOG_FILE="${1:-nginx-access.log}"

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: log file '$LOG_FILE' not found." >&2
    echo "Usage: $0 [path/to/nginx-access.log]" >&2
    exit 1
fi

TOP_N=5

# Turn "count value" lines from `sort | uniq -c | sort -rn` into the
# "value - count requests" format used in the example output.
format_counts() {
    sed -E 's/^[[:space:]]*([0-9]+)[[:space:]]+(.*)$/\2 - \1 requests/'
}

print_top_ips() {
    echo "Top ${TOP_N} IP addresses with the most requests:"
    # The IP address is always the first thing on the line.
    grep -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}' "$LOG_FILE" \
        | sort | uniq -c | sort -rn | head -n "$TOP_N" \
        | format_counts
    echo
}

print_top_paths() {
    echo "Top ${TOP_N} most requested paths:"
    # Pull out the request line (first "quoted" field), e.g. "GET /path HTTP/1.1",
    # then take the second word (the path) with cut.
    sed -E 's/^[^"]*"([^"]*)".*$/\1/' "$LOG_FILE" \
        | cut -d' ' -f2 \
        | sort | uniq -c | sort -rn | head -n "$TOP_N" \
        | format_counts
    echo
}

print_top_status_codes() {
    echo "Top ${TOP_N} response status codes:"
    # After the closing quote of the request line comes " STATUS SIZE ".
    sed -E 's/^[^"]*"[^"]*"[[:space:]]*([0-9]{3}).*$/\1/' "$LOG_FILE" \
        | sort | uniq -c | sort -rn | head -n "$TOP_N" \
        | format_counts
    echo
}

print_top_user_agents() {
    echo "Top ${TOP_N} user agents:"
    # The user agent is the last "quoted" field on the line.
    sed -E 's/^.*"([^"]*)"$/\1/' "$LOG_FILE" \
        | sort | uniq -c | sort -rn | head -n "$TOP_N" \
        | format_counts
    echo
}

print_top_ips
print_top_paths
print_top_status_codes
print_top_user_agents
