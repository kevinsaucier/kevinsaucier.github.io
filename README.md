# FPP VM Build & Sync Automation

This repository contains everything needed to:

* Build a **Falcon Player (FPP) v10** system on **Debian 13 (Trixie)** using a preseed file
* Deploy a **primary / backup architecture**
* Automatically **sync media, configuration, and optionally plugins** between systems

The goal is a **repeatable, low-touch deployment** with minimal manual intervention.

---

# 🚀 Quick Start

## 1. Install Debian using Preseed

Use the Debian installer:

```
Advanced Options → Graphical Automated Install
```

Enter the preseed URL:

```
https://raw.githubusercontent.com/kevinsaucier/cloud/refs/heads/main/fpp_preseed.txt
```

> Optional (manual entry shortcut):
> https://kevinsaucier.github.io/fpp_vm/debian_preseed.txt

---

## 2. Post-Install Setup (REQUIRED)

Login as `root` and run:

```bash
# Enable root SSH (preseed does NOT fully handle this)
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# Ensure root SSH key exists
if ! ls /root/.ssh/id_*.pub >/dev/null 2>&1; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""
fi
```

---

## 3. Install FPP

```bash
cd /root
wget -O /root/FPP_Install.sh https://raw.githubusercontent.com/FalconChristmas/fpp/master/SD/FPP_Install.sh
chmod +x /root/FPP_Install.sh

# Patch for Debian 13 compatibility
sed -i 's/systemctl stop unattended-upgrades/systemctl stop unattended-upgrades || true/' /root/FPP_Install.sh
sed -i 's/systemctl disable unattended-upgrades/systemctl disable unattended-upgrades || true/g' /root/FPP_Install.sh
sed -i 's/systemctl disable beagle-flasher-init-shutdown.service/systemctl disable beagle-flasher-init-shutdown.service || true/' /root/FPP_Install.sh

./FPP_Install.sh
reboot
```

---

## 4. Verify FPP

```bash
systemctl status fppd --no-pager
```

Access UI:

```
http://<server-ip>
```

---

# 🔄 Sync Setup (Primary → Backup)

## 1. Copy Script

From primary:

```bash
scp /home/fpp/SyncFPP_Primary2Backup.sh root@<backup-ip>:/home/fpp/
ssh root@<backup-ip> "chmod +x /home/fpp/SyncFPP_Primary2Backup.sh"
```

---

## 2. Configure Passwordless SSH

From primary:

```bash
ssh-copy-id root@<backup-ip>
```

Verify:

```bash
ssh -o BatchMode=yes root@<backup-ip> "exit"
```

Expected result:

```
0
```

---

## 3. Test Sync

```bash
/home/fpp/SyncFPP_Primary2Backup.sh <backup-ip> --include-plugins
```

---

## 4. Enable Automation

```bash
crontab -e
```

Add:

```bash
*/5 * * * * /home/fpp/SyncFPP_Primary2Backup.sh <backup-ip> --non-interactive >> /dev/null 2>&1
```

---

# 🧠 Script Features

* Incremental sync using `rsync`
* File count reporting (per category)
* Optional plugin sync (`--include-plugins`)
* Dry-run mode (`--dry-run`)
* Non-interactive mode for cron (`--non-interactive`)
* Automatic log rotation (5 daily logs)
* SSH validation and setup guidance
* Cron auto-install helper

---

# 📁 What Gets Synced

### Media

* music
* videos
* sequences
* images
* effects

### Configuration

* playlists
* config (excluding remote-falcon)
* scripts

### Optional

* plugins
* plugindata

---

# ⚠️ Notes / Gotchas

## Debian Installer

* Must use:

  ```
  Graphical Automated Install
  ```
* Other install modes will NOT properly apply preseed

---

## Partitioning Prompts

If prompted:

* "Write changes to disk"
* "Finish partitioning"

→ Your preseed is missing required `partman` confirmations

---

## SSH Keys

* Debian does NOT create user SSH keys
* Must be created manually (see Post-Install section)

---

## FPP Installer Warnings

You may see:

```
log4cpp-config: No such file or directory
```

This is expected and non-fatal (library deprecation in progress).

---

## GitHub URLs

Use:

```
raw.githubusercontent.com
```

for installer reliability.

GitHub Pages (`.io`) is fine for human use but not guaranteed for Debian.

---

# 🔧 Architecture Overview

```text
Primary FPP
   │
   ├── rsync (cron, every 5 min)
   │
   ▼
Backup FPP
```

* Primary is authoritative
* Backup stays continuously in sync
* Failover is manual or external

---

# 👍 Status

This setup provides:

* Fully automated Debian install
* Repeatable FPP deployment
* Reliable primary/backup sync
* Minimal ongoing maintenance

---

# 📌 Future Improvements (Optional)

* Email/alerting on sync failures
* Systemd timers instead of cron
* Version-pinned preseed URLs
* Automated failover logic

---

# 📄 License / Usage

Personal / community use. Modify as needed.

---

# 🙌 Credits

* Falcon Player (FPP) developers
* Debian installer / preseed system

---
