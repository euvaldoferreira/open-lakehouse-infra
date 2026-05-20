#!/bin/bash
# =============================================================================
# PostgreSQL Extra Init - Lakehouse Platform
# Creates users and databases for HMS, Superset, and OpenMetadata.
# Runs AFTER init.sql (alphabetical order: init.sql < init_extra.sh).
# CREATE DATABASE cannot run inside a transaction, so we use psql -c calls.
# =============================================================================

set -e

echo "[init_extra] Creating application users..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "CREATE USER hive_user          WITH PASSWORD 'hive_pass_2024';" \
    -c "CREATE USER superset_user      WITH PASSWORD 'superset_pass_2024';" \
    -c "CREATE USER openmetadata_user  WITH PASSWORD 'openmetadata_pass_2024';" \
    -c "CREATE USER keycloak_user      WITH PASSWORD 'keycloak_pass_2024';" \
    -c "CREATE USER ranger_user        WITH PASSWORD 'ranger_pass_2024';" \
    -c "CREATE USER debezium_user      WITH PASSWORD 'debezium_pass_2024' REPLICATION;"

echo "[init_extra] Creating application databases..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "CREATE DATABASE hive_metastore_db  OWNER hive_user;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "CREATE DATABASE superset_db        OWNER superset_user;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "CREATE DATABASE openmetadata_db    OWNER openmetadata_user;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "CREATE DATABASE keycloak_db        OWNER keycloak_user;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "CREATE DATABASE ranger_db          OWNER ranger_user;"

echo "[init_extra] Enabling uuid-ossp extension in openmetadata_db..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "openmetadata_db" \
    -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"

echo "[init_extra] Granting debezium_user SELECT on lakehouse schema..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO debezium_user;" \
    -c "GRANT USAGE ON SCHEMA lakehouse TO debezium_user;" \
    -c "GRANT SELECT ON ALL TABLES IN SCHEMA lakehouse TO debezium_user;" \
    -c "ALTER DEFAULT PRIVILEGES IN SCHEMA lakehouse GRANT SELECT ON TABLES TO debezium_user;"

echo "[init_extra] Done."
