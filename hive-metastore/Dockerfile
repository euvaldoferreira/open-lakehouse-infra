FROM apache/hive:4.0.0

USER root

# PostgreSQL JDBC driver + S3A JARs for MinIO access
RUN apt-get update && apt-get install -y --no-install-recommends curl netcat-openbsd && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fL "https://jdbc.postgresql.org/download/postgresql-42.7.3.jar" \
        -o /opt/hive/lib/postgresql-42.7.3.jar && \
    curl -fL "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" \
        -o /opt/hive/lib/hadoop-aws-3.3.4.jar && \
    curl -fL "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" \
        -o /opt/hive/lib/aws-java-sdk-bundle-1.12.262.jar

COPY hive-site.xml /opt/hive/conf/hive-site.xml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER hive

EXPOSE 9083

ENTRYPOINT ["/entrypoint.sh"]
