#!/bin/bash
# =============================================================================
# Start Lakehouse Platform
#
# Uso:
#   ./start.sh                  → stack base (Airflow, Spark, MinIO, Trino…)
#   ./start.sh --streaming      → base + Kafka KRaft + Debezium
#   ./start.sh --security       → base + Keycloak + Ranger + Solr
#   ./start.sh --all            → tudo
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/../infra"

cd "${INFRA_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')] $*${NC}"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $*${NC}"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $*${NC}"; exit 1; }
info()  { echo -e "${CYAN}[$(date '+%H:%M:%S')] $*${NC}"; }

# --- Parse argumentos ---
ENABLE_STREAMING=false
ENABLE_SECURITY=false

for arg in "$@"; do
  case "$arg" in
    --streaming) ENABLE_STREAMING=true ;;
    --security)  ENABLE_SECURITY=true  ;;
    --all)       ENABLE_STREAMING=true; ENABLE_SECURITY=true ;;
    *)           warn "Argumento desconhecido: $arg" ;;
  esac
done

# --- Monta lista de arquivos compose ---
COMPOSE_FILES="-f docker-compose.yml"
[[ "${ENABLE_STREAMING}" == "true" ]] && COMPOSE_FILES="${COMPOSE_FILES} -f docker-compose.streaming.yml"
[[ "${ENABLE_SECURITY}"  == "true" ]] && COMPOSE_FILES="${COMPOSE_FILES} -f docker-compose.security.yml"

# --- Pre-flight checks ---
command -v docker >/dev/null 2>&1 || error "Docker is not installed."
docker compose version >/dev/null 2>&1 || error "Docker Compose plugin is not installed."

if [ ! -f ".env" ]; then
  warn ".env file not found. Copying from .env.example..."
  cp .env.example .env
  warn "Please edit .env with your actual credentials before production use."
fi

# --- Generate Fernet key if not set ---
if grep -q "your-fernet-key-here-generate-with-python" .env 2>/dev/null; then
  log "Generating Fernet key..."
  FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || \
               docker run --rm python:3.11-alpine python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
  sed -i "s|your-fernet-key-here-generate-with-python|${FERNET_KEY}|g" .env
  log "Fernet key generated and saved."
fi

if grep -q "your-webserver-secret-key-here" .env 2>/dev/null; then
  SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || openssl rand -hex 32)
  sed -i "s|your-webserver-secret-key-here|${SECRET_KEY}|g" .env
fi

# --- Info sobre stacks selecionadas ---
log ""
log "========================================="
log " Lakehouse Platform — Starting"
log "========================================="
info " Compose files: ${COMPOSE_FILES}"
[[ "${ENABLE_STREAMING}" == "true" ]] && info " ✓ Stack Streaming habilitada (Kafka + Debezium)"
[[ "${ENABLE_SECURITY}"  == "true" ]] && info " ✓ Stack Security habilitada (Keycloak + Ranger)"
log ""

COMPOSE_CMD="docker compose ${COMPOSE_FILES}"

log "Phase 1: Infrastructure (PostgreSQL + MinIO)..."
${COMPOSE_CMD} up -d postgres minio

log "Waiting for PostgreSQL and MinIO to be healthy..."
sleep 10

log "Phase 2: MinIO bucket initialization..."
${COMPOSE_CMD} up --build minio-init
${COMPOSE_CMD} wait minio-init || true

log "Phase 3: Airflow initialization..."
${COMPOSE_CMD} up --build airflow-init
${COMPOSE_CMD} wait airflow-init || true

log "Phase 4: Starting all services..."
${COMPOSE_CMD} up -d --build

log ""
log "========================================="
log " Lakehouse Platform is starting up!"
log " (aguarde 2-3 minutos para full startup)"
log "========================================="
log ""
log " --- Stack Base ---"
log "  Airflow UI    -> http://localhost:8080"
log "  JupyterLab    -> http://localhost:8888"
log "  Spark UI      -> http://localhost:8081"
log "  Trino         -> http://localhost:8084"
log "  Superset      -> http://localhost:8088"
log "  MinIO Console -> http://localhost:9001"
log "  Grafana       -> http://localhost:3000"
log "  OpenMetadata  -> http://localhost:8585"

if [[ "${ENABLE_STREAMING}" == "true" ]]; then
  log ""
  log " --- Stack Streaming ---"
  log "  Kafka UI      -> http://localhost:8090"
  log "  Debezium REST -> http://localhost:8083"
  log "  Kafka broker  -> localhost:29092"
fi

if [[ "${ENABLE_SECURITY}" == "true" ]]; then
  log ""
  log " --- Stack Security ---"
  log "  Keycloak      -> http://localhost:8180"
  log "  Ranger Admin  -> http://localhost:6080"
  log "  Solr          -> http://localhost:8983"
fi

log ""
log "  Run 'docker compose ps' to check status"
log ""
