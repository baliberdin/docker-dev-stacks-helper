#!/bin/bash

hdfs dfs -mkdir -p /raw.datalake.mydomain.com
hdfs dfs -chown hive:hive /raw.datalake.mydomain.com