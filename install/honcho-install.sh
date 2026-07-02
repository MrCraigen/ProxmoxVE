#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: MrCraigen
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://honcho.dev/ | Github: https://github.com/plastic-labs/honcho

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

PG_VERSION="17" PG_MODULES="pgvector" setup_postgresql
PG_DB_NAME="honcho" PG_DB_USER="honcho" PG_DB_EXTENSIONS="vector" setup_postgresql_db
setup_uv

fetch_and_deploy_gh_release "honcho" "plastic-labs/honcho" "tarball"

msg_info "Installing Honcho (Patience)"
cd /opt/honcho
$STD uv sync
msg_ok "Installed Honcho"

msg_info "Configuring Honcho"
cat <<EOF >/opt/honcho/.env
DB_CONNECTION_URI=postgresql+psycopg://${PG_DB_USER}:${PG_DB_PASS}@localhost:5432/${PG_DB_NAME}
AUTH_USE_AUTH=false
SENTRY_ENABLED=false

# LLM Provider API Keys - add at least one, then run: systemctl restart honcho honcho-deriver
LLM_GEMINI_API_KEY=
LLM_ANTHROPIC_API_KEY=
LLM_OPENAI_API_KEY=
EOF
$STD uv run alembic upgrade head
msg_ok "Configured Honcho"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/honcho.service
[Unit]
Description=Honcho API Server
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
WorkingDirectory=/opt/honcho
ExecStart=/opt/honcho/.venv/bin/python -m uvicorn src.main:app --host 0.0.0.0 --port 8000
Restart=on-failure
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/honcho-deriver.service
[Unit]
Description=Honcho Deriver (Background Worker)
After=network.target postgresql.service honcho.service
Requires=postgresql.service

[Service]
Type=simple
WorkingDirectory=/opt/honcho
ExecStart=/opt/honcho/.venv/bin/python -m src.deriver
Restart=on-failure
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now honcho honcho-deriver
msg_ok "Created Services"

motd_ssh
customize
cleanup_lxc
