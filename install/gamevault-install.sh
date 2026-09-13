#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: (your name)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://gamevau.lt/ | Github: https://github.com/Phalcode/gamevault-backend

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Enabling contrib/non-free (needed for RAR support)"
if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
  SRC_FILE=/etc/apt/sources.list.d/debian.sources
  # Debian 13's default file only ships "Components: main non-free-firmware",
  # so we add whichever of contrib/non-free/non-free-firmware are missing,
  # on every "Components:" line (main, updates, security), without duplicating.
  for comp in contrib non-free non-free-firmware; do
    if ! grep -Eq "^Components:.*[[:space:]]${comp}([[:space:]]|\$)" "$SRC_FILE"; then
      sed -i "/^Components:/ s/\$/ ${comp}/" "$SRC_FILE"
    fi
  done
elif [[ -f /etc/apt/sources.list ]]; then
  sed -i -E "s/^(deb\s+\S+\s+\S+\s+main)(\s.*)?\$/\1 contrib non-free non-free-firmware/" /etc/apt/sources.list
fi
$STD apt-get update
msg_ok "Enabled contrib/non-free"

msg_info "Installing Dependencies"
$STD apt-get install -y \
  git \
  build-essential \
  python3 \
  p7zip-full \
  p7zip-rar
msg_ok "Installed Dependencies"

NODE_VERSION="22" NODE_MODULE="pnpm" setup_nodejs
get_lxc_ip

msg_info "Cloning GameVault Backend"
git clone -q https://github.com/Phalcode/gamevault-backend.git /opt/gamevault-backend
cd /opt/gamevault-backend
RELEASE=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || echo "main")
echo "${RELEASE}" >/opt/${APP:-gamevault}_version.txt
msg_ok "Cloned GameVault Backend (${RELEASE})"

msg_info "Creating Data Directories"
mkdir -p /opt/gamevault-data/{db,files,media,logs,plugins,config,savefiles}
msg_ok "Created Data Directories"

msg_info "Installing Node Dependencies (this can take a while)"
cd /opt/gamevault-backend
$STD pnpm install --frozen-lockfile
msg_ok "Installed Node Dependencies"

msg_info "Building GameVault"
$STD pnpm run build
msg_ok "Built GameVault"

msg_info "Configuring GameVault"
cat <<EOF >/opt/gamevault-backend/.env
# See https://gamevau.lt/docs/server-docs/configuration for all options
SERVER_PORT=8080

DB_SYSTEM=SQLITE
VOLUMES_SQLITEDB=/opt/gamevault-data/db
VOLUMES_FILES=/opt/gamevault-data/files
VOLUMES_MEDIA=/opt/gamevault-data/media
VOLUMES_LOGS=/opt/gamevault-data/logs
VOLUMES_PLUGINS=/opt/gamevault-data/plugins
VOLUMES_CONFIG=/opt/gamevault-data/config
VOLUMES_SAVEFILES=/opt/gamevault-data/savefiles
EOF
msg_ok "Configured GameVault"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/gamevault.service
[Unit]
Description=GameVault Backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/gamevault-backend
EnvironmentFile=/opt/gamevault-backend/.env
ExecStart=/usr/bin/node /opt/gamevault-backend/dist/src/main
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now gamevault
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
