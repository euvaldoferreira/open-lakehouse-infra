#!/usr/bin/env bash
# =============================================================================
# setup-repos.sh — Monta o ambiente multi-repo do Lakehouse
#
# Clona open_lakehouse_pipelines no diretório correto
# e atualiza infra/.env com o caminho absoluto.
#
# Uso:
#   ./scripts/setup-repos.sh
#
# Variáveis de ambiente opcionais (sobrepõem os defaults abaixo):
#   PIPELINES_REPO_URL  — URL SSH ou HTTPS do repo
#   PIPELINES_REPO_DIR  — Onde clonar (default: ../lakehouse-pipelines)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$PLATFORM_DIR")"
ENV_FILE="$PLATFORM_DIR/infra/.env"

# --- Defaults ---
PIPELINES_REPO_URL="${PIPELINES_REPO_URL:-git@github.com:euvaldoferreira/open-lakehouse-pipelines.git}"
PIPELINES_REPO_DIR="${PIPELINES_REPO_DIR:-$PARENT_DIR/lakehouse-pipelines}"

echo "============================================="
echo " Lakehouse — Multi-Repo Setup"
echo "============================================="
echo " PIPELINES_REPO → $PIPELINES_REPO_DIR"
echo ""

# --- Clone ou atualiza open_lakehouse_pipelines ---
if [ -d "$PIPELINES_REPO_DIR/.git" ]; then
    echo "[lakehouse-pipelines] já existe — atualizando..."
    git -C "$PIPELINES_REPO_DIR" pull --ff-only
else
    echo "[lakehouse-pipelines] clonando de $PIPELINES_REPO_URL..."
    git clone "$PIPELINES_REPO_URL" "$PIPELINES_REPO_DIR"
fi

# --- Atualiza infra/.env com caminho absoluto ---
if [ ! -f "$ENV_FILE" ]; then
    echo ""
    echo "AVISO: $ENV_FILE não encontrado."
    echo "Copie infra/.env.example para infra/.env e execute novamente."
    exit 1
fi

_set_env() {
    local key="$1" val="$2"
    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
    else
        echo "${key}=${val}" >> "$ENV_FILE"
    fi
}

_set_env "PIPELINES_REPO" "$PIPELINES_REPO_DIR"

echo ""
echo "infra/.env atualizado:"
echo "  PIPELINES_REPO=$PIPELINES_REPO_DIR"
echo ""
echo "Próximo passo:"
echo "  cd infra && docker compose up -d"
echo "============================================="
