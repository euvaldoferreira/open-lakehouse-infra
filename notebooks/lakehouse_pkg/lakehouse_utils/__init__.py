import os
from pyspark.sql import SparkSession


def get_spark(app_name: str = "LakehouseNotebook", shuffle_partitions: int = 4) -> SparkSession:
    """Return a SparkSession pre-configured for this Lakehouse platform."""
    return (
        SparkSession.builder
        .appName(app_name)
        .master(os.getenv("SPARK_MASTER_URL", "spark://spark-master:7077"))
        .config("spark.driver.host", "jupyter")
        .config("spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
        .config("spark.sql.catalog.lakehouse",
                "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.lakehouse.type", "hive")
        .config("spark.sql.catalog.lakehouse.uri",
                os.getenv("HMS_URI", "thrift://hive-metastore:9083"))
        .config("spark.sql.catalog.lakehouse.warehouse", "s3a://gold/warehouse")
        .config("spark.hadoop.fs.s3a.endpoint",
                os.getenv("MINIO_ENDPOINT", "http://minio:9000"))
        .config("spark.hadoop.fs.s3a.access.key",
                os.getenv("MINIO_ROOT_USER", "minio_admin"))
        .config("spark.hadoop.fs.s3a.secret.key",
                os.getenv("MINIO_ROOT_PASSWORD", "minio_secure_pass_2024"))
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl",
                "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.sql.shuffle.partitions", str(shuffle_partitions))
        .getOrCreate()
    )


def get_s3_client():
    """Return a boto3 S3 client pre-configured for MinIO."""
    import boto3
    from botocore.config import Config

    return boto3.client(
        "s3",
        endpoint_url=os.getenv("MINIO_ENDPOINT", "http://minio:9000"),
        aws_access_key_id=os.getenv("MINIO_ROOT_USER", "minio_admin"),
        aws_secret_access_key=os.getenv("MINIO_ROOT_PASSWORD", "minio_secure_pass_2024"),
        config=Config(signature_version="s3v4"),
        region_name="us-east-1",
    )
