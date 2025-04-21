# Docker Dev Stacks Helper
Este repositório é um conjunto de stacks de ambientes de desenvolvimento/estudos feitos utilizando **Docker Compose** e **Localstack**, com o objetivo de demonstrar uma instalação mínima e facilitar a compreenção de alguns ambientes complexos, como a iteração entre sistemas distribuídos e permitindo que, a partir de um ambiente funcional, possamos realizar customizações e experimentos.

### Atenção: Não recomendamos a utilização de nenhuma dessas stacks em produção. Os dados de eventuais bancos de dados ou storages criados e ou preenchidos duranto o uso das stacks podem ser perdidos com a reinicialização dos serviços.

- [Data Platform - Basic (LocalStack)](./data-platform-basic)
Plataforma simples com LocalStack(S3), Hive Metastore, Trino e Jupyterhub(Spark + Delta Lake) para transformação e exploração de dados.

- [Data Platform - Basic (Hadoop)](./data-platform-stream)
Plataforma simples com Hadoop(HDFS), Hive Metastore, Trino e Jupyterhub(Spark + Delta Lake) para transformação e exploração de dados.