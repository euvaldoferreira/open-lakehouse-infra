FROM apache/airflow:2.9.1-python3.11

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    curl \
    openjdk-17-jre-headless \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

USER airflow

COPY requirements.txt /tmp/airflow-requirements.txt
COPY webserver_config.py /opt/airflow/webserver_config.py

RUN pip install --no-cache-dir -r /tmp/airflow-requirements.txt
