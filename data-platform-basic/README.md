# Data Platform Stack - Basic
Stack básica de plataforma de dados onde é possível utilizar notebooks Jupyter com Spark para explorar, processar e salvar os dados em um bucket do S3 (LocalStack) no formato Delta Lake e/ou Parquet. Além disso conta com o Metasore do Hive para centralizar os metadados e o Trino que permite executar queries SQL nos dados do S3 utilizando algum client JDBC como por exemplo o DBeaver.

Caso esteja procurando pela stack com Hadoop HDFS no lugar do LocalStack (S3) vide [data-platform-basic-hadoop](../data-platform-basic-hadoop/)

### Atenção: Todos os dados serão perdidos ao parar os serviços. Todas as stacks desse repositório são destinadas apenas para desenvolvimento e estudos.

## Stack
- localhost:4566 - LocalStack (AWS)
- localhost:9083 - Hive Metastore
- localhost:5432 - PostgreSQL (banco de dados do Hive Metastore)
- localhost:8888 - Jupyterhub + Spark + Delta Lake
- localhost:8080 - Trino (antigo PrestoDB)

## Pré Requisitos
- Make
- wget
- Docker
- Terraform
- DBeaver (opcional para executar queries via Trino)
- Token pessoal de autenticação do LocalStack (https://app.localstack.cloud/settings/auth-tokens)

O container do LocalStack foi configurado esperando um token de conta Pro, que pode ser adquirido com a inscrição do tipo *Hobby Subscription*. Caso a sua inscrição não seja Pro modifique a imagem do LocalStack no arquivo *.env*

## Iniciando os serviços
IMPORTANTE: Crie uma cópia do arquivo *.env.template* e renomeie para *.env*
e adicione o seu token do LocalStack dentro do arquivo .env

`LOCALSTACK_AUTH_TOKEN="your_localstack_auth_token"`

Após configurar o arquivo .env com seu token do LocalStack, inicie os serciços utilizando a task *start-all* do Makefile.
```bash
make start-all
```
A task acima realizará o download dos Jars de dependencias e  criará todos os containers da stack. Primeiro será criado o LocalStack e em seguida será aplicado o Terraform para criar o bucket S3.
Uma vez criado o bucket, o restante da stack é iniciado: hive-metastore, hive-metastore-db, trino, jupyterhub.

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
Utilizar o LocalStack como um ambiente de desenvolvimento que simule a AWS pode ser bastante útil, mas para que isso funcione bem é necessário que todos os sistemas que dependem da AWS saibam que estamos utilizando o LocalStack e não a AWS. 

Dito isso, o que foi feito aqui é a configuração tanto do Hive Metastore quanto do Spark (que roda "embedado" no Jupyterhub) para que eles apontem para o endpoint do LocalStack. Essa configuração é feita no arquivo **core-site.xml** do Hadoop que está na pasta haddop dessa stack. O arquivo é montado via volume diretamente nos containers hive-metastore e jupyterhub.

Outro ponto da stack que depende desse endpoint do LocalStack é o Terraform e isso foi feito no arquivo **variables.tf** que está na pasta terraform. Assim, quando pedimos para o Terraform aplicar os elementos definidos na infraestrutura, ele o fará apontando para o LocalStack e não mais para a AWS.

Além da substituição da AWS por essa infra de desenvolvimento, também precisamos configurar algumas dependências que os sistemas podem ter em relação uns com os outros. Por padrão, tanto o Spark quanto o Hive Metastore não tem as bibliotecas necessárias para realizar operações de escrita e leitura do S3. Adicionamos essas bibliotecas de duas formas diferentes.
No Hive Metastore elas são montadas por meio de volumes diretamente no docker-compose.yaml, os jars estão na pasta libs. Já para o Spark, as dependências são adicionadas no momento da criação da sessão do spark, direramente no Notebook utilizando a propriedade **spark.jars.packages**. O Spark também depende das configurações do Hive Metastore que também é definido no mesmo ponto do Notebook.