# Domínio ONS — Integração ao Lakehouse Platform

MVP de dados públicos do **Operador Nacional do Sistema Elétrico (ONS)** integrado à plataforma Lakehouse existente.

---

## 1. Análise de Arquitetura

### Componentes reutilizados (sem alteração)

| Componente | Papel no domínio ONS |
|---|---|
| **MinIO** (buckets: raw, bronze, silver, gold) | Armazenamento de todas as camadas sem novos buckets |
| **Apache Iceberg** (catalog hadoop, warehouse s3a://gold/warehouse) | Formato de tabela nas camadas silver e gold |
| **Apache Spark 3.5.1** (cluster existente) | Processamento bronze → silver → gold |
| **Apache Airflow 2.9.1** (LocalExecutor) | Orquestração de todos os DAGs ONS |
| **PostgreSQL 15** (`lakehouse.pipeline_audit`, `lakehouse.dq_results`) | Auditoria de pipelines e resultados de qualidade |
| **Prometheus + Grafana + Loki** | Monitoramento e alertas operacionais |
| **Keycloak + Ranger** | IAM e controle de acesso sem configuração adicional |
| **OpenMetadata** | Catálogo e lineage por auto-discovery dos DAGs e tabelas Iceberg |
| **Trino 443** | Query engine para Superset e exploração ad-hoc |
| **Superset** | Dashboards analíticos via Trino → Iceberg gold |

### Novos componentes

| Componente | Arquivo | Finalidade |
|---|---|---|
| Tabela `lakehouse.ons_checkpoint` | `storage/scripts/init_postgres.sql` | Estado incremental da ingestão |
| DAG 01 – Raw Ingestion | `airflow/dags/ons_dag_01_raw_ingestion.py` | Download incremental da API ONS |
| DAG 02 – Bronze | `airflow/dags/ons_dag_02_bronze_transform.py` | CSV → Parquet tipado |
| DAG 03 – Silver | `airflow/dags/ons_dag_03_silver_transform.py` | Parquet → Iceberg silver via Spark |
| DAG 04 – Quality | `airflow/dags/ons_dag_04_quality_validation.py` | 6 verificações de qualidade |
| DAG 05 – Gold | `airflow/dags/ons_dag_05_gold_processing.py` | Agregações diárias via Spark |
| Spark job silver | `airflow/dags/spark_jobs/ons_silver_transform.py` | Job Spark da camada silver |
| Spark job gold | `airflow/dags/spark_jobs/ons_gold_processing.py` | Job Spark da camada gold |
| Alertas Prometheus | `monitoring/prometheus/ons_alerts.yml` | Alertas de falha e staleness |
| Dashboard Grafana | `monitoring/grafana/provisioning/dashboards/ons_pipeline_dashboard.json` | Monitoramento operacional |

### Modificações em componentes existentes

| Arquivo modificado | Mudança |
|---|---|
| `storage/scripts/init_postgres.sql` | Nova tabela `lakehouse.ons_checkpoint` |
| `monitoring/prometheus/prometheus.yml` | `rule_files` inclui `ons_alerts.yml` |
| `infra/docker-compose.yml` | Volume Prometheus monta `ons_alerts.yml` |
| `monitoring/grafana/provisioning/datasources/datasources.yml` | Novo datasource PostgreSQL para Grafana |

---

## 2. Dataset — ONS Carga Energia Hora

**Fonte pública:** `https://ons-aws-prod-opendata.s3-sa-east-1.amazonaws.com/dataset/carga_energia_hora/{year}/carga_energia_hora_{year}-{month}-{day}.csv`

| Campo CSV | Tipo | Descrição |
|---|---|---|
| `id_subsistema` | STRING | Código do subsistema (SE, S, NE, N) |
| `nom_subsistema` | STRING | Nome (SE/CO, Sul, Nordeste, Norte) |
| `din_instante` | TIMESTAMP | Marca temporal do intervalo de 30 min |
| `val_cargaenergiamwmed` | DOUBLE | Carga em MWmed |

**Frequência:** 48 leituras × 4 subsistemas = 192 registros/dia (mínimo esperado).

---

## 3. Fluxo de Dados (Medallion Architecture)

```
ONS Public API (HTTPS)
        │
        ▼
  raw/ons/carga_energia_hora/year=X/month=X/day=X/*.csv   ← arquivo original
        │
        ▼
bronze/ons/carga_energia_hora/year=X/month=X/day=X/data.parquet
  (Parquet tipado, dropna, ingested_at)
        │
        ├──► DQ Checks (dag_04) → lakehouse.dq_results
        │
        ▼
lakehouse.silver.ons_carga_energia   (Iceberg, particionado por data_referencia)
        │
        ▼
lakehouse.gold.ons_carga_diaria      (Iceberg, agregações diárias por subsistema)
        │
        ▼
  Trino ──► Superset dashboards
```

---

## 4. Ingestão Incremental

A tabela `lakehouse.ons_checkpoint` rastreia a última data ingerida com sucesso por dataset:

```sql
SELECT * FROM lakehouse.ons_checkpoint;
-- dataset              | last_date  | row_count | updated_at
-- carga_energia_hora   | 2024-03-15 | 184       | 2024-03-16 01:05:03
```

A cada execução do `ons_dag_01`:
1. Lê `last_date` do checkpoint
2. Calcula `target_date = last_date + 1 dia`
3. Se `target_date > execution_date`, pula (dados atualizados)
4. Caso contrário, baixa e faz upload do CSV
5. Atualiza o checkpoint **somente após sucesso**

Isso garante:
- **Idempotência:** reexecutar o mesmo dia sobrescreve o arquivo raw
- **Sem lacunas:** falhas não avançam o checkpoint
- **Backfill seguro:** ajuste manual do `last_date` no PostgreSQL

---

## 5. Modelo de Tabelas Iceberg

### silver.ons_carga_energia

```sql
CREATE TABLE lakehouse.silver.ons_carga_energia (
    id_subsistema         STRING    NOT NULL,
    nom_subsistema        STRING,
    din_instante          TIMESTAMP NOT NULL,
    val_cargaenergiamwmed DOUBLE,
    data_referencia       DATE,      -- partição
    ingested_at           TIMESTAMP,
    processed_at          TIMESTAMP
)
USING iceberg
PARTITIONED BY (data_referencia);
```

### gold.ons_carga_diaria

```sql
CREATE TABLE lakehouse.gold.ons_carga_diaria (
    data_referencia  DATE      NOT NULL,  -- partição
    id_subsistema    STRING    NOT NULL,
    nom_subsistema   STRING,
    carga_max_mw     DOUBLE,   -- pico do dia
    carga_min_mw     DOUBLE,   -- vale do dia
    carga_media_mw   DOUBLE,   -- média diária
    carga_total_mwh  DOUBLE,   -- energia integrada (MWmed × 0.5h)
    registros        BIGINT,   -- completude: esperado = 48
    pct_completude   DOUBLE,   -- % de registros recebidos
    processed_at     TIMESTAMP
)
USING iceberg
PARTITIONED BY (data_referencia);
```

---

## 6. Verificações de Qualidade

O DAG 04 executa 6 checks e persiste cada resultado em `lakehouse.dq_results`:

| Check | Tipo | Critério |
|---|---|---|
| `completeness` | hard | ≥ 192 linhas/dia |
| `null_check` | hard | Sem nulls em `id_subsistema` ou `din_instante` |
| `subsystem_set` | warning | Apenas {SE, S, NE, N} |
| `range_check` | warning | 0 ≤ carga ≤ 100 000 MWmed |
| `temporal_order` | warning | Sem timestamps futuros |
| `duplicate_check` | warning | Sem duplicatas em (id_subsistema, din_instante) |

**Falha (hard):** interrompe o pipeline via assert.
**Warning:** registra o problema mas permite continuidade.

---

## 7. Queries de Referência — Trino / Superset

```sql
-- Carga diária do SIN por subsistema (últimos 30 dias)
SELECT data_referencia, id_subsistema, nom_subsistema,
       carga_max_mw, carga_min_mw, carga_media_mw, carga_total_mwh
FROM iceberg.lakehouse.gold.ons_carga_diaria
WHERE data_referencia >= CURRENT_DATE - INTERVAL '30' DAY
ORDER BY data_referencia DESC, id_subsistema;

-- Demanda horária de um dia específico
SELECT id_subsistema, din_instante, val_cargaenergiamwmed
FROM iceberg.lakehouse.silver.ons_carga_energia
WHERE data_referencia = DATE '2024-03-15'
ORDER BY id_subsistema, din_instante;

-- Pico histórico por subsistema
SELECT id_subsistema, MAX(carga_max_mw) AS pico_historico_mw,
       MAX_BY(data_referencia, carga_max_mw) AS data_pico
FROM iceberg.lakehouse.gold.ons_carga_diaria
GROUP BY id_subsistema;

-- Completude da ingestão (últimos 7 dias)
SELECT data_referencia, id_subsistema, registros, pct_completude
FROM iceberg.lakehouse.gold.ons_carga_diaria
WHERE data_referencia >= CURRENT_DATE - INTERVAL '7' DAY
ORDER BY data_referencia DESC, id_subsistema;
```

---

## 8. Monitoramento e Alertas

### Grafana — ONS Pipeline Energético
Acesse: `http://localhost:3000` → Dashboard "ONS — Pipeline Energético"

Painéis:
- Última data ingerida, taxa de aprovação DQ, falhas 24h (stats)
- Registros por camada ao longo do tempo (timeseries)
- Execuções recentes com status (tabela)
- Resultados de qualidade detalhados (tabela)
- Falhas de DAG via Prometheus (timeseries)

### Alertas Prometheus (`ons_alerts.yml`)

| Alerta | Condição | Severidade |
|---|---|---|
| `ONSIngestionFailed` | Falha em qualquer `ons_dag_*` em 2h | warning |
| `ONSIngestionHighFailureRate` | > 3 falhas em 6h | critical |
| `ONSPipelineStaleness` | `ons_dag_01` sem execução há > 25h | warning |
| `ONSAPIUnavailable` | Endpoint ONS inacessível por 10min | warning |

### Loki — logs dos DAGs
Filtro: `{container_name="lakehouse-airflow-scheduler"} |= "ons_dag"`

---

## 9. Governança e Lineage (OpenMetadata)

O OpenMetadata auto-descobre:
- **Airflow pipelines:** via Airflow connector (DAGs com prefixo `ons_`)
- **Tabelas Iceberg:** via Trino connector (namespaces `silver` e `gold`)
- **Lineage automático:** Airflow → MinIO → Iceberg (inferido pelo connector)

Para enriquecer o catálogo manualmente:
1. Acesse OpenMetadata: `http://localhost:8585`
2. Navegue em Data Assets → Tables → `ons_carga_diaria`
3. Adicione descrição, owners (`data-engineering`) e tags (`ons`, `energia`, `pii:false`)

---

## 10. Segurança

Nenhuma configuração adicional de Keycloak ou Ranger é necessária para o MVP:

- Os DAGs herdam as credenciais do Airflow (variáveis de ambiente `.env`)
- As tabelas Iceberg ficam no namespace `lakehouse` já protegido pelo Ranger
- O acesso ao Trino/Superset é controlado pelo Keycloak realm `lakehouse`

Para produção, recomenda-se criar políticas Ranger específicas para o domínio ONS (grupo `ons-readers` com acesso somente-leitura ao namespace `silver` e `gold`).

---

## 11. Como Executar o MVP

### Pré-requisitos
A plataforma deve estar rodando: `cd platform && ./scripts/start.sh`

### Execução manual (backfill de 7 dias)
No Airflow UI (`http://localhost:8080`):
1. Ative o DAG `ons_dag_01_raw_ingestion` → trigger manual
2. Aguarde conclusão → verifique `raw/ons/carga_energia_hora/` no MinIO
3. Ative `ons_dag_02_bronze_transform` → trigger manual
4. Ative `ons_dag_04_quality_validation` → confirme checks passando
5. Ative `ons_dag_03_silver_transform` → aguarde job Spark
6. Ative `ons_dag_05_gold_processing` → aguarde job Spark
7. Consulte dados via Trino: `SELECT * FROM iceberg.lakehouse.gold.ons_carga_diaria LIMIT 10`

### Verificar checkpoint
```sql
-- No Airflow (via conexão postgres) ou psql:
SELECT * FROM lakehouse.ons_checkpoint;
SELECT * FROM lakehouse.pipeline_audit WHERE dag_id LIKE 'ons_%' ORDER BY started_at DESC LIMIT 10;
SELECT * FROM lakehouse.dq_results WHERE dag_id LIKE 'ons_%' ORDER BY created_at DESC LIMIT 20;
```

---

## 12. Trade-offs e Decisões Arquiteturais

| Decisão | Alternativa considerada | Razão da escolha |
|---|---|---|
| Usar `@daily` com checkpoint PostgreSQL | Airflow `catchup=True` nativo | Controle explícito de estado; evita reprocessamento acidental em backfills longos |
| Dataset único (`carga_energia_hora`) no MVP | Múltiplos datasets ONS | Minimiza risco de entrega; `geracao_sin_hora` pode ser adicionado como segundo DAG sem alterar infraestrutura |
| Bronze como Parquet (não Iceberg) | Iceberg desde o bronze | Consistência com padrão da plataforma; bronze é landing zone volátil |
| Gold com `overwritePartitions()` | MERGE INTO (upsert) | ONS publica dados corrigidos retroativamente; reprocessar a partição inteira é mais simples e seguro |
| Grafana com PostgreSQL datasource | Grafana com Trino | PostgreSQL já existe; evita instalar plugin adicional no Grafana |

---

## 13. Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| API ONS fora do ar | Média | Alto | Retry (3×) no DAG 01; alerta `ONSAPIUnavailable` |
| Mudança no schema CSV do ONS | Baixa | Alto | Validação de colunas obrigatórias no DAG 02 + alerta de falha |
| Dados retroativos (ONS publica revisões) | Alta | Médio | `overwritePartitions()` garante idempotência |
| Crescimento de storage | Baixa | Baixo | MinIO versioning ativo; Iceberg table expiration configurável |
| Latência do job Spark | Baixa | Baixo | Jobs leves (< 200 linhas CSV/dia); 1 worker Spark é suficiente |

---

## 14. Impactos Arquiteturais

- **Nenhum novo serviço** foi adicionado à plataforma
- **Nenhuma porta nova** foi exposta
- **Nenhuma dependência nova** nas camadas de orquestração e processamento
- **PostgreSQL datasource no Grafana** amplia as capacidades de todos os futuros domínios
- O padrão de checkpoint pode ser **replicado para outros domínios** (ANEEL, IBGE, etc.)
- Os namespaces Iceberg `silver.ons_*` e `gold.ons_*` ficam isolados dos dados de vendas existentes
