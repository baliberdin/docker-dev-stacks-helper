#!/usr/bin/env bash
# =============================================================================
# Manutencao das tabelas Iceberg via Trino.
#
# Em CDC streaming, cada checkpoint/commit gera arquivos pequenos e (no caso de
# upsert) delete files. Sem manutencao, a leitura degrada com o tempo. Este
# script demonstra as tres rotinas essenciais no Trino:
#
#   1) OPTIMIZE            -> compacta data files pequenos em arquivos maiores e
#                            aplica os delete files (materializa o estado).
#   2) expire_snapshots    -> descarta snapshots antigos (controla metadata bloat
#                            e libera arquivos nao mais referenciados).
#   3) remove_orphan_files -> remove arquivos no storage nao referenciados por
#                            nenhum snapshot (lixo de escritas abortadas).
#
# Uso: ./maintenance-iceberg.sh [catalogo.schema.tabela ...]
#      (default: as tabelas dos experimentos)
#
# ATENCAO sobre retencao: expire_snapshots / remove_orphan_files usam a retencao
# minima configurada no catalogo Trino (default SEGURO = 7d). Para a DEMO ter
# efeito imediato, suba o Trino em modo demo (retencao 0s) ANTES de rodar:
#
#   ICEBERG_EXPIRE_SNAPSHOTS_MIN_RETENTION=0s \
#   ICEBERG_REMOVE_ORPHAN_FILES_MIN_RETENTION=0s \
#   docker compose up -d trino
#
# Com o default de producao (7d), os passos 2 e 3 sao recusados de proposito
# (protegem snapshots/arquivos ainda em uso). Isso e esperado.
# =============================================================================
set -euo pipefail

TABLES=("$@")
if [ ${#TABLES[@]} -eq 0 ]; then
  TABLES=(
    "iceberg.public.orders"        # Teste A (espelho particionado)
    "iceberg.changelog.orders"     # Teste B (changelog append-only)
    "iceberg.public.customers"     # Pipeline base
  )
fi

trino_exec() {
  docker compose exec -T trino trino --execute "$1" 2>/dev/null
}

for t in "${TABLES[@]}"; do
  echo "==================================================================="
  echo "==> Manutencao de ${t}"

  # Nome base da tabela (ultimo segmento) para montar o metadata table "$files".
  base="${t##*.}"
  files_table="${t%.*}.\"${base}\$files\""
  snaps_table="${t%.*}.\"${base}\$snapshots\""

  echo "--- Estado ANTES ---"
  trino_exec "SELECT count(*) AS data_files, coalesce(sum(record_count),0) AS records FROM ${files_table}" || true
  trino_exec "SELECT count(*) AS snapshots FROM ${snaps_table}" || true

  echo "--- 1) OPTIMIZE (compaction) ---"
  # Reescreve arquivos menores que file_size_threshold em arquivos maiores.
  trino_exec "ALTER TABLE ${t} EXECUTE optimize(file_size_threshold => '128MB')"

  echo "--- 2) expire_snapshots (retencao 0s para demo; em prod use 7d) ---"
  # retention_threshold curto so para o efeito ser visivel no teste; exige
  # iceberg.expire-snapshots.min-retention=0s no catalogo (ver trino/catalog).
  trino_exec "ALTER TABLE ${t} EXECUTE expire_snapshots(retention_threshold => '0s')" \
    || echo "    (ajuste iceberg.expire-snapshots.min-retention e reinicie o Trino)"

  echo "--- 3) remove_orphan_files ---"
  trino_exec "ALTER TABLE ${t} EXECUTE remove_orphan_files(retention_threshold => '0s')" \
    || echo "    (ajuste iceberg.remove-orphan-files.min-retention e reinicie o Trino)"

  echo "--- Estado DEPOIS ---"
  trino_exec "SELECT count(*) AS data_files, coalesce(sum(record_count),0) AS records FROM ${files_table}" || true
  trino_exec "SELECT count(*) AS snapshots FROM ${snaps_table}" || true
done

echo "==================================================================="
echo "Manutencao concluida."
