#!/bin/bash

# Variables & Path Configuration
SETUP_DIR="/mnt/sda1/setup"
NEXTCLOUD_BASE="/mnt/sda1/nextcloud"
AI_BASE="/mnt/sda1/ai"
SYNCTHING_BASE="/mnt/sda1/syncthing"
SSD_MOUNT="/home/nilay/nextcloud_ssd"
USER_NAME="nilay"
KIWIX_DATA="/mnt/sda1/kiwix/data"

echo "Initializing Automated Server Setup"

# Create Directory Structure
echo "Mapping data directories"
sudo mkdir -p $SETUP_DIR
sudo mkdir -p $NEXTCLOUD_BASE/{db,html,data}
sudo mkdir -p $AI_BASE/{ollama,open-webui}
sudo mkdir -p $SYNCTHING_BASE/{config,data}
sudo mkdir -p $KIWIX_DATA
mkdir -p $SSD_MOUNT

# Systemd Login Settings
sudo sed -i 's/^#HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/^#LidSwitchIgnoreInhibited=.*/LidSwitchIgnoreInhibited=no/' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind

# Install Docker & NVIDIA Runtime
echo "Installing Docker Engine and NVIDIA Container Toolkit"
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# KIWIX Setup
# Download Arch Wiki (Small - 30MB)
if [ ! -f "$KIWIX_DATA/archlinux_en_all_maxi_2025-09.zim" ]; then
    wget -c -P $KIWIX_DATA https://download.kiwix.org/zim/other/archlinux_en_all_maxi_2025-09.zim
    wget -c -P $KIWIX_DATA https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_mini_2025-12.zim
fi

echo "Offline Wikibase Setup Complete."
echo " To download the 11GB Wikipedia later, use: wget -c -P $KIWIX_DATA https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_mini_2025-12.zim"

# NVIDIA Toolkit for GPU Passthrough
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Permissions & Ownership
sudo chown -R 33:33 $NEXTCLOUD_BASE/data
sudo chown -R 33:33 $NEXTCLOUD_BASE/html
sudo chown -R 33:33 $SSD_MOUNT
sudo chmod +x /home/$USER_NAME
sudo chown -R $USER:$USER $KIWIX_DATA
sudo usermod -aG docker $USER_NAME


# Ollama Keepalive
echo "Adding 24h GPU keepalive to crontab"
(crontab -l 2>/dev/null; echo "0 3 * * * docker exec ollama ollama run llama3.2 --keepalive 24h") | crontab -

# Generate Docker Compose File
echo "Writing docker-compose.yml..."
cat <<EOF > $SETUP_DIR/docker-compose.yml
services:
  db:
    image: mariadb:10.6
    container_name: nextcloud-setup-db-1
    restart: always
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
    volumes:
      - $NEXTCLOUD_BASE/db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=strongpassword123
      - MYSQL_PASSWORD=strongpassword123
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud

  app:
    image: nextcloud
    container_name: nextcloud-setup-app-1
    restart: always
    ports:
      - '8080:80'
    volumes:
      - $NEXTCLOUD_BASE/html:/var/www/html
      - $NEXTCLOUD_BASE/data:/var/www/html/data
      - $SSD_MOUNT:/var/www/html/data/nilayrakesh74@gmail.com/files/SSD_Storage
    environment:
      - MYSQL_PASSWORD=strongpassword123
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=db
    depends_on:
      - db

  ollama:
    image: ollama/ollama
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
    volumes:
      - $AI_BASE/ollama:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: always
    ports:
      - '3000:8080'
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - $AI_BASE/open-webui:/app/backend/data
    depends_on:
      - ollama

  syncthing:
    image: lscr.io/linuxserver/syncthing
    container_name: syncthing
    restart: unless-stopped
    ports:
      - "8384:8384"
      - "22000:22000"
      - "21027:21027/udp"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Kolkata
    volumes:
      - $SYNCTHING_BASE/config:/config
      - $SYNCTHING_BASE/data:/vault
  kiwix:
    image: ghcr.io/kiwix/kiwix-serve:latest
    container_name: kiwix
    restart: unless-stopped
    ports:
      - '8081:8080'
    volumes:
      - /mnt/sda1/kiwix/data:/data
    command:
      - '*.zim'
  cockpit:
    image: quay.io/cockpit/ws
    container_name: cockpit
    restart: always
    privileged: true
    ports: [ "9090:9090" ]
    volumes:
      - /run/dbus:/run/dbus
      - /etc/passwd:/etc/passwd:ro
      - /etc/group:/etc/group:ro
      - /etc/shadow:/etc/shadow:ro
EOF

echo "Server Ready. Run 'cd $SETUP_DIR && docker compose up -d' to launch."
