#!/usr/bin/env bash

# ------------------------------------------------------------------
# This app isn't part of the official community-scripts/ProxmoxVE repo,
# so build.func's built-in install-script fetch (which is hardcoded to
# raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/)
# would 404 on gamevault-install.sh. We patch just that one URL to
# point at YOUR fork/repo, and leave every other framework file
# (core.func, tools.func, install.func, ...) pointed at upstream so
# you keep getting upstream fixes for free.
#
# >>> Set these two to where you've pushed ct/ and install/ <<<
GH_USER="MrCraigen"
GH_REPO="ProxmoxVE"
GH_BRANCH="main"

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func | \
  sed "s#https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/#https://raw.githubusercontent.com/${GH_USER}/${GH_REPO}/${GH_BRANCH}/install/#g")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: (your name)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://gamevau.lt/ | Github: https://github.com/Phalcode/gamevault-backend

APP="GameVault"
var_tags="${var_tags:-gaming}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-16}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
var_arm64="${var_arm64:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/gamevault-backend ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Stopping ${APP}"
  systemctl stop gamevault
  msg_ok "Stopped ${APP}"

  msg_info "Updating ${APP} (this can take a while on first build)"
  cd /opt/gamevault-backend
  git fetch --all --tags --prune >/dev/null 2>&1
  git pull
  $STD pnpm install --frozen-lockfile
  $STD pnpm run build
  msg_ok "Updated ${APP}"

  msg_info "Starting ${APP}"
  systemctl start gamevault
  msg_ok "Started ${APP}"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
