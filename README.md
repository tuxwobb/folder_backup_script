# Transfer Script (SFTP / Local Copy / Move)  
Automated monthly directory transfer tool.

This script processes a source directory containing subdirectories named as months (`01`–`12`) and:

- Copies or moves them **locally** (if a destination directory is provided)  
- Uploads them via **SFTP** (if no destination is provided)

It skips the **current month**, and it supports *dry-run*, *logging*, and *verbose* modes.

---

## ✅ Features

- ✅ Copy mode (default)
- ✅ Move mode (`-m`)
- ✅ Local transfer (if destination directory is provided)
- ✅ SFTP upload fallback
- ✅ Logging via `logger` (`-l`)
- ✅ Verbose output (`-v`)
- ✅ Dry-run mode (`-d` or `--dry-run`)
- ✅ Safe handling of current month
- ✅ Works with month folders `01`–`12`
- ✅ Fully Bash-compatible with `[[ ]]` and `${var}` conventions

---

## ✅ Usage

```
./transfer.sh [options] <source_directory> [destination_directory]
```

- If only `<source_directory>` is provided → **SFTP mode**
- If both `<source_directory>` and `<destination_directory>` exist → **local mode**

---

## ✅ Options

| Option | Meaning |
|--------|---------|
| `-l` | Enable logging via `logger` |
| `-v` | Verbose output |
| `-m` | Move instead of copy |
| `-d`, `--dry-run` | Show actions but do nothing |
| `-h` | Show help |

---

## ✅ Examples

### Copy via SFTP:
```
./transfer.sh /data/months
```

### Move via SFTP:
```
./transfer.sh -m /data/months
```

### Copy locally:
```
./transfer.sh /data/months /backup/archive
```

### Move locally:
```
./transfer.sh -m /data/months /backup/archive
```

### Dry-run:
```
./transfer.sh --dry-run /data/months
```

### Verbose + logging + dry-run:
```
./transfer.sh -v -l -d /data/months
```

---

## ✅ Folder Structure Example

```
/data/months
 ├── 01/
 ├── 02/
 ├── 03/
 ├── 04/
 ...
 └── 12/
```

If the current month is `03`, the script transfers all except `03`.

---

## ✅ Requirements
- Bash
- SFTP installed (if using SFTP mode)
- Correct permissions for source/destination

---

## ✅ Notes
- Move mode (`-m`) deletes source folders **only after successful transfer**.
- Dry-run mode disables all write operations, including delete, copy, move, and SFTP upload.

---

## ✅ Author
Generated with ❤️ and Bash-fu 🐧  

