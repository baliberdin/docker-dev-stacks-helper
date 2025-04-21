# Data Platform Stack - Basic (Hadoop)
Stack básica de plataforma de dados onde é possível utilizar notebooks Jupyter com Spark para explorar, processar e salvar os dados Hadoop HDFS no formato Delta Lake e/ou Parquet. Além disso conta com o Metasore do Hive para centralizar os metadados e o Trino que permite executar queries SQL nos dados do HDFS utilizando algum client JDBC como por exemplo o DBeaver.

Caso esteja procurando pela stack com LocalStack (S3) no lugar do Hadoop HDFS vide [data-platform-basic](../data-platform-basic/)

### Atenção: Todos os dados serão perdidos ao parar os serviços. Todas as stacks desse repositório são destinadas apenas para desenvolvimento e estudos.

## Stack
- localhost:9870 - Hadoop Namenode (WEB UI)
- localhost:9083 - Hive Metastore
- localhost:5432 - PostgreSQL (banco de dados do Hive Metastore)
- localhost:8888 - Jupyterhub + Spark + Delta Lake
- localhost:8080 - Trino (antigo PrestoDB)

## Pré Requisitos
- Make
- wget
- Docker
- DBeaver (opcional para executar queries via Trino)

## Iniciando os serviços
IMPORTANTE: Crie uma cópia do arquivo *.env.template* e renomeie para *.env*

Após configurar o arquivo .env com seu token do LocalStack, inicie os serciços utilizando a task *start-all* do Makefile.
```bash
make start-all
```
A task acima realizará o download dos Jars de dependencias e  criará todos os containers da stack. Primeiro será criado os containers do Hadoop e em seguida o diretório no HDFS para armazenamento dos dados.
Uma vez criado e configurado o diretório no HDFS, o restante da stack é iniciado: hive-metastore, hive-metastore-db, trino, jupyterhub.

Também será criado uma nova network no Docker chamada **data-platform-basic** com um range de IP que está configurado no **docker-compose.yaml**. Verifique se o range de IPs configurados para a network não conflita com outra network existente em seu ambiente.

## Acessando o Jupyterhub
```bash
make access-jupyterhub
```
Há um notebook de exemplo na pasta work que utiliza o Spark para gerar uma Delta Table no S3 e registra a tabela no Hive Metastore.

Uma vez que os dados estejam salvos no S3 (utilizando saveAsTable do spark, por exemplo) será possível realizar queries a partir do DBeaver conectando no Trino. Não é necessario configurar autenticação na conexão do DBeaver com o Trino, apenas informe o usuário *admin* e deixe a senha em branco.

## Parando todos os serviços
```bash
make stop-all
```

## Outras informações
### Trino
A interface web do Trino http://localhost:8080/ui/ não requer autenticação, apenas um nome de usuário, experimente admin.
O banco de dados PostgreSQL pode ser acessado via DBeaver, para isso basta pegar as credenciais no arquivo .env

Exemplo de query via DBeaver através de uma conexão com o Trino
```sql
-- Define o catálogo e o schema padrão. 
-- O catalogo delta é criado automaticamente quando o 
-- Trino é iniciado de acordo com o arquivo delta.properties 
-- que está na pasta trino
-- Já o schema datalake foi criado no Notebook de exemplo.
-- jupyterhub/work/get_started.ipynb
USE delta.datalake;

-- A tabela stock_price_history foi criada no 
-- Notebook de exemplo jupyterhub/work/get_started.ipynb
SELECT COUNT(1) AS total FROM stock_price_history; 
```

### Spark
É possível acessar a interface do Spark após a inicialização do Spark Session no Notebook de exemplo pelo endereço http://localhost:4040

### Jupyterhub
A pasta jupyterhub/work está montada diretamente no container do Jupyterhub e está configurada de forma que alterações feitas via Jupyterhub sejam replicadas para a pasta local e vice-versa.

## Compreendendo um pouco mais a Stack
Nessa stack estamos utilizando o Hadoop HDFS como storage distribuído, onde tanto o Spark quanto o Trino podem ler e escrever dados nas tabelas. 

O cluster do Hadoop criado nessa stack é bem enxuto e conta com: namenode, nodemanager, datanode, resourcemanager.
Todos os containers recebem a mesma configuração que está no arquivo config na pasta hadoop.

Todos os metadados das tabelas que forem criadas pelo Spark ou Trino serão armazenados no Hive Metastore que utiliza por baixo dos panos um banco de dados PostgreSQL.

Para que o Hive Metastore, Spark e o Trino trabalhem com o Hadoop HDFS foi necessário configurar essas 3 aplicações. O Hive foi configurado a partir do arquivo **hive-site.xml** que fica na pasta hive. Já o Trino possui um arquivo de catalogo chamado **delta.properties** onde configuramos o suporte nativo para o HDFS. Para o Spark não é necessário realizar nenhuma configuração extra, além de indicar a URI do Hive Metastore no momento da criação do Spark Session.

A única biblioteca extra que é baixada durante o start da stack é o JDBC connector do PostgreSQL.
No caso do Spark, as dependências são adicionadas no momento da criação da sessão do spark, direramente no Notebook utilizando a propriedade **spark.jars.packages**.