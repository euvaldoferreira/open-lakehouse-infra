-- =============================================================================
-- PostgreSQL Initialization - Lakehouse Platform
-- =============================================================================

-- Create schema for operational tables (Airflow uses public by default)
CREATE SCHEMA IF NOT EXISTS lakehouse;

-- Audit log table for pipeline runs
CREATE TABLE IF NOT EXISTS lakehouse.pipeline_audit (
    id          BIGSERIAL PRIMARY KEY,
    dag_id      VARCHAR(250) NOT NULL,
    run_id      VARCHAR(250) NOT NULL,
    layer       VARCHAR(50)  NOT NULL,
    status      VARCHAR(50)  NOT NULL,
    row_count   BIGINT,
    started_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMP,
    notes       TEXT
);

-- Data quality results
CREATE TABLE IF NOT EXISTS lakehouse.dq_results (
    id           BIGSERIAL PRIMARY KEY,
    dag_id       VARCHAR(250) NOT NULL,
    run_date     DATE         NOT NULL,
    layer        VARCHAR(50)  NOT NULL,
    check_name   VARCHAR(250) NOT NULL,
    status       VARCHAR(50)  NOT NULL,
    issue_count  INTEGER      DEFAULT 0,
    details      JSONB,
    created_at   TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dq_results_run_date ON lakehouse.dq_results (run_date);
CREATE INDEX IF NOT EXISTS idx_pipeline_audit_dag  ON lakehouse.pipeline_audit (dag_id, started_at);

-- =============================================================================
-- Generic incremental ingestion checkpoint (all domains)
-- Tracks the last successfully processed date per dataset so DAGs can resume
-- without reprocessing data already in the lakehouse.
-- Key: dataset (e.g. "balanco_energia_subsistema_ho", "aneel_tarifas", ...)
-- =============================================================================
CREATE TABLE IF NOT EXISTS lakehouse.pipeline_checkpoint (
    dataset       VARCHAR(200) NOT NULL,
    dag_id        VARCHAR(250) NOT NULL,
    partition_key VARCHAR(50)  NOT NULL,  -- granularity defined by the domain: "2024", "2024-01", "2024-01-15"
    last_date     DATE         NOT NULL,
    row_count     BIGINT,
    updated_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    PRIMARY KEY (dataset, dag_id, partition_key)
);

-- Grant access to airflow user
GRANT USAGE ON SCHEMA lakehouse TO airflow_user;
GRANT ALL ON ALL TABLES IN SCHEMA lakehouse TO airflow_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA lakehouse TO airflow_user;
