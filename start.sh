#!/bin/bash

cd /docker
docker-compose up -d --force-recreate --build
runuser -l pi -c "chromium-browser --display=:0 --kiosk --app=http://localhost:80/"
