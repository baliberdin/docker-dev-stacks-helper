#!/usr/bin/env bash
# =============================================================================
# Submete o pipeline Flink CDC (Postgres -> Iceberg) ao cluster Flink em execucao.
#
# Todos os jars necessarios ja estao em /opt/flink/lib (Hadoop uber, Hive
# connector, iceberg-aws-bundle) e em /opt/flink-cdc/lib (pipeline connectors).
# O flink-cdc.sh adiciona ambos os diretorios ao classpath automaticamente,
# entao nao e preciso passar --jar.
# =============================================================================
set -euo pipefail

docker compose exec flink-jobmanager \
  /opt/flink-cdc/bin/flink-cdc.sh \
    --flink-home /opt/flink \
    /opt/flink/pipelines/postgres-to-iceberg.yaml
