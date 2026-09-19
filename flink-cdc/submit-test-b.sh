#!/usr/bin/env bash
# =============================================================================
# TESTE B - registra os connectors do Kafka Connect:
#   1) Debezium Postgres source (com unwrap) -> topico cdc.public.orders
#   2) Iceberg Sink (append-only) -> tabela iceberg changelog.orders no MinIO
#
# Os arquivos JSON usam o formato { "name": ..., "config": {...} }, aceito pelo
# endpoint POST /connectors do Kafka Connect. Se o connector ja existir, o script
# faz DELETE antes de recriar.
# =============================================================================
set -euo pipefail

CONNECT_URL="http://localhost:8083"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kafka-connect/connectors"

echo "==> Aguardando o Kafka Connect responder em ${CONNECT_URL}..."
for i in $(seq 1 60); do
  if curl -sf "${CONNECT_URL}/connectors" >/dev/null 2>&1; then
    echo "    Kafka Connect pronto."
    break
  fi
  sleep 3
done

register() {
  local file="$1" name="$2"
  echo "==> Registrando connector '${name}'..."
  # Remove se ja existir (idempotencia), ignorando erro se nao existir.
  curl -sf -X DELETE "${CONNECT_URL}/connectors/${name}" >/dev/null 2>&1 || true
  sleep 1
  curl -sf -X POST -H "Content-Type: application/json" \
    "${CONNECT_URL}/connectors" --data @"${file}" >/dev/null \
    && echo "    OK: ${name}" || { echo "    Falha ao registrar ${name}"; exit 1; }
}

register "${DIR}/debezium-orders-source.json" "orders-postgres-source"
echo "==> Aguardando o topico cdc.public.orders ser populado (snapshot)..."
sleep 10

# O Iceberg Kafka Connect sink cria a TABELA automaticamente, mas NAO o namespace.
# Criamos o schema "changelog" no metastore via Trino antes de subir o sink.
echo "==> Garantindo o namespace iceberg.changelog..."
docker compose exec -T trino trino --execute "CREATE SCHEMA IF NOT EXISTS iceberg.changelog;" >/dev/null 2>&1 \
  && echo "    namespace changelog pronto." \
  || echo "    aviso: nao foi possivel criar o namespace via Trino (verifique manualmente)."

register "${DIR}/iceberg-orders-sink.json" "orders-iceberg-sink"

echo
echo "==> Connectors registrados:"
curl -s "${CONNECT_URL}/connectors"
echo
