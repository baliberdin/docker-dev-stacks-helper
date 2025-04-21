access-jupyterhub: JUPYTERHUB_URL = $(shell cat ./jupyter.log | grep http://127.0.0.1:8888 | sed -e 's/^[ \t]*//g' | grep -v Server)

start-hadoop:
	@echo "Starting Hadoop..."
	@docker compose up -d --wait hadoop-namenode hadoop-datanode hadoop-resourcemanager hadoop-nodemanager
	@echo "Hadoop started."

create-hdfs-dir:
	@echo "Creating HDFS directories..."
	@docker exec -it hadoop-namenode bash -c "/tmp/create_dir.sh"
	@echo "HDFS directories created."

start-hive-metastore: download-dependencies
	@echo "Starting Hive Metastore..."
	@docker compose up -d --wait hive-metastore hive-metastore-db
	@echo "Hive Metastore started."

start-jupyterhub: download-dependencies
	@echo "Starting JupyterHub..."
	@docker compose up -d --wait jupyterhub
	@echo "JupyterHub started."

start-trino:
	@echo "Starting Trino..."
	@docker compose up -d --wait trino
	@echo "Trino started."

start-all: download-dependencies start-hadoop create-hdfs-dir start-hive-metastore start-trino start-jupyterhub 
	@echo "All services started and Terraform applied."

stop-all:
	@echo "Stopping Stack..."
	@docker compose down

read-jupyter-log:
	@docker logs jupyterhub 2> ./jupyter.log 1> /dev/null 0> /dev/null

access-jupyterhub: read-jupyter-log
	@echo "Access to JupyterHub"
	@echo Open your browser and go to:
	@echo ${JUPYTERHUB_URL}
	@rm -rf ./jupyter.log
	@xdg-open ${JUPYTERHUB_URL}

download-dependencies:
	@./libs/download-libs.sh