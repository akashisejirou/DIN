#!/bin/bash

show() {
    echo "$1"
}

if ! command -v jq &> /dev/null; then
    show "jq not found, installing..."
    sudo apt-get update
    sudo apt-get install -y jq > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        show "Failed to install jq. Please check your package manager."
        exit 1
    fi
fi

check_latest_version() {
    local REPO_URL="https://api.github.com/repos/web3go-xyz/chipper-node-miner-release/releases/latest"

    for i in {1..3}; do
        LATEST_VERSION=$(curl -s "$REPO_URL" | jq -r '.tag_name')
        if [ $? -ne 0 ]; then
            show "curl failed. Please ensure curl is installed and working properly."
            exit 1
        fi

        if [ -n "$LATEST_VERSION" ]; then
            show "Latest version available: $LATEST_VERSION"
            return 0
        fi

        show "Attempt $i: Failed to fetch the latest version. Retrying..."
        sleep 2
    done

    show "Failed to fetch the latest version after 3 attempts. Please check your internet connection or GitHub API limits."
    exit 1
}

check_latest_version

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    DOWNLOAD_URL="https://github.com/web3go-xyz/chipper-node-miner-release/releases/download/${LATEST_VERSION}/din-chipper-node-cli-linux-amd64"
else
    show "Unsupported architecture: $ARCH"
    exit 1
fi

DIN_NODE_DIR="/home/$USER/din_node"
mkdir -p "$DIN_NODE_DIR"

show "Downloading din-chipper-node-cli for architecture $ARCH..."
curl -L "$DOWNLOAD_URL" -o "$DIN_NODE_DIR/din-chipper-node-cli-linux-amd64"
if [ $? -ne 0 ]; then
    show "Failed to download the asset. Please check your internet connection."
    exit 1
fi

show "Download complete."

chmod +x "$DIN_NODE_DIR/din-chipper-node-cli-linux-amd64"

for i in {1..10}; do
    read -p "Enter your license key for license #$i: " license_key
    if [ -z "$license_key" ]; then
        break
    fi
    echo "$license_key" > "$DIN_NODE_DIR/license/din_license_$i.license"
done

SERVICE_NAME="din_node"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

cat <<EOL | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=DIN Node Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$DIN_NODE_DIR
ExecStart=$DIN_NODE_DIR/din-chipper-node-cli-linux-amd64 --license=$DIN_NODE_DIR/license/din_license_1.license --license=$DIN_NODE_DIR/license/din_license_2.license
Restart=no

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"
show "DIN Node service started."

show "Displaying real-time logs. Press Ctrl+C to stop."
journalctl -u "$SERVICE_NAME" -f

# Exit the script gracefully
exit 0
