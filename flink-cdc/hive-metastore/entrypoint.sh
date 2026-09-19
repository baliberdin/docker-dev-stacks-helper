#!/usr/bin/env bash
set -euo pipefail

export HADOOP_HOME="/opt/hadoop-${HADOOP_VERSION}"
export HADOOP_CLASSPATH="${HADOOP_HOME}/share/hadoop/tools/lib/*"

echo "==> Aguardando o PostgreSQL responder..."
until (echo > /dev/tcp/postgres/5432) >/dev/null 2>&1; do
  sleep 2
done
echo "==> PostgreSQL disponivel."

# Cria o banco "metastore" no Postgres caso ainda nao exista.
# Usa o driver JDBC via um pequeno script Java nao seria trivial; entao usamos psql
# nao esta disponivel na imagem, portanto criamos via schematool que assume o DB pronto.
# Para garantir o DB, tentamos criar por meio do JDBC do proprio schematool:
# como alternativa simples e robusta, criamos o banco usando o cliente do postgres
# instalado sob demanda.
if ! command -v psql >/dev/null 2>&1; then
  apt-get update >/dev/null 2>&1 && apt-get install -y --no-install-recommends postgresql-client >/dev/null 2>&1 || true
fi

export PGPASSWORD=postgres
if command -v psql >/dev/null 2>&1; then
  psql -h postgres -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'metastore'" \
    | grep -q 1 || psql -h postgres -U postgres -c "CREATE DATABASE metastore"
fi

SCHEMA_TOOL="${HIVE_HOME}/bin/schematool"

# Inicializa o schema do metastore apenas se ainda nao foi inicializado.
if ! "${SCHEMA_TOOL}" -dbType postgres -info >/dev/null 2>&1; then
  echo "==> Inicializando schema do metastore no Postgres..."
  "${SCHEMA_TOOL}" -dbType postgres -initSchema
else
  echo "==> Schema do metastore ja inicializado."
fi

echo "==> Iniciando o Hive Metastore (thrift :9083)..."
exec "${HIVE_HOME}/bin/start-metastore"
