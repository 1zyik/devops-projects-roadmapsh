#!/usr/bin/env bash
# server-stats.sh - basic server performance stats for any Linux server.

set -u
export LC_ALL=C

hr() { printf '\n==== %s ====\n' "$1"; }

# --- Stretch: system info ---
hr "System Info"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    echo "OS version   : ${PRETTY_NAME:-unknown}"
fi
echo "Kernel       : $(uname -r)"
echo "Hostname     : $(hostname)"
echo "Uptime       : $(uptime -p 2>/dev/null || uptime)"
echo "Load average : $(cut -d' ' -f1-3 /proc/loadavg)"
echo "Logged users : $(who | wc -l)"
who | awk '{printf "  - %s (%s)\n", $1, $2}' | sort -u

# --- Total CPU usage (sampled over 1s from /proc/stat) ---
hr "Total CPU Usage"
read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
idle1=$((i1 + w1)); idle2=$((i2 + w2))
tot1=$((u1 + n1 + s1 + i1 + w1 + q1 + sq1 + st1))
tot2=$((u2 + n2 + s2 + i2 + w2 + q2 + sq2 + st2))
dt=$((tot2 - tot1)); di=$((idle2 - idle1))
awk -v dt="$dt" -v di="$di" 'BEGIN {
    u = dt > 0 ? (dt - di) * 100 / dt : 0
    printf "CPU used: %.1f%%  |  idle: %.1f%%\n", u, 100 - u }'

# --- Memory ---
hr "Memory Usage"
free -m | awk '/^Mem:/ {
    used = $3; total = $2; free = $4; avail = $7
    printf "Total: %d MiB\nUsed : %d MiB (%.1f%%)\nFree : %d MiB (%.1f%%)\nAvailable: %d MiB\n",
        total, used, used * 100 / total, free, free * 100 / total, avail }'

# --- Disk (all real, non-virtual filesystems, de-duplicated by device) ---
hr "Disk Usage"
df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs --output=source,size,used,avail 2>/dev/null |
    awk 'NR > 1 && !seen[$1]++ { size += $2; used += $3; avail += $4 }
    END {
        if (size == 0) { print "No disk info available"; exit }
        g = 1024 ^ 3
        printf "Total: %.2f GiB\nUsed : %.2f GiB (%.1f%%)\nFree : %.2f GiB (%.1f%%)\n",
            size / g, used / g, used * 100 / size, avail / g, avail * 100 / size }'

# --- Top processes ---
hr "Top 5 Processes by CPU"
ps -eo pid,user:12,pcpu,pmem,comm --sort=-pcpu | head -n 6

hr "Top 5 Processes by Memory"
ps -eo pid,user:12,pcpu,pmem,comm --sort=-pmem | head -n 6

# --- Stretch: failed logins ---
hr "Failed Login Attempts"
if command -v lastb >/dev/null 2>&1 && [ -r /var/log/btmp ]; then
    echo "Failed logins (btmp): $(lastb 2>/dev/null | grep -vc -e '^$' -e '^btmp begins')"
elif [ -r /var/log/auth.log ]; then
    echo "Failed logins (auth.log): $(grep -c 'Failed password' /var/log/auth.log)"
elif command -v journalctl >/dev/null 2>&1 && journalctl -q -n 1 >/dev/null 2>&1; then
    echo "Failed logins (journal): $(journalctl -q _COMM=sshd 2>/dev/null | grep -c 'Failed password')"
else
    echo "Unavailable (try running with sudo)"
fi
