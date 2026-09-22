# Log Archival Tool

A Bash CLI, `log-archive`, that compresses a directory of logs into a timestamped `tar.gz` archive so old logs can be cleared out while still being kept for future reference.

Project URL: https://roadmap.sh/projects/log-archive-tool

## What it does

| Step                | Details                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------ |
| Compress             | Packs the given log directory into a single `tar.gz` file                                        |
| Name                 | `logs_archive_YYYYMMDD_HHMMSS.tar.gz`, e.g. `logs_archive_20240816_100648.tar.gz`                 |
| Store                | Saves the archive to a separate directory (default `~/log_archives`), created if it doesn't exist |
| Record               | Appends a line to `archive.log` in the archive directory with the date, time, source and size     |
| Self-exclude         | If the archive directory is inside the log directory, it's excluded from the tar so repeated runs don't nest previous archives inside new ones |

## Requirements

- Bash
- Standard tools: `tar`, `du`, `date`

## Usage

```bash
chmod +x log-archive   # once
./log-archive <log-directory> [archive-directory]
```

Or put it on your `PATH` (e.g. symlink it into `/usr/local/bin/log-archive`) to run it as `log-archive <log-directory>` from anywhere, as shown in the project spec.

```bash
# Archive /var/log to the default location (~/log_archives)
log-archive /var/log

# Archive to a specific directory instead
log-archive /var/log /backup/log_archives

# Or set a default archive directory via environment variable
LOG_ARCHIVE_DIR=/backup/log_archives log-archive /var/log
```

`/var/log` is usually only readable as root, so on most systems you'll need:

```bash
sudo log-archive /var/log
```

### Scheduling

To archive logs on a set schedule, add a cron entry, e.g. daily at 2 AM:

```cron
0 2 * * * /usr/local/bin/log-archive /var/log /backup/log_archives >> /backup/log_archives/cron.log 2>&1
```

## Example output

```
$ log-archive /var/log /backup/log_archives
Archived '/var/log' -> '/backup/log_archives/logs_archive_20240816_100648.tar.gz' (2.1M)
Logged to '/backup/log_archives/archive.log'
```

`archive.log` accumulates one line per run:

```
2024-08-16 10:06:48 | source=/var/log | archive=/backup/log_archives/logs_archive_20240816_100648.tar.gz | size=2.1M
```

## Notes

- The default archive directory (`~/log_archives`) lives outside the log directory, so nothing needs to be excluded from the tar in the common case.
- If you do point `[archive-directory]` inside `<log-directory>`, the tool detects it and passes `--exclude` to `tar` so an archive never contains earlier archives.
- Run `log-archive --help` for the full usage summary.
