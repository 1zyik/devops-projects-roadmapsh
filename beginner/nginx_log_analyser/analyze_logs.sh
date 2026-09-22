#!/usr/bin/env bash
#
# analyze_logs.sh - Analyze an nginx access log (combined log format) and
# report the top 5 IP addresses, requested paths, response status codes,
# and user agents.
#
# Usage:
#   ./analyze_logs.sh [path/to/nginx-access.log]
#
# If no path is given, defaults to ./nginx-access.log in the current
# directory.

set -eu
# Note: pipefail is deliberately left off. `head` exits after reading the
# top N lines, which makes the upstream awk/sort commands receive SIGPIPE
# and exit non-zero even though the pipeline worked correctly - pipefail
# would turn that expected SIGPIPE into a script-ending error.

LOG_FILE="${1:-nginx-access.log}"

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: log file '$LOG_FILE' not found." >&2
    echo "Usage: $0 [path/to/nginx-access.log]" >&2
    exit 1
fi

TOP_N=5

# A line in nginx's combined log format looks like:
#   IP - user [date:time zone] "METHOD PATH PROTOCOL" STATUS SIZE "REFERRER" "USER AGENT"
#
# Splitting on the double quote (") character breaks each line into
# predictable chunks regardless of how many spaces are inside the quoted
# fields (the request line, the referrer and the user agent can all
# contain spaces):
#
#   $1 = 'IP - user [date:time zone] '
#   $2 = 'METHOD PATH PROTOCOL'
#   $3 = ' STATUS SIZE '
#   $4 = 'REFERRER'
#   $5 = ' '
#   $6 = 'USER AGENT'
#
# This is more reliable than splitting the whole line on spaces, since
# malformed/garbage request lines (e.g. port-scan noise) would otherwise
# shift every field that comes after them.

print_top_ips() {
    echo "Top ${TOP_N} IP addresses with the most requests:"
    awk -F'"' '{split($1, a, " "); print a[1]}' "$LOG_FILE" \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -n "$TOP_N" \
        | awk '{printf "%s - %s requests\n", $2, $1}'
    echo
}

print_top_paths() {
    echo "Top ${TOP_N} most requested paths:"
    awk -F'"' '{
        n = split($2, req, " ")
        print (n >= 2) ? req[2] : req[1]
    }' "$LOG_FILE" \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -n "$TOP_N" \
        | awk '{printf "%s - %s requests\n", $2, $1}'
    echo
}

print_top_status_codes() {
    echo "Top ${TOP_N} response status codes:"
    awk -F'"' '{split($3, s, " "); print s[1]}' "$LOG_FILE" \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -n "$TOP_N" \
        | awk '{printf "%s - %s requests\n", $2, $1}'
    echo
}

print_top_user_agents() {
    echo "Top ${TOP_N} user agents:"
    awk -F'"' '{print $6}' "$LOG_FILE" \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -n "$TOP_N" \
        | awk '{count=$1; $1=""; sub(/^ /, ""); printf "%s - %s requests\n", $0, count}'
    echo
}

print_top_ips
print_top_paths
print_top_status_codes
print_top_user_agents
