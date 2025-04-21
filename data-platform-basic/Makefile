access-jupyterhub: JUPYTERHUB_URL = $(shell cat ./jupyter.log | grep http://127.0.0.1:8888 | sed -e 's/^[ \t]*//g' | grep -v Server)

start-localstack:
	@echo "Starting LocalStack..."
	@docker compose up -d --wait localstack
	@echo "LocalStack started."

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

perform-terraform-apply:
	@echo "Applying Terraform configuration..."
	@cd terraform && terraform init && terraform apply -auto-approve
	@echo "Terraform configuration applied."

start-all: download-dependencies start-localstack perform-terraform-apply start-hive-metastore start-trino start-jupyterhub 
	@echo "All services started and Terraform applied."

stop-all:
	@echo "Stopping LocalStack..."
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
	./libs/download-libs.sh