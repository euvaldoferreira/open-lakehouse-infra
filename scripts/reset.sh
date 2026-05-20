#!/bin/bash
# =============================================================================
# Reset Lakehouse Platform (removes all volumes and data)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/../infra"

cd "${INFRA_DIR}"

COMPOSE_CMD="docker compose"

echo "WARNING: This will destroy ALL data (volumes, MinIO data, PostgreSQL)."
read -r -p "Are you sure? Type 'yes' to confirm: " confirm

if [ "${confirm}" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

${COMPOSE_CMD} down -v --remove-orphans
echo "All containers and volumes removed. Platform reset complete."
