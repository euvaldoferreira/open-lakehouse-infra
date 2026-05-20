#!/bin/bash
# =============================================================================
# Kafka Topic Initialization - Lakehouse Platform
# Cria todos os topics necessários para a plataforma.
# Executado uma vez após o Kafka iniciar (kafka-init container).
# =============================================================================

set -euo pipefail

BOOTSTRAP="${KAFKA_BOOTSTRAP_SERVERS:-kafka:9092}"
KAFKA_TOPICS="/opt/kafka/bin/kafka-topics.sh --bootstrap-server ${BOOTSTRAP}"

create_topic() {
  local topic="$1"
  local partitions="${2:-3}"
  local retention_ms="${3:-604800000}"   # 7 dias por padrão

  if ${KAFKA_TOPICS} --describe --topic "${topic}" &>/dev/null; then
    echo "[kafka-init] Already exists: ${topic}"
  else
    ${KAFKA_TOPICS} --create \
      --topic "${topic}" \
      --partitions "${partitions}" \
      --replication-factor 1 \
      --config "retention.ms=${retention_ms}"
    echo "[kafka-init] Created: ${topic}"
  fi
}

create_compacted_topic() {
  local topic="$1"
  local partitions="${2:-3}"

  if ${KAFKA_TOPICS} --describe --topic "${topic}" &>/dev/null; then
    echo "[kafka-init] Already exists: ${topic}"
  else
    ${KAFKA_TOPICS} --create \
      --topic "${topic}" \
      --partitions "${partitions}" \
      --replication-factor 1 \
      --config "cleanup.policy=compact" \
      --config "min.compaction.lag.ms=0"
    echo "[kafka-init] Created (compacted): ${topic}"
  fi
}

echo "[kafka-init] ================================================"
echo "[kafka-init] Creating Lakehouse Platform topics..."
echo "[kafka-init] Bootstrap: ${BOOTSTRAP}"
echo "[kafka-init] ================================================"

# --- CDC Topics (Debezium → PostgreSQL) ---
create_topic "cdc.postgres.lakehouse.pipeline_audit"  3  2592000000   # 30 dias
create_topic "cdc.postgres.lakehouse.dq_results"      3  2592000000

# --- Platform Event Topics ---
create_topic "lakehouse.events"            6  604800000   # 7 dias
create_topic "lakehouse.pipeline.status"  3  604800000
create_topic "lakehouse.data.ingestion"   6  259200000   # 3 dias
create_topic "lakehouse.data.errors"      3  2592000000  # 30 dias (erros ficam mais tempo)
create_topic "lakehouse.data.quality"     3  604800000

# --- State Topics (compactados — mantém último valor por chave) ---
create_compacted_topic "lakehouse.entity.state"  3
create_compacted_topic "lakehouse.schema.registry.schemas"  1

echo "[kafka-init] ================================================"
echo "[kafka-init] Topics created successfully:"
${KAFKA_TOPICS} --list
echo "[kafka-init] Done."
