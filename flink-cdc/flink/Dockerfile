# =============================================================================
# Imagem do Flink 1.20 com o toolkit Flink CDC 3.5.0 e os jars necessarios para
# rodar o pipeline Postgres -> Iceberg (sink no MinIO via Hive Metastore catalog).
# =============================================================================
FROM flink:1.20.1-java11

# Versoes dos artefatos
ENV FLINK_CDC_VERSION=3.5.0
ENV ICEBERG_VERSION=1.7.1
ENV HADOOP_UBER_VERSION=2.8.3-10.0
ENV HIVE_CONNECTOR_VERSION=1.20.0
ENV MAVEN_BASE=https://repo1.maven.org/maven2

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 1) Flink CDC toolkit (fornece o flink-cdc.sh + libs em /opt/flink-cdc)
# ---------------------------------------------------------------------------
RUN curl -fsSL "https://archive.apache.org/dist/flink/flink-cdc-${FLINK_CDC_VERSION}/flink-cdc-${FLINK_CDC_VERSION}-bin.tar.gz" \
      | tar -xz -C /opt \
    && mv /opt/flink-cdc-${FLINK_CDC_VERSION} /opt/flink-cdc

# ---------------------------------------------------------------------------
# 2) Pipeline connectors do Flink CDC (source Postgres + sink Iceberg)
#    Vao no diretorio de libs do toolkit CDC.
# ---------------------------------------------------------------------------
RUN curl -fsSL "${MAVEN_BASE}/org/apache/flink/flink-cdc-pipeline-connector-postgres/${FLINK_CDC_VERSION}/flink-cdc-pipeline-connector-postgres-${FLINK_CDC_VERSION}.jar" \
      -o /opt/flink-cdc/lib/flink-cdc-pipeline-connector-postgres-${FLINK_CDC_VERSION}.jar \
    && curl -fsSL "${MAVEN_BASE}/org/apache/flink/flink-cdc-pipeline-connector-iceberg/${FLINK_CDC_VERSION}/flink-cdc-pipeline-connector-iceberg-${FLINK_CDC_VERSION}.jar" \
      -o /opt/flink-cdc/lib/flink-cdc-pipeline-connector-iceberg-${FLINK_CDC_VERSION}.jar

# ---------------------------------------------------------------------------
# 3) Dependencias Hadoop + Hive no classpath do Flink (/opt/flink/lib)
#    O connector iceberg 3.5.0 ja e "shaded" e embute o iceberg-flink-runtime,
#    o iceberg-hive-metastore e o iceberg-aws-bundle (S3FileIO + AWS SDK v2).
#    Faltam:
#    - flink-shaded-hadoop-2-uber: classes Hadoop (Configuration usada pelo HiveCatalog)
#    - flink-sql-connector-hive-3.1.3: cliente/thrift do Hive Metastore
#      (fornece org.apache.hadoop.hive.metastore.api.* exigido pelo HiveCatalog)
# ---------------------------------------------------------------------------
RUN curl -fsSL "${MAVEN_BASE}/org/apache/flink/flink-shaded-hadoop-2-uber/${HADOOP_UBER_VERSION}/flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar" \
      -o /opt/flink/lib/flink-shaded-hadoop-2-uber-${HADOOP_UBER_VERSION}.jar \
    && curl -fsSL "${MAVEN_BASE}/org/apache/flink/flink-sql-connector-hive-3.1.3_2.12/${HIVE_CONNECTOR_VERSION}/flink-sql-connector-hive-3.1.3_2.12-${HIVE_CONNECTOR_VERSION}.jar" \
      -o /opt/flink/lib/flink-sql-connector-hive-3.1.3_2.12-${HIVE_CONNECTOR_VERSION}.jar \
    && curl -fsSL "${MAVEN_BASE}/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar" \
      -o /opt/flink/lib/iceberg-aws-bundle-${ICEBERG_VERSION}.jar

# ---------------------------------------------------------------------------
# 4) Plugin do S3 do proprio Flink (para checkpoints/paths s3://, opcional mas util)
# ---------------------------------------------------------------------------
RUN mkdir -p /opt/flink/plugins/s3-fs-hadoop \
    && cp /opt/flink/opt/flink-s3-fs-hadoop-*.jar /opt/flink/plugins/s3-fs-hadoop/

# Configuracao Hadoop core-site.xml para o S3A apontar ao MinIO
COPY core-site.xml /opt/hadoop-conf/core-site.xml
ENV HADOOP_CONF_DIR=/opt/hadoop-conf

# Deixa o flink-cdc.sh no PATH e torna o toolkit gravavel (log do CLI)
ENV PATH="/opt/flink-cdc/bin:${PATH}"
RUN chown -R flink:flink /opt/flink-cdc \
    && chmod -R g+w /opt/flink-cdc/log

USER flink
