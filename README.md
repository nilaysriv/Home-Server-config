# Nilay’s Home Lab Stack

This repository documents the setup and configuration of a **fully self-hosted Docker homelab** running on a Debian/Ubuntu-based server.

The stack provides:
- Private cloud storage
- Local AI inference and chat UI
- Offline knowledge base (Wikipedia + Arch Wiki)
- Photo management (Immich)
- Media streaming
- Document editing (ONLYOFFICE)
- File sync (Syncthing)
- Server management (Cockpit)

All services are orchestrated using **Docker Compose** and communicate over a single internal Docker bridge network.

External access is currently handled via **direct HTTP ports** (no reverse proxy yet).

---

## Services Overview

| Service | Container Name | Host Port | Purpose | Status |
|------|------|------|------|------|
| **Nextcloud** | `nextcloud-setup-app-1` | `8080` | Private cloud storage & file sync | ✅ Operational |
| **ONLYOFFICE** | `onlyoffice` | `8082` | Document editing for Nextcloud | ✅ Integrated |
| **Immich** | `immich_server` | `2283` | Self-hosted photo & video backup | ✅ Operational |
| **Jellyfin** | `jellyfin` | `8096` | Media streaming server | ✅ Operational |
| **Open WebUI** | `open-webui` | `3000` | Local LLM chat interface | ✅ Operational |
| **Ollama** | `ollama` | `11434` (API) | Local AI model backend | ✅ Operational |
| **Syncthing** | `syncthing` | `8384` | Obsidian vault & file sync | ✅ Operational |
| **KIWIX** | `kiwix` | `8081` | Offline Wikipedia & Arch Wiki | ✅ Operational |
| **FreshRSS** | `freshrss` | `8083` | RSS feed reader | ✅ Operational |
| **Cockpit** | `cockpit` | `9090` | Web-based server management | ✅ Operational |
| **Samba** | `samba` | `139 / 445` | LAN file sharing | ✅ Operational |
| **Portainer** | `portainer` | `9000` | Docker management UI | ✅ Operational |
| **Minecraft** | `minecraft-server` | `25565` | Minecraft Java server (Paper) | ✅ Operational |

---

## Prerequisites

Before deploying this stack on a new machine, ensure:

1. **Operating System**  
   Debian / Ubuntu / Linux Mint (tested on Debian-based systems)

2. **Docker**
   - Docker Engine
   - Docker Compose plugin

3. **NVIDIA GPU (Optional but recommended)**
   - NVIDIA drivers installed
   - `nvidia-container-toolkit` configured

4. **Tailscale**
   - Installed and running (used for secure remote access)

5. **Data Drive**
   - Primary data drive **must be mounted at `/mnt/sda1`**

---

## One-Click Setup Script

The entire stack can be deployed using the provided **`conf.sh`** script.

### What the script does
- Installs Docker + NVIDIA runtime
- Creates all required directories
- Fixes permissions
- Writes a production-ready `docker-compose.yml`
- Avoids IPv6 / proxy / port binding issues
- Requires **zero manual editing**

### Usage

```bash
git clone <this-repo>
cd <this-repo>
chmod +x conf.sh
./conf.sh
````

After completion:

```bash
cd /mnt/sda1/setup
docker compose up -d
```

---

## Directory Structure (Host Volumes)

All persistent data lives under `/mnt/sda1`:

| Host Path                    | Purpose                         |
| ---------------------------- | ------------------------------- |
| `/mnt/sda1/setup/`           | Docker Compose files & config   |
| `/mnt/sda1/nextcloud/`       | Nextcloud app + database        |
| `/mnt/sda1/ai/`              | Ollama models & Open WebUI data |
| `/mnt/sda1/immich/`          | Immich photos, DB, ML cache     |
| `/mnt/sda1/onlyoffice/`      | ONLYOFFICE data & cache         |
| `/mnt/sda1/jellyfin/`        | Jellyfin config & cache         |
| `/mnt/sda1/kiwix/`           | Offline Wikipedia & Arch Wiki   |
| `/mnt/sda1/syncthing/`       | Syncthing config & vault        |
| `/mnt/sda1/freshrss/`        | FreshRSS data                   |
| `/mnt/sda1/portainer/`       | Portainer configuration         |
| `/mnt/sda1/minecraft/`       | Minecraft server data           |
| `/home/nilay/nextcloud_ssd/` | SSD-backed Nextcloud storage    |

---

## Access Links

Use **local IP** or **Tailscale IP / hostname**.

| Service    | URL                |
| ---------- | ------------------ |
| Nextcloud  | `http://<ip>:8080` |
| ONLYOFFICE | `http://<ip>:8082` |
| Immich     | `http://<ip>:2283` |
| Jellyfin   | `http://<ip>:8096` |
| Open WebUI | `http://<ip>:3000` |
| Syncthing  | `http://<ip>:8384` |
| KIWIX      | `http://<ip>:8081` |
| FreshRSS   | `http://<ip>:8083` |
| Cockpit    | `http://<ip>:9090` |
| Portainer  | `http://<ip>:9000` |

---

## Key Configuration Files

* **`docker-compose.yml`**
  Defines the entire stack (single network, fixed ports, safe defaults)

* **`conf.sh`**
  Fully reproducible system bootstrap script

---

## Nextcloud Maintenance Notes

If Nextcloud login or file operations break (usually after proxy testing), run:

```bash
# Clear file locks
docker exec nextcloud-setup-db-1 \
  mysql -u root -pstrongpassword123 \
  -e "DELETE FROM nextcloud.oc_file_locks WHERE 1;"

# Remove stale proxy settings
docker exec --user www-data nextcloud-setup-app-1 php occ config:system:delete overwriteprotocol
docker exec --user www-data nextcloud-setup-app-1 php occ config:system:delete trusted_proxies
```

---

## Documentation Links

Official documentation for all services in this stack:

| Service | Documentation URL |
|---------|------------------|
| **Nextcloud** | https://docs.nextcloud.com/server/latest/admin_manual/ |
| **MariaDB** | https://mariadb.com/kb/en/documentation/ |
| **ONLYOFFICE** | https://helpcenter.onlyoffice.com/installation/docs-community-install-docker.aspx |
| **Immich** | https://immich.app/docs/overview/introduction |
| **Jellyfin** | https://jellyfin.org/docs/ |
| **Ollama** | https://github.com/ollama/ollama/blob/main/README.md |
| **Open WebUI** | https://docs.openwebui.com/ |
| **Syncthing** | https://docs.syncthing.net/ |
| **Kiwix** | https://wiki.kiwix.org/wiki/Main_Page |
| **FreshRSS** | https://freshrss.github.io/FreshRSS/en/ |
| **Cockpit** | https://cockpit-project.org/guide/latest/ |
| **Samba** | https://www.samba.org/samba/docs/ |
| **Portainer** | https://docs.portainer.io/ |
| **Minecraft Server** | https://docker-minecraft-server.readthedocs.io/en/latest/ |
| **Docker** | https://docs.docker.com/ |
| **NVIDIA Container Toolkit** | https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html |

---

## Screenshots / Rice

![fastfetch](fastfetch.png)
![btop](btop.png)
![containers](containers.png)
