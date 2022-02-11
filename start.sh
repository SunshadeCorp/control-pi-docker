#!/bin/bash

cd /docker
docker-compose up -d --force-recreate --build
#chromium-browser --incognito --kiosk http://localhost:80/
