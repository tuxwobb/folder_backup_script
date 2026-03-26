# SFTP / Local Archive Transfer Script

This script automates copying or moving monthly folders from a source directory
into a target storage location — either a local directory or a remote SFTP server.

The script expects subdirectories in the source folder named:

```
01, 02, 03, ..., 12
```

Each folder represents one month.

---

## 🧠 Year Detection Logic

The year is **not** taken from the folder name.  
Instead, it is determined from the folder’s **creation/modification timestamp**:

- year = `stat -c %y <folder> | cut -d'-' -f1`
- month = folder name (01–12)

The resulting structure in the target storage is:

```
<DEST>/<YEAR>/<MONTH>/
```

Examples:

```
/remote/path/2024/03/
/archive/2023/11/
```

---

## 📦 Transfer Modes

The script supports two transfer modes:

### 1) Local transfer
If a second argument is provided and it is an existing directory:

```
./script.sh /data/months /archive
```

→ folders are copied or moved locally.

### 2) SFTP upload
If no second argument is provided:

```
./script.sh /data/months
```

→ folders are uploaded to the SFTP server into:

```
/remote/path/<YEAR>/<MONTH>/
```

---

## 🔧 Command‑line Options

| Option | Description |
|--------|-------------|
| `-l` | Enable logging to syslog (`logger -t sftp_backup`) |
| `-v` | Verbose mode (prints progress) |
| `-m` | Move instead of copy (`mv`) |
| `-h` | Show help |

---

## 📝 Usage Examples

### Copy via SFTP
```
./script.sh /data/months
```

### Local move
```
./script.sh -m /data/months /archive
```

### Verbose + logging
```
./script.sh -v -l /data/months
```

---

## 🚫 What the script ignores

- folders not matching the `01–12` pattern  
- the folder corresponding to the **current month** (e.g., in March, folder `03`)  
- non‑existent source or destination directories  

---

## 📁 SFTP Operation Structure

The script uses **three separate SFTP sessions**:

1. create the year directory  
2. create the month directory  
3. upload the folder  

This avoids SFTP’s limitation of not supporting `mkdir -p`.

---

## 🛡️ Safety and Robustness

- `set -euo pipefail` ensures safe execution  
- all operations can be logged (`-l`)  
- the script is resilient to missing directories or duplicate `mkdir` calls  

---

## 📌 Requirements

- Bash 4+
- `sftp` client
- access to the SFTP server (password or SSH key)
- Linux/Unix environment

---

## 📂 Project Structure

```
script.sh
README.md
```

---

## 🧩 License

You may use, modify, and distribute this script as needed.

