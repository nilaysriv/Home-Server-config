#!/bin/bash

# --- CONFIGURATION ---
USER_NAME="nilay"
SETUP_DIR="/mnt/data/nextcloud-setup"
DATA_DIR="/mnt/data"
PORTS=(8080 3000 9091 3001 8663)

echo "--- PHASE 1: Dependency Setup ---"

# Install Docker
if ! command -v docker &> /dev/null
then
    echo "Installing Docker..."
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
    
    sudo usermod -aG docker ${USER_NAME}
    
    echo "Docker installed. User added to 'docker' group."
    echo "Move the docker-compose.yml file to /mnt/data/nextcloud-setup. You must log out and log back in for new permissions to take effect. Rerun the script afterwards."
    exit 1
fi

# Install and Configure Tailscale
if ! command -v tailscale &> /dev/null
then
    echo "Installing Tailscale..."
    sudo dnf install -y tailscale
    sudo systemctl enable --now tailscaled
    echo "Run 'sudo tailscale up' and log in manually after setup is complete."
fi

# Check data mount
if [ ! -d "${SETUP_DIR}" ]; then
    echo "ERROR: Setup directory ${SETUP_DIR} not found. Ensure HDD is mounted to /mnt/data."
    exit 1
fi


echo "--- PHASE 2: Permissions and Firewall ---"

# Fix volume permissions
echo "Setting file ownership for ${DATA_DIR}..."
sudo chown -R ${USER_NAME}:${USER_NAME} ${DATA_DIR}

# Configure FirewallD
echo "Configuring FirewallD..."
for PORT in "${PORTS[@]}"; do
    if ! sudo firewall-cmd --query-port=${PORT}/tcp &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=${PORT}/tcp
        echo "Added port ${PORT}/tcp."
    fi
done

sudo firewall-cmd --reload
echo "Firewall rules reloaded."


echo "--- PHASE 3: Launching Stack ---"

# Change directory and launch Docker Compose
cd "${SETUP_DIR}" || { echo "Failed to navigate to ${SETUP_DIR}."; exit 1; }

echo "Launching services defined in docker-compose.yml..."
sudo docker compose up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "------------------------------------------------------------------"
    echo "Stack launched successfully."
    echo "------------------------------------------------------------------"
else
    echo "ERROR: Docker Compose failed to start the stack."
fi
