# VPN & Gaming DNS Setup Script

A streamlined Bash script for rapid deployment of a personal network infrastructure on a **fresh VPS**. This tool is designed to set up a high-performance VPN and an ad-blocking DNS server in under a minute, with custom DNS-rewrite support for gaming.

### 🚀 Key Features
* **Automated Installation:** Automatically handles dependencies and installs the latest Xray-core.
* **Modern Protocols:** Optimized for bypassing DPI and censorship:
    * **VLESS (Reality)** — industry-standard stealth.
    * **Hysteria 2** — high-speed UDP-based performance.
    * **Shadowsocks (2022)** — reliable security.
    * **Trojan, WireGuard, OpenVPN**.
* **AdGuard Home:** Integrated ad-blocking with easy DNS-rewrite (bypass) configuration.
* **Zero Bloat:** Deploys a clean, targeted solution without unnecessary services.

---

### ⚠️ Warning
This script is intended **only for fresh server installations**. Running it on a server with existing configurations may overwrite your current settings.

---

### 🛠 How it works
1. **DNS Setup:** Installs AdGuard Home, applies default ad-blocking filters, and allows you to configure DNS-rewrite for specific game domains.
2. **VPN Setup:** Choose your preferred protocol, set a port, and receive a ready-to-use connection link (compatible with v2rayNG, Nekoray, etc.) along with an ANSI QR code.

---

### 📋 Supported Protocols
* VLESS + Reality (XTLS-Vision)
* Hysteria 2
* Shadowsocks 2022 (AEAD)
* Trojan
* WireGuard
* OpenVPN

---

### ⚠️ Important Note
This script overwrites the configuration file at `/usr/local/etc/xray/config.json`. Please back up any existing configurations if you are not using a fresh server.

---

```bash
wget https://raw.githubusercontent.com/MrVPNru/Auto-setup-VPN-Xray-V-1.0/refs/heads/main/setup.sh && chmod +x setup.sh && ./setup.sh
