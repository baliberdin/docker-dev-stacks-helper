# =============================================================================
# Hive Standalone Metastore 3.1.3 + Hadoop 3.3.6 + suporte S3A (MinIO) + Postgres JDBC
# =============================================================================
FROM eclipse-temurin:11-jre-jammy

ENV HADOOP_VERSION=3.3.6
ENV METASTORE_VERSION=3.1.3
ENV POSTGRES_JDBC_VERSION=42.7.4

ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV HIVE_HOME=/opt/apache-hive-metastore-${METASTORE_VERSION}-bin
ENV JAVA_HOME=/opt/java/openjdk

WORKDIR /opt

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Hadoop (fornece libs e o hadoop-aws / aws-java-sdk-bundle para S3A)
RUN curl -fsSL "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
      | tar -xz -C /opt

# Hive Standalone Metastore
RUN curl -fsSL "https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${METASTORE_VERSION}/hive-standalone-metastore-${METASTORE_VERSION}-bin.tar.gz" \
      | tar -xz -C /opt \
    || curl -fsSL "https://archive.apache.org/dist/hive/hive-standalone-metastore-${METASTORE_VERSION}/hive-standalone-metastore-${METASTORE_VERSION}-bin.tar.gz" \
      | tar -xz -C /opt

# Driver JDBC do Postgres (backend do metastore)
RUN curl -fsSL "https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar" \
      -o "${HIVE_HOME}/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar"

# Habilita o filesystem S3A copiando os jars do Hadoop para o classpath do metastore
RUN cp ${HADOOP_HOME}/share/hadoop/tools/lib/hadoop-aws-${HADOOP_VERSION}.jar ${HIVE_HOME}/lib/ \
    && cp ${HADOOP_HOME}/share/hadoop/tools/lib/aws-java-sdk-bundle-*.jar ${HIVE_HOME}/lib/

# Remove um jar de guava antigo do metastore que conflita com o do Hadoop
RUN rm -f ${HIVE_HOME}/lib/guava-*.jar \
    && cp ${HADOOP_HOME}/share/hadoop/common/lib/guava-*.jar ${HIVE_HOME}/lib/

COPY metastore-site.xml ${HIVE_HOME}/conf/metastore-site.xml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9083

ENTRYPOINT ["/entrypoint.sh"]
