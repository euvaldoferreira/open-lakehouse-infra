#!/bin/sh
# =============================================================================
# Debezium Connector Registration
# Registra todos os conectores .json em /connectors/ via REST API.
# Executado uma vez após o Debezium/Kafka Connect iniciar.
# =============================================================================

set -e

DEBEZIUM_URL="${DEBEZIUM_URL:-http://debezium:8083}"
CONNECTORS_DIR="/connectors"

echo "[debezium-init] Debezium URL: ${DEBEZIUM_URL}"
echo "[debezium-init] Registering connectors from: ${CONNECTORS_DIR}"

for connector_file in "${CONNECTORS_DIR}"/*.json; do
  [ -f "${connector_file}" ] || continue
  connector_name=$(basename "${connector_file}" .json)

  echo "[debezium-init] Checking connector: ${connector_name}"

  # Verifica se já existe
  existing=$(curl -sf "${DEBEZIUM_URL}/connectors/${connector_name}" 2>/dev/null && echo "exists" || echo "new")

  if [ "${existing}" = "exists" ]; then
    echo "[debezium-init] Updating existing connector: ${connector_name}"
    curl -sf -X PUT "${DEBEZIUM_URL}/connectors/${connector_name}/config" \
      -H "Content-Type: application/json" \
      -d "$(cat "${connector_file}" | sed 's/^{"name":[^,]*,//' | sed 's/"config"://' | sed 's/}$//')" \
      && echo "[debezium-init] Updated: ${connector_name}" \
      || echo "[debezium-init] WARNING: Failed to update ${connector_name}"
  else
    echo "[debezium-init] Registering new connector: ${connector_name}"
    curl -sf -X POST "${DEBEZIUM_URL}/connectors" \
      -H "Content-Type: application/json" \
      -d "@${connector_file}" \
      && echo "[debezium-init] Registered: ${connector_name}" \
      || echo "[debezium-init] WARNING: Failed to register ${connector_name}"
  fi
done

echo ""
echo "[debezium-init] Active connectors:"
curl -sf "${DEBEZIUM_URL}/connectors?expand=status" | tr ',' '\n' | grep '"name"' || true
echo ""
echo "[debezium-init] Done."
