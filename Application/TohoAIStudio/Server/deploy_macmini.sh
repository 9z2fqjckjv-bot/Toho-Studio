#!/usr/bin/env bash
set -euo pipefail

# TohoAIStudio V3.0 Gateway Server - MacMini (debian.local) 自動デプロイスクリプト
REMOTE_HOST="${1:-macmini}"
REMOTE_DIR="/opt/tohostudio-llm-gateway"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== [1/4] MacMini (${REMOTE_HOST}) 上にディレクトリを準備 ==="
ssh "${REMOTE_HOST}" "sudo mkdir -p ${REMOTE_DIR}/data && sudo chown -R \$(whoami):\$(whoami) ${REMOTE_DIR}"

echo "=== [2/4] ゲートウェイサーバコードを転送 ==="
scp "${SCRIPT_DIR}/pricing_plans.py" \
    "${SCRIPT_DIR}/gateway_server.py" \
    "${SCRIPT_DIR}/admin_cli.py" \
    "${SCRIPT_DIR}/requirements.txt" \
    "${REMOTE_HOST}:${REMOTE_DIR}/"

echo "=== [3/4] Python 仮想環境・環境変数・systemd サービスを構成 ==="
ssh "${REMOTE_HOST}" "bash -s" <<'EOF'
set -euo pipefail
REMOTE_DIR="/opt/tohostudio-llm-gateway"

if [ ! -d "${REMOTE_DIR}/venv" ]; then
    python3 -m venv "${REMOTE_DIR}/venv"
fi
"${REMOTE_DIR}/venv/bin/pip" install --quiet --upgrade pip
"${REMOTE_DIR}/venv/bin/pip" install --quiet -r "${REMOTE_DIR}/requirements.txt"

if [ ! -f "${REMOTE_DIR}/.env" ]; then
    cat << 'ENVEOF' > "${REMOTE_DIR}/.env"
TOHO_GATEWAY_PORT=8095
OLLAMA_BASE_URL=http://127.0.0.1:11434
DEFAULT_LOCAL_MODEL=qwen2.5:3b
TOHO_ADMIN_TOKEN=toho-nanndemoya-admin-2026
# 「何でも屋」側で管理するマスターAPIキー（設定すると定額プラン上位推論およびNanndemoyaAPIで自動利用されます）
GEMINI_API_KEY=
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
DEEPSEEK_API_KEY=
XAI_API_KEY=
MISTRAL_API_KEY=
OPENROUTER_API_KEY=
ENVEOF
    chmod 600 "${REMOTE_DIR}/.env"
fi

SERVICE_USER="$(whoami)"
sudo chown -R "${SERVICE_USER}:${SERVICE_USER}" "${REMOTE_DIR}"

sudo tee /etc/systemd/system/tohostudio-llm-gateway.service >/dev/null << SVCEOF
[Unit]
Description=TohoAIStudio V3.0 Public LLM & Quota Gateway
After=network.target ollama.service

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=/opt/tohostudio-llm-gateway
EnvironmentFile=/opt/tohostudio-llm-gateway/.env
ExecStart=/opt/tohostudio-llm-gateway/venv/bin/python3 /opt/tohostudio-llm-gateway/gateway_server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable tohostudio-llm-gateway.service
sudo systemctl restart tohostudio-llm-gateway.service
for i in {1..10}; do
    curl -fsS http://127.0.0.1:8095/health >/dev/null 2>&1 && break
    sleep 1
done
sudo systemctl status tohostudio-llm-gateway.service --no-pager | head -n 15
EOF

echo "=== [4/4] ヘルスチェック確認 ==="
ssh "${REMOTE_HOST}" "curl -fsS http://127.0.0.1:8095/health && echo ''"
