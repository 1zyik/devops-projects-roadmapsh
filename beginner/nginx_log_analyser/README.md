# Nginx Log Analyser

A shell scripting exercise from [roadmap.sh](https://roadmap.sh/projects/nginx-log-analyser): parse an
nginx access log from the command line and report the top 5 IP addresses,
requested paths, response status codes, and user agents.

Two independent implementations are included, both producing identical
output, to satisfy the project's stretch goal of solving the problem more
than one way:

| Script | Approach |
|---|---|
| `analyze_logs.sh` | `awk` for field extraction, `sort`/`uniq`/`head` for ranking |
| `analyze_logs_grep_sed.sh` | `grep`/`sed`/`cut` for field extraction, `sort`/`uniq`/`head` for ranking |

## The log format

The sample log (`nginx-access.log`) is in nginx's default **combined log
format**:

```
IP - remote_user [date:time zone] "METHOD PATH PROTOCOL" STATUS SIZE "REFERRER" "USER_AGENT"
```

Example line:

```
178.128.94.113 - - [04/Oct/2024:00:00:18 +0000] "GET /v1-health HTTP/1.1" 200 51 "-" "DigitalOcean Uptime Probe 0.22.0 (https://digitalocean.com)"
```

The tricky part is that a naive "split the line on spaces" strategy breaks,
because the request, referrer, and user agent fields all contain spaces of
their own. Both scripts work around this by first splitting the line on the
`"` (double-quote) character, which reliably separates the line into:

```
$1  IP - remote_user [date:time zone]
$2  METHOD PATH PROTOCOL          <- the request line
$3  STATUS SIZE
$4  REFERRER
$5  (a single space)
$6  USER AGENT
```

From there:
- The **IP** is the first word of `$1`.
- The **path** is the second word of `$2`.
- The **status code** is the first word of `$3`.
- The **user agent** is `$6` as-is.

This also correctly handles the handful of malformed/garbage request lines
present in the sample log (e.g. port-scanner noise like `"\x04\x01\x00PPBS0\x00"`
instead of a real `GET /path HTTP/1.1` request) without shifting every field
that comes after them, which a plain whitespace split would do.

## Usage

Both scripts take an optional path to a log file (defaulting to
`nginx-access.log` in the current directory) and print the same report.

```bash
chmod +x analyze_logs.sh analyze_logs_grep_sed.sh

# Use the default ./nginx-access.log
./analyze_logs.sh

# Or point at any other access log
./analyze_logs.sh /var/log/nginx/access.log
./analyze_logs_grep_sed.sh /var/log/nginx/access.log
```

### Sample output

```
Top 5 IP addresses with the most requests:
178.128.94.113 - 1087 requests
142.93.136.176 - 1087 requests
138.68.248.85 - 1087 requests
159.89.185.30 - 1086 requests
86.134.118.70 - 277 requests

Top 5 most requested paths:
/v1-health - 4560 requests
/ - 270 requests
/v1-me - 232 requests
/v1-list-workspaces - 127 requests
/v1-list-timezone-teams - 75 requests

Top 5 response status codes:
200 - 5740 requests
404 - 937 requests
304 - 621 requests
400 - 260 requests
403 - 23 requests

Top 5 user agents:
DigitalOcean Uptime Probe 0.22.0 (https://digitalocean.com) - 4347 requests
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 - 513 requests
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 - 332 requests
Custom-AsyncHttpClient - 294 requests
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 - 282 requests
```

Both scripts produce byte-for-byte identical output against the sample log
(verified with `diff <(./analyze_logs.sh) <(./analyze_logs_grep_sed.sh)`).

## How it works

### `analyze_logs.sh` (awk)

For each report, the pipeline is: extract the relevant field with `awk`,
`sort` the values, collapse duplicates and count them with `uniq -c`,
`sort -rn` to rank by count descending, then `head -n 5` to keep the top 5.
A final `awk` reformats the `count value` output of `uniq -c` into the
`value - count requests` format shown above.

```bash
awk -F'"' '{split($1, a, " "); print a[1]}' "$LOG_FILE" \
    | sort | uniq -c | sort -rn | head -n 5
```

### `analyze_logs_grep_sed.sh` (grep + sed)

Same pipeline shape, but each field is pulled out with `grep -oE` or
`sed -E` instead of `awk`:

- **IPs**: `grep -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}'` matches the IP anchored
  at the start of the line.
- **Paths**: `sed -E 's/^[^"]*"([^"]*)".*$/\1/'` captures the request line
  (the first quoted field), then `cut -d' ' -f2` takes the path out of
  `METHOD PATH PROTOCOL`.
- **Status codes**: `sed -E 's/^[^"]*"[^"]*"[[:space:]]*([0-9]{3}).*$/\1/'`
  matches the three-digit status code that follows the closing quote of the
  request line.
- **User agents**: `sed -E 's/^.*"([^"]*)"$/\1/'` greedily matches up to the
  last quoted field on the line.

### Why `pipefail` is not used

Both scripts run with `set -eu` rather than `set -euo pipefail`. With
`pipefail` enabled, `head -n 5` exiting after reading 5 lines causes the
upstream `sort`/`awk`/`sed` processes to receive `SIGPIPE` and exit
non-zero, which `set -e` would then treat as a script failure even though
the pipeline did exactly what was intended. Leaving `pipefail` off avoids
that false failure.

## Getting the sample log

The sample log used during development was downloaded with:

```bash
curl -sL -o nginx-access.log \
  "http://gist.githubusercontent.com/nilbuild/e66c3b9ea89a1a030d3b739eeeef22d0/raw/77fb3ac837a73c4f0206e78a236d885590b7ae35/nginx-access.log"
```

It's committed alongside the scripts in this directory so the project runs
out of the box.
