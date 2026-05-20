#!/bin/bash
# =============================================================================
# Apache Ranger Admin - Bootstrap Script
# 1. Aguarda PostgreSQL e Solr ficarem disponíveis
# 2. Na primeira execução: substitui placeholders e roda setup.py
# 3. Inicia o Ranger Admin e mantém o container vivo via log tail
# =============================================================================

set -euo pipefail

INSTALLED_MARKER="/opt/ranger-admin/.installed"
RANGER_HOME="/opt/ranger-admin"
LOG_DIR="${RANGER_HOME}/ews/logs"

log() { echo "[Ranger] $(date '+%H:%M:%S') $*"; }

# ---------------------------------------------------------------------------
# 1. Aguardar dependências
# ---------------------------------------------------------------------------

log "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_ROOT_USER}" -q; do
  log "PostgreSQL not ready — retrying in 5s..."
  sleep 5
done
log "PostgreSQL is ready."

log "Waiting for Solr at ${AUDIT_SOLR_HOST}:${AUDIT_SOLR_PORT}..."
until curl -sf "http://${AUDIT_SOLR_HOST}:${AUDIT_SOLR_PORT}/solr/" > /dev/null; do
  log "Solr not ready — retrying in 5s..."
  sleep 5
done
log "Solr is ready."

# ---------------------------------------------------------------------------
# 2. Primeiro boot: configurar e instalar
# ---------------------------------------------------------------------------

if [ ! -f "${INSTALLED_MARKER}" ]; then
  log "First boot — running Ranger Admin setup..."

  # Substituir placeholders no install.properties
  sed -i \
    -e "s|{{DB_ROOT_USER}}|${DB_ROOT_USER}|g" \
    -e "s|{{DB_ROOT_PASSWORD}}|${DB_ROOT_PASSWORD}|g" \
    -e "s|{{DB_HOST}}|${DB_HOST}|g" \
    -e "s|{{DB_PORT}}|${DB_PORT}|g" \
    -e "s|{{DB_NAME}}|${DB_NAME}|g" \
    -e "s|{{DB_USER}}|${DB_USER}|g" \
    -e "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g" \
    -e "s|{{RANGER_ADMIN_USER}}|${RANGER_ADMIN_USER}|g" \
    -e "s|{{RANGER_ADMIN_PASSWORD}}|${RANGER_ADMIN_PASSWORD}|g" \
    -e "s|{{AUDIT_SOLR_HOST}}|${AUDIT_SOLR_HOST}|g" \
    -e "s|{{AUDIT_SOLR_PORT}}|${AUDIT_SOLR_PORT}|g" \
    -e "s|{{POLICY_MGR_URL}}|${POLICY_MGR_URL}|g" \
    "${RANGER_HOME}/install.properties"

  log "Running setup.py..."
  cd "${RANGER_HOME}"
  python3 setup.py

  touch "${INSTALLED_MARKER}"
  log "Setup complete."
fi

# ---------------------------------------------------------------------------
# 3. Iniciar Ranger Admin
# ---------------------------------------------------------------------------

mkdir -p "${LOG_DIR}"

log "Starting Ranger Admin..."
"${RANGER_HOME}/ews/ranger-admin-services.sh" start

log "Ranger Admin started. Port: 6080"
log "Web UI: http://ranger-admin:6080"

# Mantém o container vivo via tail de logs
exec tail -f "${LOG_DIR}"/*.log 2>/dev/null || \
  exec tail -f /dev/null
