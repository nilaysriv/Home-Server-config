#!/bin/bash
set -e

# =======================
# Variables & Paths
# =======================
SETUP_DIR="/mnt/sda1/setup"
NEXTCLOUD_BASE="/mnt/sda1/nextcloud"
AI_BASE="/mnt/sda1/ai"
SYNCTHING_BASE="/mnt/sda1/syncthing"
KIWIX_BASE="/mnt/sda1/kiwix"
ONLYOFFICE_BASE="/mnt/sda1/onlyoffice"
IMMICH_BASE="/mnt/sda1/immich"
JELLYFIN_BASE="/mnt/sda1/jellyfin"
FRESHRSS_BASE="/mnt/sda1/freshrss"
PORTAINER_BASE="/mnt/sda1/portainer"
MINECRAFT_BASE="/mnt/sda1/minecraft"
GLANCE_BASE="/mnt/sda1/glance"
VAULTWARDEN_BASE="/mnt/sda1/vaultwarden"
STIRLING_BASE="/mnt/sda1/stirling-pdf"
SPEEDTEST_BASE="/mnt/sda1/speedtest"
SEARXNG_BASE="/mnt/sda1/searxng"
LINKWARDEN_BASE="/mnt/sda1/linkwarden"
SAMBA_BASE="/mnt/sda1"
COCKPIT_BASE="/mnt/sda1/cockpit"
HASS_BASE="/mnt/sda1/homeassistant"
N8N_BASE="/mnt/sda1/n8n"
NPM_BASE="/mnt/sda1/npm"
MEDIA_BASE="/mnt/sda1/media"
ARRS_BASE="/mnt/sda1/arrs"
SSD_MOUNT="/home/nilay/nextcloud_ssd"
USER_NAME="nilay"
PUID=1000
PGID=1000

# =======================
# Directory Structure
# =======================
echo "Creating directory structure..."
sudo mkdir -p \
  "$SETUP_DIR" \
  "$NEXTCLOUD_BASE"/{db,html,data} \
  "$AI_BASE"/{ollama,open-webui} \
  "$SYNCTHING_BASE"/{config,data} \
  "$KIWIX_BASE"/data \
  "$ONLYOFFICE_BASE"/{data,logs,lib,db,cache} \
  "$IMMICH_BASE"/{library,postgres,model-cache} \
  "$JELLYFIN_BASE"/{config,cache} \
  "$FRESHRSS_BASE"/data \
  "$PORTAINER_BASE" \
  "$MINECRAFT_BASE"/data \
  "$GLANCE_BASE" \
  "$VAULTWARDEN_BASE" \
  "$STIRLING_BASE"/{configs,customFiles,logs} \
  "$SPEEDTEST_BASE" \
  "$SEARXNG_BASE" \
  "$LINKWARDEN_BASE"/{data,pgdata} \
  "$COCKPIT_BASE" \
  "$MEDIA_BASE"/{usenet,torrents} \
  "$ARRS_BASE"/{sabnzbd,qbittorrent,rdtclient,bazarr,lidarr,prowlarr,radarr,sonarr} \
  "$SSD_MOUNT" \
  "$HASS_BASE"/config \
  "$N8N_BASE"/data \
  "$NPM_BASE"/{data,letsencrypt}

# =======================
# Systemd Power Settings
# =======================
echo "Configuring lid behavior..."
sudo sed -i 's/^#HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/^#LidSwitchIgnoreInhibited=.*/LidSwitchIgnoreInhibited=no/' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind

# =======================
# Docker + NVIDIA Toolkit
# =======================
echo "Installing Docker & NVIDIA Container Toolkit..."
if ! command -v docker &>/dev/null; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# NVIDIA
if ! command -v nvidia-ctk &>/dev/null; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  sudo apt-get update
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
fi

# =======================
# Permissions
# =======================
echo "Fixing permissions..."

# Nextcloud (www-data)
sudo chown -R 33:33 "$NEXTCLOUD_BASE"/{data,html}

# App containers
sudo chown -R $PUID:$PGID \
  "$AI_BASE" \
  "$SYNCTHING_BASE" \
  "$KIWIX_BASE" \
  "$ONLYOFFICE_BASE" \
  "$IMMICH_BASE" \
  "$JELLYFIN_BASE" \
  "$FRESHRSS_BASE" \
  "$PORTAINER_BASE" \
  "$MINECRAFT_BASE" \
  "$GLANCE_BASE" \
  "$VAULTWARDEN_BASE" \
  "$STIRLING_BASE" \
  "$SPEEDTEST_BASE" \
  "$SEARXNG_BASE" \
  "$LINKWARDEN_BASE" \
  "$MEDIA_BASE" \
  "$ARRS_BASE" \
  "$SSD_MOUNT" \
  "$HASS_BASE" \
  "$N8N_BASE" \
  "$NPM_BASE"

# Docker access
sudo usermod -aG docker "$USER_NAME"

# =======================
# Ollama Keepalive
# =======================
echo "Adding Ollama GPU keepalive cron..."
(crontab -l 2>/dev/null; echo "0 3 * * * docker exec ollama ollama run llama3.2 --keepalive 24h") | crontab -

# =======================
# Notes
# =======================
echo "=== Setup Complete ==="
echo "- All containers preserved"
echo "- Uses env-based docker-compose.yml"
echo "- Next: docker compose --env-file .env up -d"