#!/bin/bash

# Get user id of the first normal user
USER=$(id -nu 1000)

# Wait until Homeassistant is ready. Is there a better way to do this?
until </dev/tcp/localhost/80; do
    sleep 1s
done

sleep 15s

# Run Chromium as normal user
sudo -u $USER chromium-browser --disable-pinch --display=:0 --kiosk --enable-features=OverlayScrollbar,OverlayScrollbarFlashAfterAnyScrollUpdate,OverlayScrollbarFlashWhenMouseEnter http://localhost:80/
