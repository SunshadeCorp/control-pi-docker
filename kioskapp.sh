#!/bin/bash

# Get user id of the first normal user
USER=$(id -nu 1000)

# Run chromium as normal user
runuser -l $USER -c "chromium-browser --display=:0 --kiosk --app=http://localhost:80/"
