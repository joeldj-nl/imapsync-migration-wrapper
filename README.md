# Universal IMAP Migration Tool (CLI)

A robust, interactive Bash wrapper for **imapsync**. This tool provides a user-friendly CLI menu to migrate email accounts between servers.

It handles background processing, logging, and connection stability automatically, so you don't have to memorize complex CLI flags.

## 🚀 Features

*   **Interactive Menu:** No need to type long commands or CSV files. Just follow the prompts.
*   **Background Processing:** Migrations run in the background (detached). You can close your terminal without killing the migration.
*   **Performance Optimized:** Uses `--useheader` and `--skipcrossduplicates` for maximum speed (skips downloading full bodies if headers match).
*   **Live Monitoring:** View real-time logs of *active* migrations without interrupting them.
*   **PID Tracking:** Smart tracking system that knows exactly which migrations are running and which have finished.
*   **Secure:** Passwords are stored in temporary, permission-locked files (`chmod 600`) during execution to prevent command-history leaks.

## 🛠️ Prerequisites

This tool requires **imapsync** to be installed on your system.

### 1. Install imapsync

**Ubuntu / Debian:**
```bash
cd /tmp/
wget https://imapsync.lamiral.info/dist2/imapsync.deb
sudo apt install ./imapsync.deb
```

**CentOS / AlmaLinux / Rocky Linux / CloudLinux:**

First, enable the EPEL repository (if not already enabled):
```bash
sudo dnf install epel-release
```
Then install imapsync:
```bash
sudo dnf install imapsync
```

### 2. Install optional utilities (Recommended)
The tool uses standard Linux commands (`ps`, `grep`, `awk`, `tail`). These are usually pre-installed. If you encounter issues viewing logs, ensure `less` is installed.

## 📥 Installation


Clone this repository or copy and paste the script into `migration_tool.sh`.

Make the script executable.
 ```bash
chmod +x migration_tool.sh
```

## 🖥️ Usage

Run the tool from your terminal:

```bash
./migration_tool.sh
```

### The Main Menu

1.  **Start new migration:**
    *   Prompts for Source (Host1) and Destination (Host2) details.
    *   Automatically validates credentials (`--justlogin`) before starting.
    *   Starts the migration in the background.
2.  **View ACTIVE logs:**
    *   Shows a list of currently running migrations.
    *   Select one to view its live progress.
    *   Press `q` to return to the menu (does not stop the migration).
3.  **View HISTORY:**
    *   View logs of completed or failed migrations.
4.  **Delete old logs:**
    *   Cleans up the log directory.

## ⚙️ Technical Details (Flags Used)

This script applies the following `imapsync` optimizations by default:

*   `--useheader "Message-Id"`: **Huge speed boost.** Compares emails by Header ID instead of body size/content. Essential when migrating between different server types.
*   `--syncinternaldates`: Preserves the original date/time of emails.
*   `--resyncflags`: Preserves Read/Unread/Replied status.
*   `--skipcrossduplicates`: Prevents checking across different folders (saves CPU).
*   `--delete2duplicates`: Ensures the destination folder doesn't contain duplicates.

## 📂 File Structure

The script creates two hidden folders in its running directory:
*   `./imapsync_logs/`: Contains the output logs for every migration.
*   `./.imapsync_secrets/`: Temporarily stores password files and the active process tracker.
