# Flink CDC Lakehouse: Postgres → Iceberg (MinIO) → Trino

Ambiente Docker Compose completo para capturar mudanças (CDC) de uma tabela no
PostgreSQL com **Flink CDC**, gravá-las em formato **Apache Iceberg** no **MinIO**
(S3), catalogadas no **Hive Metastore**, e consultá-las via **Trino**.

## Componentes

| Serviço | Porta | Função |
|---|---|---|
| `postgres` | 5432 | Banco de origem (`wal_level=logical`). Contém o DB `cdc_source` |
| `minio` | 9000 / 9001 | Storage S3 (console em http://localhost:9001) |
| `hive-metastore` | 9083 | Catálogo compartilhado (backend no Postgres, storage no MinIO) |
| `flink-jobmanager` | 8081 | Cluster Flink + toolkit Flink CDC (UI em http://localhost:8081) |
| `flink-taskmanager` | — | Worker do Flink |
| `kafka` | 9092 | Broker Kafka (KRaft) — usado no Teste B |
| `kafka-connect` | 8083 | Kafka Connect (Debezium + Iceberg Sink, converter Avro) — Teste B |
| `schema-registry` | 8085 | Confluent Schema Registry (schemas Avro) — Teste B |
| `redpanda-console` | 8090 | UI para tópicos, schemas e connectors (http://localhost:8090) |
| `trino` | 8080 | Engine de consulta (catálogos `iceberg` e `hive`) |

Fluxo base: `Postgres (cdc_source.public.customers)` → `Flink CDC` → `Iceberg em s3a://warehouse/` → `Trino`.

Além do pipeline base, há dois experimentos de **camada de chegada no Lake** sobre a
tabela `public.orders` — veja a seção [Experimentos de camada de chegada](#experimentos-de-camada-de-chegada-orders).

## Pré-requisitos

- Docker + Docker Compose v2
- ~4 GB de RAM livres para os containers

## 1. Subir o ambiente

```bash
docker compose up -d --build
```

A primeira execução baixa e compila as imagens (Hive Metastore e Flink com jars),
o que pode levar alguns minutos. Acompanhe:

```bash
docker compose ps
docker compose logs -f hive-metastore
```

Aguarde o `hive-metastore` logar `Starting Hive Metastore Server` / thrift na 9083.

## 2. Submeter o pipeline CDC

```bash
./submit-pipeline.sh
```

O script chama `flink-cdc.sh` dentro do JobManager com o pipeline
[`flink/pipelines/postgres-to-iceberg.yaml`](flink/pipelines/postgres-to-iceberg.yaml).
Ao final ele imprime um `Job ID`. Verifique o job rodando em http://localhost:8081.

A fase de *snapshot* copia as 4 linhas iniciais; depois o job segue lendo o WAL.

## 3. Consultar via Trino

Abra o CLI do Trino:

```bash
docker compose exec trino trino
```

```sql
SHOW SCHEMAS FROM iceberg;
SHOW TABLES FROM iceberg.public;
SELECT * FROM iceberg.public.customers ORDER BY id;
```

> O namespace no Iceberg segue o schema do Postgres: a tabela `cdc_source.public.customers`
> vira `iceberg.public.customers` (o database do Postgres não entra no Table ID por padrão).
> A primeira query traz os 4 registros do snapshot inicial.

## 4. Testar o CDC (inserts / updates / deletes)

Em outro terminal, altere dados no Postgres:

```bash
docker compose exec postgres psql -U postgres -d cdc_source
```

```sql
INSERT INTO public.customers (id, name, email, country)
VALUES (5, 'Margaret Hamilton', 'margaret@example.com', 'US');

UPDATE public.customers SET country = 'USA' WHERE id = 3;

DELETE FROM public.customers WHERE id = 1;
```

Aguarde alguns segundos (intervalo de checkpoint = 10s) e reconsulte no Trino:

```sql
SELECT * FROM iceberg.public.customers ORDER BY id;
```

As mudanças devem refletir: `id=5` inserido, `id=3` atualizado, `id=1` removido.

## Como criar um novo banco/tabela para testar

O `cdc_source` já é o "segundo banco" de teste. Para adicionar outra tabela:

1. Crie a tabela com **chave primária** (obrigatória para o sink Iceberg) e
   `ALTER TABLE ... REPLICA IDENTITY FULL;`.
2. Adicione-a à publicação: `ALTER PUBLICATION dbz_publication ADD TABLE public.sua_tabela;`.
3. Inclua-a em `tables:` no pipeline YAML (ex.: `cdc_source.public.customers,cdc_source.public.sua_tabela`)
   ou use regex (`cdc_source.public.\.*`).
4. Reenvie o pipeline com `./submit-pipeline.sh`.

## Reenviar o pipeline do zero

Cada submissão cria um job novo (sem savepoint). Como o slot de replicação do
Postgres guarda a posição (LSN) já lida, um novo job pula o snapshot inicial e
começa direto no streaming. Se quiser reprocessar tudo do zero (novo snapshot),
descarte o slot antes de resubmeter:

```bash
docker compose exec postgres psql -U postgres -d cdc_source \
  -c "SELECT pg_drop_replication_slot('flink_cdc_slot');"
./submit-pipeline.sh
```

## Estrutura

```
.
├── docker-compose.yml
├── submit-pipeline.sh
├── postgres/init/01-init.sql          # DB cdc_source + tabela + publicação
├── hive-metastore/                    # Dockerfile + metastore-site.xml + entrypoint
├── flink/                             # Dockerfile + core-site.xml + pipelines/
│   └── pipelines/postgres-to-iceberg.yaml
└── trino/catalog/                     # iceberg.properties + hive.properties
```

## Notas de versão / decisões de implementação

- Flink 1.20.1 / Flink CDC 3.5.0 / Iceberg 1.7.1 / Trino 465 / Hive Metastore 3.1.3 / Postgres 16.
- O sink Iceberg usa `at-least-once` + PK para escrita idempotente (upsert).
- Checkpoints a cada 10s controlam a frequência de commit no Iceberg (latência de visibilidade no Trino).
- O sink usa `catalog.properties.type: hive` com `io-impl: S3FileIO` e warehouse `s3://warehouse/`.
  O Hive Metastore mapeia o esquema `s3` para `S3AFileSystem` (ver `metastore-site.xml`) para
  conseguir criar os diretórios de namespace/tabela no MinIO.
- A rede do Compose recebe `name: lakehouse` explicitamente: o cliente do Hive Metastore
  rejeita hostnames com `_`, e o sufixo padrão do nome do projeto (`flink-cdc-lakehouse_lakehouse`)
  quebraria a conexão thrift.
- Os jars necessários (Hadoop uber, `flink-sql-connector-hive` para o cliente do metastore e
  `iceberg-aws-bundle` para o AWS SDK v2 do S3FileIO) são baixados no `flink/Dockerfile`.

## Validação realizada

Este ambiente foi executado e validado de ponta a ponta:
1. Snapshot inicial das 4 linhas apareceu em `iceberg.public.customers` via Trino.
2. Um `INSERT` (id=5), um `UPDATE` (id=3) e um `DELETE` (id=1) no Postgres foram
   refletidos na tabela Iceberg após o checkpoint seguinte.
3. Os arquivos (`data/*.parquet`, `metadata/*.metadata.json`, manifests `*.avro`) foram
   confirmados no bucket `s3://warehouse/public.db/customers/` do MinIO.

## Encerrar

```bash
docker compose down          # mantém volumes
docker compose down -v       # apaga dados (Postgres, MinIO, checkpoints)
```

---

# Experimentos de camada de chegada (orders)

Motivação: no pipeline base, a tabela do Lake é um **espelho do estado** do Postgres
(upsert por PK). Em escala (milhões de linhas com muito UPDATE/DELETE), isso gera
equality deletes e small files que encarecem a leitura. Estes dois experimentos
comparam abordagens para a **camada de chegada** (a primeira parada do dado no Lake),
ambas terminando em Iceberg administrável. Etapas posteriores (reparticionamento,
upsert do diff, materialização Silver/Gold) ficam fora do escopo aqui.

Os dois testes leem a **mesma** tabela de origem `cdc_source.public.orders`, então os
mesmos eventos produzem resultados diferentes no Lake — é essa a comparação.

| | Pipeline base / Teste A | Teste B |
|---|---|---|
| Ferramenta | Flink CDC (YAML pipeline) | Debezium + Kafka + Iceberg Sink (Kafka Connect) |
| Semântica | Espelho do estado (upsert por PK) | Changelog append-only (1 linha por evento) |
| DELETE na origem | Remove a linha no Lake | Vira uma linha com `__op=d`, `__deleted=true` |
| UPDATE na origem | Sobrescreve (equality delete + novo dado) | Nova linha `__op=u`, versões antigas preservadas |
| Tabela destino | `iceberg.public.orders` | `iceberg.changelog.orders` |
| Particionamento | `created_date` (string derivada) | `day(created_at)` (transform nativo) |
| Camada típica | Silver (estado atual) | Bronze (log bruto, auditoria/reprocessamento) |

## Teste A — Flink CDC → Iceberg particionado (espelho)

Igual ao pipeline base, mas particionado por dia. O sink Iceberg do Flink CDC 3.5.0 só
particiona por **identidade** de coluna (não tem `day()`/`hour()`), então um transform
deriva `created_date` (`yyyy-MM-dd`) a partir de `created_at`, e particionamos por ela.

```bash
./submit-test-a.sh
```

```sql
-- estado atual (espelho), particionado
SELECT id, status, created_date FROM iceberg.public.orders ORDER BY id;
SELECT partition, record_count FROM iceberg.public."orders$partitions";
```

## Teste B — Debezium → Kafka → Iceberg Sink (changelog append-only)

Debezium lê o WAL e publica no tópico Kafka `cdc.public.orders`, **serializando em
Avro** com os schemas registrados no **Schema Registry**. O SMT
`ExtractNewRecordState` (unwrap) achata o envelope e adiciona metadados
(`__op`, `__deleted`, `__lsn`, `__source_ts_ms`). O Iceberg Sink connector grava
cada evento como **uma linha nova** (sem `id-columns` → sem upsert), particionando
por `day(created_at)`.

Serialização: os dois connectors usam `io.confluent.connect.avro.AvroConverter`
apontando para `http://schema-registry:8085`. Os subjects criados seguem a
estratégia de nome de tópico: `cdc.public.orders-key` e `cdc.public.orders-value`.

Pré-requisito: o Kafka Connect precisa da imagem construída (`docker compose up -d --build`).

```bash
./submit-test-b.sh
```

O script registra os dois connectors e cria o namespace `iceberg.changelog` (o Iceberg
Sink cria a tabela, mas não o namespace). Confira os schemas Avro no Registry:

```bash
curl -s http://localhost:8085/subjects
# ["cdc.public.orders-key","cdc.public.orders-value"]
curl -s http://localhost:8085/subjects/cdc.public.orders-value/versions/latest | jq .schema
```

Consulte no Trino:

```sql
-- historico completo de eventos (append-only)
SELECT id, status, __op, __deleted FROM iceberg.changelog.orders ORDER BY id, __source_ts_ms;
-- distribuicao por operacao: r=snapshot, c=insert, u=update, d=delete
SELECT __op, count(*) FROM iceberg.changelog.orders GROUP BY __op ORDER BY __op;
SELECT partition, record_count FROM iceberg.changelog."orders$partitions";
```

## Testar os dois lado a lado

Aplique mudanças no Postgres e compare os dois destinos:

```bash
docker compose exec postgres psql -U postgres -d cdc_source -c "
  UPDATE public.orders SET status='CANCELLED' WHERE id=3;
  DELETE FROM public.orders WHERE id=1;
"
```

Após alguns segundos:
- `iceberg.public.orders` (Teste A): `id=1` some, `id=3` passa a CANCELLED (só o estado atual).
- `iceberg.changelog.orders` (Teste B): ganham-se linhas novas para o update e o delete; nada é apagado.

## Endpoints úteis do Teste B

```bash
# status dos connectors
curl -s http://localhost:8083/connectors?expand=status | jq

# conteudo do topico (envelope ja "unwrapped")
docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 --topic cdc.public.orders --from-beginning --max-messages 3
```

## Notas de implementação dos experimentos

- **Teste A / particionamento por identidade:** o sink Flink CDC 3.5.0 usa
  `PartitionSpec.builderFor(schema).identity(col)`. Por isso derivamos a coluna
  `created_date` como string de dia; particionar direto pelo `created_at` (timestamp)
  geraria uma partição por microssegundo.
- **Teste B / tipos temporais:** o Debezium exporta `TIMESTAMP` como epoch (BIGINT) por
  padrão, o que quebra o transform `day()`. Setamos `time.precision.mode: connect` no
  source para o `created_at` chegar como timestamp lógico do Kafka Connect, reconhecido
  pelo Iceberg sink.
- **Teste B / namespace:** o Iceberg Sink cria a tabela automaticamente, mas não o
  namespace/database. O `submit-test-b.sh` cria `iceberg.changelog` via Trino antes.
- **Teste B / classe do connector:** a distribuição usada (Databricks
  `iceberg-kafka-connect-runtime-hive`) registra a classe legada
  `io.tabular.iceberg.connect.IcebergSinkConnector`.
- **Teste B / reprocesso:** o source usa `snapshot.mode: always` e o sink lê com
  `auto.offset.reset: earliest` para o experimento ser reprodutível a cada (re)registro.
  Em produção o padrão seria `initial`.
- **Commit do Iceberg Sink:** o intervalo padrão é 5 min; reduzimos para 15s
  (`iceberg.control.commit.interval-ms`) para o changelog aparecer rápido no Trino.
- **Avro converter no classpath do worker:** a imagem Debezium não traz o
  `io.confluent.connect.avro.AvroConverter` (removido desde a 2.0). Instalamos os jars
  em `/kafka/libs` (classpath do worker), **não** como plugin isolado em `/kafka/connect`
  — isso evita conflito de classloader/jackson quando o Iceberg sink usa o converter.
- **Tipos temporais em Avro:** com `time.precision.mode: connect`, o `created_at` chega
  como timestamp lógico do Connect e vira `timestamp` no Iceberg, permitindo o
  particionamento `day(created_at)` também no caminho Avro.

## Redpanda Console

UI web (open-source) para inspecionar o Teste B: http://localhost:8090

- **Topics:** veja `cdc.public.orders`, mensagens desserializadas via Schema Registry.
- **Schema Registry:** os subjects Avro e suas versões.
- **Kafka Connect:** estado dos connectors `orders-postgres-source` e `orders-iceberg-sink`.

Configuração via `CONSOLE_CONFIG_FILE` no compose (`kafka`, `schemaRegistry` e
`kafkaConnect` são seções top-level na v3.x do Console).

## Manutenção das tabelas Iceberg (compaction / expire)

Em CDC streaming, cada commit gera arquivos pequenos (e, no upsert, delete files).
Sem manutenção, a leitura degrada. O script `maintenance-iceberg.sh` roda, via Trino,
as três rotinas essenciais:

```bash
./maintenance-iceberg.sh                          # tabelas dos experimentos
./maintenance-iceberg.sh iceberg.changelog.orders # uma tabela especifica
```

1. `ALTER TABLE ... EXECUTE optimize` — compacta small files e aplica delete files.
2. `ALTER TABLE ... EXECUTE expire_snapshots` — descarta snapshots antigos.
3. `ALTER TABLE ... EXECUTE remove_orphan_files` — remove arquivos órfãos no storage.

O script imprime o antes/depois (data files e snapshots). Exemplo observado na
`changelog.orders`: 5 → 4 data files e 2 → 1 snapshots, com os registros preservados.

### Retenção mínima: seguro por padrão

A retenção mínima do `expire_snapshots` / `remove_orphan_files` é **parametrizada por
variável de ambiente**, com **default seguro de produção (7 dias)**. Em
`trino/catalog/iceberg.properties`:

```properties
iceberg.expire-snapshots.min-retention=${ENV:ICEBERG_EXPIRE_SNAPSHOTS_MIN_RETENTION}
iceberg.remove-orphan-files.min-retention=${ENV:ICEBERG_REMOVE_ORPHAN_FILES_MIN_RETENTION}
```

O compose injeta o default `7d` (`${VAR:-7d}`). Com isso, `expire_snapshots(0s)` é
**recusado de propósito** — é o comportamento correto de produção, que protege
snapshots/arquivos ainda em uso por leituras concorrentes ou time travel.

Para a **demo** ter efeito imediato, suba o Trino em modo demo (retenção `0s`):

```bash
ICEBERG_EXPIRE_SNAPSHOTS_MIN_RETENTION=0s \
ICEBERG_REMOVE_ORPHAN_FILES_MIN_RETENTION=0s \
docker compose up -d trino

./maintenance-iceberg.sh iceberg.changelog.orders
```

Ou copie `.env.example` para `.env` e descomente as linhas de `0s`. Para voltar ao
default seguro, rode `docker compose up -d trino` sem as variáveis (ou remova o `.env`).
**Nunca use `0s` em produção**; lá, mantenha 7 dias e agende a manutenção fora do pico.

## Conclusão prática (para um projeto produtivo)

Para uma camada de chegada que precisa **escalar para milhões de linhas** e ser
administrável, o padrão mais robusto é o do **Teste B (Bronze append-only)**: a escrita
é barata (sem equality deletes), preserva histórico e é fácil de reprocessar. A partir
dele, um processo posterior materializa o estado atual (Silver) por batch/streaming,
fazendo upsert só do diff e reparticionando conforme o padrão de consulta. O
**Teste A (espelho)** é conveniente quando você quer o estado atual direto e o volume
de mudanças é moderado, mas exige disciplina de compaction/expire para não degradar a
leitura ao longo do tempo.
