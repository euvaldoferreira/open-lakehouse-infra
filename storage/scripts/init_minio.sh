#!/bin/sh
# =============================================================================
# MinIO Initialization Script
# Creates buckets, sets versioning, and configures policies
# =============================================================================

set -e

MINIO_ALIAS="local"
MC="mc"

echo ">>> Waiting for MinIO to be ready..."
until $MC alias set "${MINIO_ALIAS}" "http://minio:9000" "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" 2>/dev/null; do
    echo "MinIO not ready, retrying in 3s..."
    sleep 3
done

echo ">>> MinIO is ready. Creating buckets..."

BUCKETS="raw bronze silver gold checkpoints logs temp"

for bucket in $BUCKETS; do
    if $MC ls "${MINIO_ALIAS}/${bucket}" > /dev/null 2>&1; then
        echo "  [SKIP] Bucket '${bucket}' already exists."
    else
        $MC mb "${MINIO_ALIAS}/${bucket}"
        echo "  [OK] Created bucket: ${bucket}"
    fi
done

echo ">>> Enabling versioning on key buckets..."
for bucket in raw bronze silver gold; do
    $MC version enable "${MINIO_ALIAS}/${bucket}"
    echo "  [OK] Versioning enabled: ${bucket}"
done

echo ">>> Setting bucket policies..."

$MC anonymous set none "${MINIO_ALIAS}/raw"
$MC anonymous set none "${MINIO_ALIAS}/bronze"
$MC anonymous set none "${MINIO_ALIAS}/silver"
$MC anonymous set none "${MINIO_ALIAS}/gold"
$MC anonymous set none "${MINIO_ALIAS}/checkpoints"

echo ">>> Creating folder structure placeholders..."
for bucket in raw bronze silver gold checkpoints logs temp; do
    echo -n "" | $MC pipe "${MINIO_ALIAS}/${bucket}/.keep"
    echo "  [OK] Placeholder created: ${bucket}/.keep"
done

echo ">>> MinIO initialization complete!"
echo "    Buckets: ${BUCKETS}"
