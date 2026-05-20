#!/bin/bash
# =============================================================================
# Superset Init (one-shot)
# Runs DB migrations, creates admin user, initializes roles.
# =============================================================================

set -e

echo "[superset-init] Running database migrations..."
superset db upgrade

echo "[superset-init] Creating admin user..."
superset fab create-admin \
    --username  "${SUPERSET_ADMIN_USER}" \
    --firstname Admin \
    --lastname  User \
    --email     "${SUPERSET_ADMIN_EMAIL}" \
    --password  "${SUPERSET_ADMIN_PASSWORD}" || true

echo "[superset-init] Initializing roles and permissions..."
superset init

echo "[superset-init] Done."
