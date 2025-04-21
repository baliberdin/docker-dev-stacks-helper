#!/bin/bash

BASEDIR=$(dirname "$0")

for i in `cat ${BASEDIR}/dependencies.txt`
do
  echo "Downloading $i"
  wget -nc -q --show-progress --progress=bar:force:noscroll -P ${BASEDIR} $i
done
echo "All libraries downloaded."