#!/usr/bin/env bash
# =============================================================================
# TESTE A - submete o pipeline Flink CDC orders -> Iceberg particionado.
# =============================================================================
set -euo pipefail

docker compose exec flink-jobmanager \
  /opt/flink-cdc/bin/flink-cdc.sh \
    --flink-home /opt/flink \
    /opt/flink/pipelines/orders-to-iceberg-partitioned.yaml
