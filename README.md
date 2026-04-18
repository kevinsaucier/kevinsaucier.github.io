# FPP Debian VM Build and optional Primary/Backup Sync

This repository contains everything needed to:

* Build a **Falcon Player (FPP) v10** system on **Debian 13 (Trixie)** using a preseed file
* Deploy a **primary / backup architecture**
* Automatically **sync media, configuration, and optionally plugins** between systems

The goal is a **repeatable, low-touch deployment** with minimal manual intervention.

---

# 🚀 Quick Start

## 1. Install Debian using Preseed

Boot the VM using the Debian ISO:

```
Advanced Options → Graphical Automated Install
```

Enter the preseed URL (this just automates a clean basic install using the full drive size):

```
https://raw.githubusercontent.com/kevinsaucier/cloud/refs/heads/main/fpp_preseed.txt
```

> Optional (manual entry shortcut):
> https://kevinsaucier.github.io/fpp_vm/debian_preseed.txt

---

## 2. Post-Install Setup

Login as `root` and run:

Generate/Verify SSH key for root user:

```bash
# Ensure root SSH key exists
if ! ls /root/.ssh/id_*.pub >/dev/null 2>&1; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""
fi
```

To allow SSH access directly to the FPP host:

```bash
# Enable root SSH (preseed does NOT fully handle this)
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
```

---

## 3. Install FPP

Copy the script from GitHub and give it execute permissions:

```bash
cd /root
wget -O /root/FPP_Install.sh https://raw.githubusercontent.com/FalconChristmas/fpp/master/SD/FPP_Install.sh
chmod +x /root/FPP_Install.sh
```

Patch for Debian 13 on VM compatibility (these steps fail when building on the VM, so bypass the failures):

```bash
sed -i 's/systemctl stop unattended-upgrades/systemctl stop unattended-upgrades || true/' /root/FPP_Install.sh
sed -i 's/systemctl disable unattended-upgrades/systemctl disable unattended-upgrades || true/g' /root/FPP_Install.sh
sed -i 's/systemctl disable beagle-flasher-init-shutdown.service/systemctl disable beagle-flasher-init-shutdown.service || true/' /root/FPP_Install.sh
```

Install FPP:

```bash
./FPP_Install.sh
```

Reboot the VM:

```bash
reboot
```

---

## 4. Verify FPP is Started and get the current IP

```bash
systemctl status fppd --no-pager
ip address
```

Access the UI:

```
http://<server-ip>
```

---

# 🔄 Optional Multi Server Sync Setup (Primary → Backup)

## 1. Download the script and copy it to a directory on the Primary server (I use /home/fpp)

> https://kevinsaucier.github.io/fpp_vm/SyncFPP_Primary2Backup.sh

Grant execute on Primary:

```bash
chmod +x /home/fpp/SyncFPP_Primary2Backup.sh
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
### You can include plugins if you like, but this may cause issues on some plugins.

```bash
/home/fpp/SyncFPP_Primary2Backup.sh <backup-ip> --include-plugins
```

When using `--include-plugins`, you can also exclude one or more plugins by name.

This is useful if:

* A plugin is configured differently on each server
* A plugin causes issues when copied between systems
* You want to keep certain plugins local to a specific instance

Example:

```bash
/home/fpp/SyncFPP_Primary2Backup.sh <backup-ip> --include-plugins --exclude-plugin remote-falcon
```

Multiple exclusions are supported:

```bash
/home/fpp/SyncFPP_Primary2Backup.sh <backup-ip> --include-plugins --exclude-plugin remote-falcon --exclude-plugin fpp-brightness
```

The script automatically translates each plugin name into the appropriate excludes for:

* `/home/fpp/media/plugins/<plugin-name>`
* `/home/fpp/media/config/plugin.<plugin-name>`
* `/home/fpp/media/config/plugin.<plugin-name>.*`

To see the current plugin names that can be excluded, run:

```bash
ls /home/fpp/media/plugins/
```


---

---

## 4. You can add the following to cron or you'll be prompted when running the script the first time

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
* Optional plugin exclusions (`--exclude-plugin <name>`)
* Dry-run mode (`--dry-run`)
* Non-interactive mode for cron (`--non-interactive`)
* Automatic log rotation (5 daily logs)
* `latest` log symlink for easy viewing
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
* config
* scripts

### Optional (copying plugin data to a second server may cause issues depending on plugin configuration. Use with caution.)

* plugins
* plugindata

---

# ⚠️ Notes / Gotchas

## SSH Keys

* Debian does NOT create a root user SSH key
* Must be created manually (see Post-Install section)

## FPP Installer Warnings

You may see:

```
log4cpp-config: No such file or directory
```

This is expected and non-fatal (library deprecation in progress).

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
* Optional Primary to Backup server sync

---

# 📄 License / Usage

Personal / community use. Modify as needed.

---

# 🙌 Credits

* Falcon Player (FPP) developers
* Debian installer / preseed system

---
