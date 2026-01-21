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
SSD_MOUNT="/home/nilay/nextcloud_ssd"
USER_NAME="nilay"

echo "=== Initializing Automated Home Server Setup ==="

# =======================
# Directory Structure
# =======================
echo "Creating directory structure..."
sudo mkdir -p \
  $SETUP_DIR \
  $NEXTCLOUD_BASE/{db,html,data} \
  $AI_BASE/{ollama,open-webui} \
  $SYNCTHING_BASE/{config,data} \
  $KIWIX_BASE/data \
  $ONLYOFFICE_BASE/{data,logs,lib,db,cache} \
  $IMMICH_BASE/{library,postgres,model-cache} \
  $JELLYFIN_BASE/{config,cache} \
  $FRESHRSS_BASE/data \
  $PORTAINER_BASE \
  $MINECRAFT_BASE/data \
  $SSD_MOUNT

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
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu jammy stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# NVIDIA
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
| sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
| sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# =======================
# Permissions
# =======================
echo "Fixing permissions..."
sudo chown -R 33:33 $NEXTCLOUD_BASE/{data,html}
sudo chown -R 1000:1000 \
  $AI_BASE \
  $SYNCTHING_BASE \
  $KIWIX_BASE \
  $ONLYOFFICE_BASE \
  $IMMICH_BASE \
  $JELLYFIN_BASE \
  $FRESHRSS_BASE \
  $PORTAINER_BASE \
  $MINECRAFT_BASE \
  $SSD_MOUNT

sudo usermod -aG docker $USER_NAME

# =======================
# Ollama Keepalive
# =======================
echo "Adding Ollama GPU keepalive cron..."
(crontab -l 2>/dev/null; \
 echo "0 3 * * * docker exec ollama ollama run llama3.2 --keepalive 24h") | crontab -

# =======================
# Docker Compose
# =======================
echo "Writing docker-compose.yml..."

cat <<EOF > $SETUP_DIR/docker-compose.yml
networks:
  nilay-net:
    driver: bridge

services:
  # --- 1. Nextcloud Database ---
  db:
    image: mariadb:10.6
    container_name: nextcloud-setup-db-1
    restart: always
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
    volumes:
      - $NEXTCLOUD_BASE/db:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: strongpassword123
      MYSQL_PASSWORD: strongpassword123
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
    networks:
      - nilay-net

  # --- 2. Nextcloud Application ---
  app:
    image: nextcloud
    container_name: nextcloud-setup-app-1
    restart: always
    ports:
      - "8080:80"
    volumes:
      - $NEXTCLOUD_BASE/html:/var/www/html
      - $NEXTCLOUD_BASE/data:/var/www/html/data
      - $SSD_MOUNT:/var/www/html/data/nilayrakesh74@gmail.com/files/SSD_Storage
    environment:
      MYSQL_PASSWORD: strongpassword123
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
      MYSQL_HOST: db
    depends_on:
      - db
    networks:
      - nilay-net

  # --- 3. Ollama ---
  ollama:
    image: ollama/ollama
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    environment:
      OLLAMA_HOST: 0.0.0.0:11434
    volumes:
      - $AI_BASE/ollama:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    networks:
      - nilay-net

  # --- 4. Open-WebUI ---
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: always
    ports:
      - "3000:8080"
    environment:
      OLLAMA_BASE_URL: http://ollama:11434
    volumes:
      - $AI_BASE/open-webui:/app/backend/data
    depends_on:
      - ollama
    networks:
      - nilay-net

  # --- 5. Syncthing ---
  syncthing:
    image: lscr.io/linuxserver/syncthing
    container_name: syncthing
    restart: unless-stopped
    ports:
      - "8384:8384"
      - "22000:22000"
      - "21027:21027/udp"
    environment:
      PUID: 1000
      PGID: 1000
      TZ: Asia/Kolkata
    volumes:
      - $SYNCTHING_BASE/config:/config
      - $SYNCTHING_BASE/data:/vault
    networks:
      - nilay-net

  # --- 6. Kiwix ---
  kiwix:
    image: ghcr.io/kiwix/kiwix-serve:latest
    container_name: kiwix
    restart: unless-stopped
    ports:
      - "8081:8080"
    volumes:
      - $KIWIX_BASE/data:/data
    command: ["*.zim"]
    networks:
      - nilay-net

  # --- 7. Cockpit ---
  cockpit:
    image: quay.io/cockpit/ws
    container_name: cockpit
    restart: always
    privileged: true
    ports:
      - "9090:9090"
    volumes:
      - /run/dbus:/run/dbus:ro
      - /etc/passwd:/etc/passwd:ro
      - /etc/group:/etc/group:ro
      - /etc/shadow:/etc/shadow:ro
      - /etc/localtime:/etc/localtime:ro
    networks:
      - nilay-net

  # --- 8. Jellyfin ---
  jellyfin:
    image: jellyfin/jellyfin
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"
    volumes:
      - $JELLYFIN_BASE/config:/config
      - $JELLYFIN_BASE/cache:/cache
      - /mnt/sda1:/media
    environment:
      PUID: 1000
      PGID: 1000
    networks:
      - nilay-net

  # --- 9. ONLYOFFICE ---
  onlyoffice:
    image: onlyoffice/documentserver:latest
    container_name: onlyoffice
    restart: always
    ports:
      - "8082:80"
    environment:
      JWT_ENABLED: "true"
      JWT_SECRET: verysecurekey
      JWT_HEADER: Authorization
      JWT_IN_BODY: "true"
    volumes:
      - $ONLYOFFICE_BASE/data:/var/www/onlyoffice/Data
      - $ONLYOFFICE_BASE/logs:/var/log/onlyoffice
      - $ONLYOFFICE_BASE/lib:/var/lib/onlyoffice
      - $ONLYOFFICE_BASE/db:/var/lib/postgresql/14/main
      - $ONLYOFFICE_BASE/cache:/var/www/onlyoffice/documentserver/.cache
    networks:
      - nilay-net

  # --- 10. FreshRSS ---
  freshrss:
    image: freshrss/freshrss
    container_name: freshrss
    restart: unless-stopped
    ports:
      - "8083:80"
    environment:
      PUID: 1000
      PGID: 1000
      TZ: Asia/Kolkata
    volumes:
      - $FRESHRSS_BASE/data:/var/www/FreshRSS/data
    networks:
      - nilay-net

  # --- 11. IMMICH ---
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich_server
    restart: always
    environment:
      DB_HOSTNAME: immich-postgres
      DB_USERNAME: postgres
      DB_PASSWORD: strongpassword123
      DB_DATABASE_NAME: immich
      REDIS_HOSTNAME: immich-redis
      IMMICH_LISTEN_IP: 0.0.0.0
      IMMICH_PORT: 2283
      IMMICH_TRUSTED_PROXIES: 172.16.0.0/12
    volumes:
      - $IMMICH_BASE/library:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "2283:2283"
    depends_on:
      - immich-postgres
      - immich-redis
      - immich-machine-learning
    networks:
      - nilay-net

  immich-web:
    image: ghcr.io/immich-app/immich-web:release
    container_name: immich_web
    restart: always
    environment:
      IMMICH_SERVER_URL: http://immich-server:2283
    depends_on:
      - immich-server
    networks:
      - nilay-net

  immich-machine-learning:
    container_name: immich_machine_learning
    image: ghcr.io/immich-app/immich-machine-learning:release
    restart: always
    runtime: nvidia
    environment:
      NVIDIA_VISIBLE_DEVICES: all
      NVIDIA_DRIVER_CAPABILITIES: compute,utility
    volumes:
      - $IMMICH_BASE/model-cache:/cache
    networks:
      - nilay-net

  immich-postgres:
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
    container_name: immich_postgres
    restart: always
    environment:
      POSTGRES_PASSWORD: strongpassword123
      POSTGRES_USER: postgres
      POSTGRES_DB: immich
    volumes:
      - $IMMICH_BASE/postgres:/var/lib/postgresql/data
    networks:
      - nilay-net

  immich-redis:
    image: redis:6.2-alpine
    container_name: immich_redis
    restart: always
    networks:
      - nilay-net

  # --- 12. Samba ---
  samba:
    image: dperson/samba
    container_name: samba
    restart: always
    ports:
      - "139:139"
      - "445:445"
    volumes:
      - /mnt/sda1:/mnt/sda1
    command: >
      -u "nilay;strongpassword123"
      -s "HomeServer;/mnt/sda1;yes;no;no;nilay"
    networks:
      - nilay-net

  # --- 13. Portainer (Docker Management UI) ---
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - $PORTAINER_BASE:/data
    networks:
      - nilay-net

  # --- 14. Minecraft Server ---
  minecraft:
    image: itzg/minecraft-server
    container_name: minecraft-server
    restart: unless-stopped
    ports:
      - "25565:25565"
    environment:
      EULA: "TRUE"
      ONLINE_MODE: "FALSE"
      TYPE: "PAPER"
      VERSION: "LATEST"
      MEMORY: "4G"
      ENABLE_RCON: "true"
      RCON_PASSWORD: "strongpassword123"
    volumes:
      - $MINECRAFT_BASE/data:/data
    networks:
      - nilay-net
EOF

echo "=== Setup Complete! ==="
echo "Next steps:"
echo "  1. Navigate to: cd $SETUP_DIR"
echo "  2. Start services: docker compose up -d"
echo "  3. Access services via http://<ip>:<port>"
