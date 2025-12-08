#  Nilay's Home Lab Stack

This repository documents the setup and configuration for a fully functional, self-hosted Docker stack running on a Fedora server. This stack provides private cloud storage, a local AI chat engine, a centralized dashboard, and performance monitoring.

## Services Overview

All services are run via Docker Compose and are configured to communicate over the internal Docker network. External access is currently handled via direct **HTTP ports**.

| Service | Container Name | Host Port | Function | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Nextcloud** | `nextcloud-setup-app-1` | `8080` | Private Cloud Storage | Operational (HTTP) |
| **AI Chatbot** | `open-webui` | `3000` | Local LLM Chat Interface | Operational (HTTP) |
| **Dashy** | `dashy` | `8663` | Centralized Dashboard | Operational (HTTP) |
| **Grafana** | `grafana` | `3001` | Visualization Dashboard | Operational (HTTP) |
| **Prometheus** | `prometheus` | `9091` | Time-Series Metrics Database | Operational (HTTP) |
| **Ollama** | `ollama` | Internal | Local AI Model Backend | Operational |

-----

## Prerequisites

Before launching the stack on a new machine, ensure the following are installed and configured:

1.  **Operating System:** Fedora
2.  **Docker & Compose:** Docker Engine and Docker Compose Plugin installed.
3.  **Tailscale:** Installed and running (for secure remote access).
4.  **Data Drive:** The primary data drive **must be mounted to `/mnt/data`**.

## The "One-Click" Setup Script

To easily migrate or restore the entire environment, use the provided `setup_my_stack.sh` script.

**Steps:**

1.  Clone this repository to your new machine.
2.  Ensure your data drive is mounted at `/mnt/data`.
3.  Give the script execution permission: `chmod +x conf.sh`
4.  Run the script: `./conf.sh`

-----

> **NOTE:** The script will pause and prompt you to **log out and log back in** after installing Docker and adding your user to the `docker` group. Rerun the script after re-login to complete the setup.

-----

## Directory Structure (Host Volumes)

All persistent data for the services are mapped to directories under `/mnt/data`:

| Host Path | Purpose |
| :--- | :--- |
| `/mnt/data/nextcloud-setup` | Contains `docker-compose.yml` and `setup_my_stack.sh`. **The project root.** |
| `/mnt/data/nextcloud/` | All Nextcloud files and database storage. |
| `/mnt/data/ai/` | Stores Ollama models and Open WebUI user data. |
| `/mnt/data/monitoring/` | Stores Prometheus configuration (`prometheus.yml`). |
| `/mnt/data/dashy/` | Stores the `conf.yml` dashboard configuration. |

## 🔗 Access Links

All services are accessible on the local network. For remote access, use your **Tailscale IP** or **Tailscale Hostname**.

| Service | URL (Local/Tailscale) | Login/Notes |
| :--- | :--- | :--- |
| **Dashy Dashboard** | `http://<ip-address>:8663` | Centralized links and host metrics. |
| **Nextcloud** | `http://<ip-address>:8080` | Use your Nextcloud user credentials. |
| **AI Chatbot** | `http://<ip-address>:3000` | Log in with Open WebUI admin credentials. |
| **Grafana** | `http://<ip-address>:3001` | User: `admin`, Pass: `strongpassword123` (Change immediately) |
| **Prometheus** | `http://<ip-address>:9091` | Prometheus UI (Used for checking scrape targets). |
| **Cockpit (OS Mgmt)** | `http://<ip-address>:9090` | Fedora Server Management. |

-----

## Key Configuration Files

The entire stack is defined in the single **`docker-compose.yml`** file located in the root of this project.

### Nextcloud Fixes

Due to previous reverse proxy testing, if Nextcloud fails to log in, you must use these commands to clear stale settings:

```bash
# Clear file locks (useful after mobile app issues)
sudo docker exec nextcloud-setup-db-1 mysql -u root -pstrongpassword123 -e "DELETE FROM nextcloud.oc_file_locks WHERE 1;"

# Reset proxy and protocol settings (run after any proxy issues)
sudo docker exec --user www-data nextcloud-setup-app-1 php occ config:system:delete overwriteprotocol
sudo docker exec --user www-data nextcloud-setup-app-1 php occ config:system:delete trusted_proxies
```
