FROM apache/superset:3.1.3

USER root

# Trino SQLAlchemy driver for connecting Superset → Trino
RUN pip install --no-cache-dir "trino[sqlalchemy]"

USER superset
