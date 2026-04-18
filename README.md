# FPP Debian VM Build

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

## 2. Post-Install Setup

Login as `root` and run:

# Generate/Verify SSH key for root user
```bash
# Ensure root SSH key exists
if ! ls /root/.ssh/id_*.pub >/dev/null 2>&1; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""
fi
```

# To allow SSH access directly to the FPP host
```bash
# Enable root SSH (preseed does NOT fully handle this)
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
```



---

## 3. Install FPP

# Copy the script from github and give it execute permissions
```bash
cd /root
wget -O /root/FPP_Install.sh https://raw.githubusercontent.com/FalconChristmas/fpp/master/SD/FPP_Install.sh
chmod +x /root/FPP_Install.sh
```

# Patch for Debian 13 on VM compatibility (these steps fail when building on the VM so bypass the failure
```bash
sed -i 's/systemctl stop unattended-upgrades/systemctl stop unattended-upgrades || true/' /root/FPP_Install.sh
sed -i 's/systemctl disable unattended-upgrades/systemctl disable unattended-upgrades || true/g' /root/FPP_Install.sh
sed -i 's/systemctl disable beagle-flasher-init-shutdown.service/systemctl disable beagle-flasher-init-shutdown.service || true/' /root/FPP_Install.sh
```

# Install FPP
```bash
./FPP_Install.sh
```

# Reboots
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


# 👍 Status

This setup provides:

* Fully automated Debian install
* Repeatable FPP deployment

---

# 📄 License / Usage

Personal / community use. Modify as needed.

---

# 🙌 Credits

* Falcon Player (FPP) developers
* Debian installer / preseed system

---
