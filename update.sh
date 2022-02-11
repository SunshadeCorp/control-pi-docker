#!/bin/bash

systemctl stop kioskapp
docker-compose down
git pull
cd /docker/build/easybms-master && git pull
cd /docker/build/can-service && git pull
cd /docker/build/relay-service && git pull
cd /docker/build/bind9-docker && git pull
cd /docker/build/modbus4mqtt && git pull
cd /docker
./install.sh --keep-db
docker-compose build
docker-compose up -d --force-recreate
systemctl start kioskapp
