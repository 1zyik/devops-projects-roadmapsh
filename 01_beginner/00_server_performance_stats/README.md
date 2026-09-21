# Server Performance Stats

A Bash script, `server-stats.sh`, that analyses basic server performance stats on any Linux server.

Project idea from [https://roadmap.sh/projects/server-stats](https://roadmap.sh/projects/server-stats).

## What it reports

| Section                   | Details                                                                                                                        |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| System info               | OS version, kernel, hostname, uptime, load average, logged-in users                                                            |
| Total CPU usage           | Used and idle percentage, sampled over 1 second from `/proc/stat`                                                              |
| Memory usage              | Total, used and free in MiB, with percentages, plus available memory                                                           |
| Disk usage                | Total, used and free in GiB, with percentages. Sums real filesystems and skips tmpfs, devtmpfs, squashfs, overlay and efivarfs |
| Top 5 processes by CPU    | PID, user, %CPU, %MEM, command                                                                                                 |
| Top 5 processes by memory | PID, user, %CPU, %MEM, command                                                                                                 |
| Failed login attempts     | Count from `lastb`, `/var/log/auth.log` or the systemd journal, whichever is available                                         |

## Requirements

- Linux with Bash
- Standard tools: `free`, `df`, `ps`, `awk`, `who`, `uptime`
- Optional: `lastb` / `journalctl` for failed login counts

## Usage

Make the script executable (once), then run it:

```bash
chmod +x server-stats.sh
./server-stats.sh
```

Or run it without changing permissions:

```bash
bash server-stats.sh
```

Failed login attempts usually need read access to `/var/log/btmp`, `/var/log/auth.log` or the journal. If the script prints `Unavailable`, run it with `sudo`:

```bash
sudo ./server-stats.sh
```

To run it on a remote server:

```bash
ssh user@host 'bash -s' < server-stats.sh
```

## Example output

```
==== System Info ====
OS version   : Fedora Linux 44 (Workstation Edition)
Kernel       : 7.2.5-200.fc44.x86_64
Hostname     : lana
Uptime       : up 1 day, 21 hours, 57 minutes
Load average : 0.80 0.79 0.70
Logged users : 2

==== Total CPU Usage ====
CPU used: 3.6%  |  idle: 96.4%

==== Memory Usage ====
Total: 31706 MiB
Used : 16609 MiB (52.4%)
Free : 281 MiB (0.9%)
Available: 15096 MiB

==== Disk Usage ====
Total: 953.77 GiB
Used : 66.59 GiB (7.0%)
Free : 886.22 GiB (92.9%)

==== Top 5 Processes by CPU ====
    PID USER         %CPU %MEM COMMAND
  79989 izyik        18.5  1.0 claude
  ...
```

## Notes

- "Free" memory excludes cache and buffers, so it is often low on a healthy system. Use "Available" for memory that can actually be used by new processes.
- `ps` may briefly appear at the top of the CPU list because it measures itself at startup; this is normal.
