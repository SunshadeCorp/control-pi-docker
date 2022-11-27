#!/bin/bash

cd /docker
docker compose up -d --force-recreate --build
systemctl start kioskapp
