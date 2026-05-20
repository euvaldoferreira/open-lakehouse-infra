#!/bin/bash
# =============================================================================
# Hive Metastore Entrypoint
# Initializes HMS schema on first run, then starts the Thrift service.
# =============================================================================

set -e

echo "[hms] Checking metastore schema in PostgreSQL..."
if ! schematool -dbType postgres -info > /dev/null 2>&1; then
    echo "[hms] Schema not found — initializing..."
    schematool -dbType postgres -initSchema
    echo "[hms] Schema initialized."
else
    echo "[hms] Schema already exists."
fi

echo "[hms] Starting Hive Metastore on port 9083..."
exec hive --service metastore
