#!/bin/bash

# Get user id of the first normal user
USER=$(id -nu 1000)

# Wait until Homeassistant is ready. Is there a better way to do this?
until </dev/tcp/localhost/80; do 
    sleep 1s
done
sleep 5s

# Run Chromium as normal user
sudo -u $USER chromium-browser --display=:0 --kiosk http://localhost:80/
