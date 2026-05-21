FROM quay.io/jupyter/pyspark-notebook:spark-3.5.0

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Download Iceberg and S3A JARs for PySpark kernel
RUN curl -fL "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.5.2/iceberg-spark-runtime-3.5_2.12-1.5.2.jar" \
        -o /usr/local/spark/jars/iceberg-spark-runtime-3.5_2.12-1.5.2.jar && \
    curl -fL "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" \
        -o /usr/local/spark/jars/hadoop-aws-3.3.4.jar && \
    curl -fL "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" \
        -o /usr/local/spark/jars/aws-java-sdk-bundle-1.12.262.jar

COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py
COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

COPY requirements.txt /tmp/notebook-requirements.txt
RUN /opt/conda/bin/pip install --no-cache-dir -r /tmp/notebook-requirements.txt && \
    /opt/conda/bin/pip install --no-cache-dir --force-reinstall jupyterlab-git==0.53.0

# Install internal Lakehouse utilities (abstracts credentials/config from notebooks)
COPY lakehouse_pkg /tmp/lakehouse_pkg
RUN /opt/conda/bin/pip install --no-cache-dir --no-build-isolation /tmp/lakehouse_pkg \
    && rm -rf /tmp/lakehouse_pkg

WORKDIR /home/jovyan/work

# Override CMD to go through our entrypoint (runs as root via tini)
USER root
CMD ["/usr/local/bin/docker-entrypoint.sh"]
