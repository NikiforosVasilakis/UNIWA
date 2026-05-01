# Linux Shell Scripting Exercises

## Prerequisites

Make each script executable before running it:

```bash
chmod +x E1/searching.sh
chmod +x E2/bck.sh E2/bck1.sh E2/bck2.sh
chmod +x E3/mfproc.sh
```

---

## E1 — Directory Scanner (`searching.sh`)

Scans one or more directories and reports files/subdirectories based on permissions, modification/access time, and read/write rights.

**Usage:**

```bash
./E1/searching.sh <octal_permissions> <days>
```

| Argument | Description |
|---|---|
| `octal_permissions` | Octal permission value to search for (e.g. `644`) |
| `days` | Number of days to look back for modifications/accesses |

**Example:**

```bash
./E1/searching.sh 644 7
```

After launching, the script enters an interactive loop prompting you to enter a directory path. Type `q` to exit and see the totals summary.

**What it reports per directory:**
1. Files matching the given octal permissions
2. Files modified in the last N days
3. Subdirectories accessed in the last N days
4. Files readable by all users (owner, group, others)
5. Subdirectories writable by others

---

## E2 — Backup Scripts (`bck.sh`, `bck1.sh`, `bck2.sh`)

### `bck.sh` — Immediate Backup

Creates a `.tar.gz` backup of a file or directory and copies/appends it to a destination.

**Usage:**

```bash
./E2/bck.sh <username> <source> <destination>
```

| Argument | Description |
|---|---|
| `username` | An existing system user |
| `source` | File or directory to back up |
| `destination` | Target directory or file path |

**Example:**

```bash
./E2/bck.sh john /home/john/docs /backup/
```

If `destination` is an existing directory, the archive is copied into it. If it is an existing file, the archive is appended to it. If it does not exist, it is created as a new file.

---

### `bck1.sh` — Scheduled Backup with `at`

Schedules a one-time backup using the `at` command.

> **Requires:** `at` daemon to be installed and running.

**Usage:**

```bash
./E2/bck1.sh <username> <source> <destination> <time>
```

| Argument | Description |
|---|---|
| `username` | An existing system user |
| `source` | File or directory to back up |
| `destination` | Target directory or file path |
| `time` | Time string accepted by `at` (see examples below) |

**Examples:**

```bash
./E2/bck1.sh john /home/john/docs /backup/ "11:00 PM"
./E2/bck1.sh john /home/john/docs /backup/ "now + 1 hour"
./E2/bck1.sh john /home/john/docs /backup/ "tomorrow 23:00"
```

---

### `bck2.sh` — Weekly Cron Backup

Backs up the **current working directory** to `/tmp` as a timestamped `.tar.gz` archive. Takes no arguments. Intended to be run via `cron` every Sunday at 23:00.

**Run manually:**

```bash
cd /directory/you/want/to/back/up
/path/to/E2/bck2.sh
```

**Set up with cron (every Sunday at 23:00):**

```bash
crontab -e
```

Add the following line:

```
0 23 * * 0 /full/path/to/E2/bck2.sh >> /tmp/bck2.log 2>&1
```

See [E2/CRON_SETUP.txt](E2/CRON_SETUP.txt) for more details.

---

## E3 — Process Info (`mfproc.sh`)

Displays information about running processes by reading directly from `/proc`. Supports filtering by user and/or process state.

> **Note:** This script reads from `/proc` and is intended for **Linux** only.

**Usage:**

```bash
./E3/mfproc.sh [-u <username>] [-s <R|S|Z>]
```

| Flag | Description |
|---|---|
| `-u username` | Filter processes belonging to this user |
| `-s state` | Filter by process state: `R` (running), `S` (sleeping), `Z` (zombie) |

Both flags are optional and can be combined.

**Examples:**

```bash
# All processes
./E3/mfproc.sh

# Processes owned by 'john'
./E3/mfproc.sh -u john

# All sleeping processes
./E3/mfproc.sh -s S

# Sleeping processes owned by 'john'
./E3/mfproc.sh -u john -s S
```
