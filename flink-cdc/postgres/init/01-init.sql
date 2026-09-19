-- =============================================================================
-- Inicializacao do PostgreSQL para o cenario de CDC do Flink.
--
-- Este script roda automaticamente na PRIMEIRA subida do container (banco vazio).
-- Cria:
--   * um segundo banco de dados "cdc_source" para testar o CDC
--   * uma tabela de teste "public.customers" com PK (obrigatorio para o sink Iceberg)
--   * dados iniciais (que serao capturados na fase de snapshot)
--   * garante que o wal_level=logical ja foi ligado via command do compose
-- =============================================================================

-- Segundo banco de dados usado como origem do CDC
CREATE DATABASE cdc_source;

-- Conecta ao novo banco para criar objetos dentro dele
\connect cdc_source

-- Tabela de teste. O connector Iceberg exige chave primaria.
CREATE TABLE public.customers (
    id          INTEGER      PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    email       VARCHAR(255),
    country     VARCHAR(100),
    updated_at  TIMESTAMP    NOT NULL DEFAULT now()
);

-- Publicacao logica usada pelo Debezium/Flink CDC (plugin pgoutput).
-- Publicar apenas as tabelas de interesse. Pode usar FOR ALL TABLES tambem.
CREATE PUBLICATION dbz_publication FOR TABLE public.customers;

-- REPLICA IDENTITY FULL faz o WAL carregar os valores antigos das linhas,
-- necessario para updates/deletes serem materializados corretamente no sink.
ALTER TABLE public.customers REPLICA IDENTITY FULL;

-- Dados iniciais capturados na fase de snapshot do CDC.
INSERT INTO public.customers (id, name, email, country) VALUES
    (1, 'Ada Lovelace',    'ada@example.com',    'UK'),
    (2, 'Alan Turing',     'alan@example.com',   'UK'),
    (3, 'Grace Hopper',    'grace@example.com',  'US'),
    (4, 'Dennis Ritchie',  'dennis@example.com', 'US');

-- =============================================================================
-- Tabela "orders" usada pelos experimentos de camada de chegada no Lake:
--   * Teste A: Flink CDC -> Iceberg particionado por created_at (upsert)
--   * Teste B: Debezium unwrap -> Kafka -> Kafka Connect Iceberg Sink (append-only)
-- Tem uma coluna temporal (created_at) para servir de chave de particionamento.
-- =============================================================================
CREATE TABLE public.orders (
    id          INTEGER      PRIMARY KEY,
    customer_id INTEGER      NOT NULL,
    product     VARCHAR(255) NOT NULL,
    amount      NUMERIC(12,2) NOT NULL,
    status      VARCHAR(50)  NOT NULL DEFAULT 'NEW',
    created_at  TIMESTAMP    NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP    NOT NULL DEFAULT now()
);

ALTER TABLE public.orders REPLICA IDENTITY FULL;

-- Inclui orders na publicacao logica (dbz_publication) usada por Flink CDC e Debezium.
ALTER PUBLICATION dbz_publication ADD TABLE public.orders;

-- Dados iniciais (capturados no snapshot). created_at variado para exercitar particao.
INSERT INTO public.orders (id, customer_id, product, amount, status, created_at) VALUES
    (1, 1, 'Keyboard',  120.00, 'PAID',    TIMESTAMP '2026-01-10 09:00:00'),
    (2, 2, 'Mouse',      59.90, 'PAID',    TIMESTAMP '2026-01-10 10:30:00'),
    (3, 3, 'Monitor',   899.00, 'NEW',     TIMESTAMP '2026-02-05 14:15:00'),
    (4, 1, 'USB Cable',  19.90, 'SHIPPED', TIMESTAMP '2026-02-20 11:45:00');
