#!/bin/bash
# =============================================================================
# Stop Lakehouse Platform
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/../infra"

cd "${INFRA_DIR}"

COMPOSE_CMD="docker compose"

echo "Stopping Lakehouse Platform..."
${COMPOSE_CMD} down

echo "Platform stopped. Volumes are preserved."
echo "To remove all data: docker compose down -v"
