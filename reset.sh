#!/bin/bash

echo "Shutting down kioskapp."
systemctl stop kioskapp
docker-compose down
cd /docker
rm -rf /docker/homeassistant/.storage
rm -rf /mnt/ssd/mariadb_data
rm -rf /mnt/ssd/mosquitto
docker-compose build
docker-compose up -d --force-recreate
systemctl start kioskapp
echo "Started kioskapp."
