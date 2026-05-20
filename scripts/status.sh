#!/bin/bash
# Show platform status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/../infra"

COMPOSE_CMD="docker compose"

echo "============================================="
echo " Lakehouse Platform - Service Status"
echo "============================================="
${COMPOSE_CMD} ps

echo ""
echo "--- Docker Stats (snapshot) ---"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
    2>/dev/null | grep -i lakehouse || echo "(no running containers)"
