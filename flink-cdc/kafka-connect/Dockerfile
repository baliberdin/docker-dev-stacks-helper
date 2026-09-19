# =============================================================================
# Kafka Connect baseado na imagem do Debezium (traz o source connector Postgres +
# os SMTs, incluindo ExtractNewRecordState/unwrap) e com o Apache Iceberg Sink
# Connector instalado (distribuicao "hive" da Databricks, que inclui o cliente
# do Hive Metastore + S3FileIO).
# =============================================================================
FROM quay.io/debezium/connect:3.0.8.Final

# Versao do runtime do Iceberg Kafka Connect (mantido pela Databricks, inclui HMS)
ENV ICEBERG_KC_VERSION=0.6.19
ENV ICEBERG_KC_URL=https://github.com/databricks/iceberg-kafka-connect/releases/download/v${ICEBERG_KC_VERSION}/iceberg-kafka-connect-runtime-hive-${ICEBERG_KC_VERSION}.zip

USER root

# Diretorio de plugins do Connect (a imagem Debezium usa /kafka/connect)
ENV CONNECT_PLUGIN_DIR=/kafka/connect

RUN mkdir -p ${CONNECT_PLUGIN_DIR} \
    && curl -fsSL "${ICEBERG_KC_URL}" -o /tmp/iceberg-kc.zip \
    && unzip -q /tmp/iceberg-kc.zip -d ${CONNECT_PLUGIN_DIR} \
    && rm -f /tmp/iceberg-kc.zip

# ---------------------------------------------------------------------------
# Confluent Avro converter (io.confluent.connect.avro.AvroConverter) + deps.
# A imagem Debezium NAO traz o converter Avro desde a 2.0; instalamos o conjunto
# de jars num diretorio dedicado no plugin path para os connectors serializarem
# em Avro contra o Confluent Schema Registry.
# ---------------------------------------------------------------------------
ENV CONFLUENT_VERSION=7.9.10
ENV AVRO_VERSION=1.11.4
# Converter vai no classpath do WORKER (/kafka/libs), nao como plugin isolado.
# Converters sao carregados pelo worker; instala-los como plugin em /kafka/connect
# gera conflito de classloader com as libs (jackson) do connector que os usa.
ENV AVRO_DIR=/kafka/libs
ENV CFLT_MAVEN=https://packages.confluent.io/maven/io/confluent
ENV CENTRAL=https://repo1.maven.org/maven2

RUN for a in \
         kafka-connect-avro-converter \
         kafka-connect-avro-data \
         kafka-avro-serializer \
         kafka-schema-serializer \
         kafka-schema-converter \
         kafka-schema-registry-client \
         common-config \
         common-utils ; do \
         curl -fsSL "${CFLT_MAVEN}/${a}/${CONFLUENT_VERSION}/${a}-${CONFLUENT_VERSION}.jar" \
           -o "${AVRO_DIR}/${a}-${CONFLUENT_VERSION}.jar" ; \
       done \
    && curl -fsSL "${CENTRAL}/org/apache/avro/avro/${AVRO_VERSION}/avro-${AVRO_VERSION}.jar" \
         -o "${AVRO_DIR}/avro-${AVRO_VERSION}.jar" \
    && curl -fsSL "${CENTRAL}/com/google/guava/guava/32.1.3-jre/guava-32.1.3-jre.jar" \
         -o "${AVRO_DIR}/guava-32.1.3-jre.jar" \
    && curl -fsSL "${CENTRAL}/com/google/guava/failureaccess/1.0.2/failureaccess-1.0.2.jar" \
         -o "${AVRO_DIR}/failureaccess-1.0.2.jar" \
    && curl -fsSL "${CENTRAL}/com/google/re2j/re2j/1.7/re2j-1.7.jar" \
         -o "${AVRO_DIR}/re2j-1.7.jar" \
    && curl -fsSL "${CENTRAL}/io/swagger/core/v3/swagger-annotations/2.2.25/swagger-annotations-2.2.25.jar" \
         -o "${AVRO_DIR}/swagger-annotations-2.2.25.jar"

USER kafka
