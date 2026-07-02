#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/MrCraigen/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrCraigen
# License: MIT | https://github.com/MrCraigen/ProxmoxVE/raw/main/LICENSE
# Source: https://honcho.dev/ | Github: https://github.com/plastic-labs/honcho

APP="Honcho"
var_tags="${var_tags:-ai}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-10}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/honcho ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "honcho" "plastic-labs/honcho"; then
    msg_info "Stopping Services"
    systemctl stop honcho honcho-deriver
    msg_ok "Stopped Services"

    fetch_and_deploy_gh_release "honcho" "plastic-labs/honcho" "tarball"

    msg_info "Updating ${APP}"
    cd /opt/honcho
    $STD uv sync
    $STD uv run alembic upgrade head
    msg_ok "Updated ${APP}"

    msg_info "Starting Services"
    systemctl start honcho honcho-deriver
    msg_ok "Started Services"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Add your LLM provider API key(s) to /opt/honcho/.env, then restart the services:${CL}"
echo -e "${TAB}${YW}systemctl restart honcho honcho-deriver${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8000${CL}"
