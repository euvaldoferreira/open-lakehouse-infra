# =============================================================================
# Apache Ranger Admin - Docker Image
# Versão: 2.5.0
# Base: Eclipse Temurin JRE 11 (LTS)
# =============================================================================

FROM eclipse-temurin:11-jre-jammy

ARG RANGER_VERSION=2.5.0
ARG POSTGRES_JDBC_VERSION=42.7.3

ENV RANGER_HOME=/opt/ranger-admin \
    RANGER_VERSION=${RANGER_VERSION} \
    JAVA_HOME=/opt/java/openjdk

# Dependências de sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    wget \
    curl \
    netcat-openbsd \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# PostgreSQL JDBC Driver
RUN wget -q \
    "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar" \
    -O /tmp/postgresql.jar

# Ranger Admin binary — baixa do Apache Archive
RUN wget -q \
    "https://archive.apache.org/dist/ranger/${RANGER_VERSION}/ranger-${RANGER_VERSION}-admin.tar.gz" \
    -O /tmp/ranger-admin.tar.gz \
    && tar -xzf /tmp/ranger-admin.tar.gz -C /opt \
    && mv "/opt/ranger-${RANGER_VERSION}-admin" /opt/ranger-admin \
    && mv /tmp/postgresql.jar /opt/ranger-admin/ews/lib/ \
    && rm /tmp/ranger-admin.tar.gz

# Cria usuário/grupo ranger (setup.py precisa deles)
RUN groupadd -f ranger && \
    id -u ranger &>/dev/null || useradd -r -g ranger -d /opt/ranger-admin ranger && \
    chown -R ranger:ranger /opt/ranger-admin

# Scripts e configuração
COPY install.properties /opt/ranger-admin/install.properties
COPY bootstrap.sh /bootstrap.sh
RUN chmod +x /bootstrap.sh

WORKDIR /opt/ranger-admin

EXPOSE 6080

CMD ["/bootstrap.sh"]
