#!/bin/bash
# ChameleonPiP Global Arena Server — One-Click Remote SSH Deployment Script
# Usage:
#   ./server/deploy.sh <user@your-server> [ssh_key_path] [public_tunnel_url]

set -euo pipefail

if [ $# -lt 1 ] && [ -z "${CHAMELEON_SSH_TARGET:-}" ]; then
  echo "Usage: ./server/deploy.sh <user@server> [ssh_key_path] [public_url]"
  exit 1
fi

TARGET="${1:-$CHAMELEON_SSH_TARGET}"
SSH_KEY="${2:-${CHAMELEON_SSH_KEY:-}}"
PUBLIC_URL="${3:-https://passenger-leave-merger-permission.trycloudflare.com}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SSH_OPTS=()
if [ -n "$SSH_KEY" ] && [ -f "$SSH_KEY" ]; then
  SSH_OPTS=(-i "$SSH_KEY")
fi

echo "🚀 [1/3] 正在同步服务端与静态站点至远端服务器 ..."
ssh "${SSH_OPTS[@]}" "$TARGET" "sudo mkdir -p /opt/chameleon-arena/data /var/www/chameleon-arena/extension/icons /var/www/chameleon-arena/demo && sudo chown -R \$(whoami):\$(whoami) /opt/chameleon-arena /var/www/chameleon-arena"

scp "${SSH_OPTS[@]}" \
  "$ROOT_DIR/server/arena-server.js" \
  "$ROOT_DIR/server/package.json" \
  "$ROOT_DIR/server/Dockerfile" \
  "$TARGET:/opt/chameleon-arena/"

scp "${SSH_OPTS[@]}" \
  "$ROOT_DIR/demo/index.html" \
  "$ROOT_DIR/demo/arena.html" \
  "$TARGET:/var/www/chameleon-arena/"

scp "${SSH_OPTS[@]}" \
  "$ROOT_DIR/demo/index.html" \
  "$ROOT_DIR/demo/arena.html" \
  "$TARGET:/var/www/chameleon-arena/demo/"

scp "${SSH_OPTS[@]}" \
  "$ROOT_DIR/extension/gecko-core.js" \
  "$ROOT_DIR/extension/chameleon-stats.js" \
  "$TARGET:/var/www/chameleon-arena/extension/"

scp "${SSH_OPTS[@]}" \
  "$ROOT_DIR/extension/icons/"*.png \
  "$TARGET:/var/www/chameleon-arena/extension/icons/"

echo "⚙️ [2/3] 正在重启远端 chameleon-arena.service 守护进程 ..."
ssh "${SSH_OPTS[@]}" "$TARGET" "sudo systemctl restart chameleon-arena.service && sudo systemctl is-active chameleon-arena.service"

echo "🔨 [3/3] 正在同步并重新编译本地客户端 ..."
"$ROOT_DIR/macos-ghost/build.sh"

echo "✅ 部署完成！Cloudflare 加密隧道已在线: ${PUBLIC_URL}/api/health"
