FROM apache/spark:3.5.1

USER root

RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Miniconda with Python 3.11
RUN curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-py311_23.11.0-2-Linux-x86_64.sh \
        -o /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

ENV PATH="/opt/conda/bin:${PATH}"

RUN /opt/conda/bin/pip install --no-cache-dir \
    pyarrow==14.0.2 \
    pandas==2.0.3 \
    boto3==1.34.69 \
    minio==7.2.7

# Download required JARs for Iceberg + S3A
RUN curl -fL "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.5.2/iceberg-spark-runtime-3.5_2.12-1.5.2.jar" \
        -o /opt/spark/jars/iceberg-spark-runtime-3.5_2.12-1.5.2.jar && \
    curl -fL "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" \
        -o /opt/spark/jars/hadoop-aws-3.3.4.jar && \
    curl -fL "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" \
        -o /opt/spark/jars/aws-java-sdk-bundle-1.12.262.jar

COPY spark-defaults.conf /opt/spark/conf/spark-defaults.conf

ENV PYSPARK_PYTHON=/opt/conda/bin/python3.11

USER spark
