#!/bin/bash

CREDENTIALS_FILE=/docker/credentials.yaml
ENV_FILE=/docker/.env
MOSQ_PW_FILE=/docker/mosquitto/config/mosquitto.password_file
HA_SECRETS_FILE=/docker/homeassistant/secrets.yaml
FSTAB_FILE=/etc/fstab
MOUNT_PARTITION=/dev/sda1
MOUNT_DIR=/mnt/ssd
MARIADB_DATA_DIR=/mnt/ssd/mariadb_data
TARGET_DIR=/docker

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# Check if the location of the clone is correct
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [[ ! $SCRIPT_DIR == $TARGET_DIR ]]; then
    echo "You are trying to install in ${SCRIPT_DIR}. This script is designed to install in ${TARGET_DIR}. Aborting."
    exit 1
fi

# Load the previous configuration if it exists
if [ -f "$ENV_FILE" ]; then
    source $ENV_FILE
fi

# Check if root user
if [[ ! $(whoami) == "root" ]]; then
    echo "You are not root. This script is designed to be executed as root. Try 'sudo su root'. Aborting."
    exit 1
fi

# Check SSH keys set up
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "SSH keys not found. Please set up SSH keys before installing. Try 'ssh-keygen'."
    exit 2
fi

# Check internet connection
if ! ping -q -w 1 -c 1 github.com > /dev/null; then
    echo "Cannot reach github.com. Are you sure you are connected to the internet? Aborting."
    exit 1
fi

ENV_MQTT_USER="easy-bms"

# Choose MQTT password
while [ -z "$ENV_MQTT_PW" ]; do
    echo "Choose a password for MQTT user 'easy-bms':"
    read ENV_MQTT_PW
    if [ -z "$ENV_MQTT_PW" ]; then
        echo "An empty value is not allowed. Try again."
    fi
done

ENV_MARIADB_USER="homeassistant"

# Choose password for MariaDB user homeassistant
while [ "${#ENV_MARIADB_PW}" -lt 4 ]; do
    echo "Choose a password for MariaDB user 'homeassistant' (>= 4 characters):"
    read ENV_MARIADB_PW
    if [ ${#ENV_MARIADB_PW} -lt 4 ]; then
        echo "It has to be at least 4 characters. Try again."
    fi
done

# Choose password for MariaDB user root
while [ "${#ENV_MARIADB_ROOT_PW}" -lt 4 ]; do
    echo "Choose a password for MariaDB user 'root' (>= 4 characters):"
    read ENV_MARIADB_ROOT_PW
    if [ ${#ENV_MARIADB_ROOT_PW} -lt 4 ]; then
        echo "It has to be at least 4 characters. Try again."
    fi
done

# Overwrite credentials file if it exists
if [ -f "$CREDENTIALS_FILE" ]; then
    rm $CREDENTIALS_FILE
    echo "Replacing ${CREDENTIALS_FILE}."
fi

# Overwrite .env file if it exists
if [ -f "$ENV_FILE" ]; then
    rm $ENV_FILE
    echo "Replacing ${ENV_FILE}."
fi

# Create config files for credentials
echo "ENV_MQTT_USER='${ENV_MQTT_USER}'" >> $ENV_FILE
echo "ENV_MQTT_PW='${ENV_MQTT_PW}'" >> $ENV_FILE
echo "ENV_MARIADB_USER='${ENV_MARIADB_USER}'" >> $ENV_FILE
echo "ENV_MARIADB_PW='${ENV_MARIADB_PW}'" >> $ENV_FILE
echo "ENV_MARIADB_ROOT_PW='${ENV_MARIADB_ROOT_PW}'" >> $ENV_FILE

echo "username: '${ENV_MQTT_USER}'" >> $CREDENTIALS_FILE
echo "password: '${ENV_MQTT_PW}'" >> $CREDENTIALS_FILE
echo "mqtt_cert_path: 'path/to/cert.pem'" >> $CREDENTIALS_FILE

# Verify that credentials.yaml exists
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "$CREDENTIALS_FILE does not exist! Aborting."
    exit 2
fi

# Verify that .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo "$ENV_FILE does not exist! Aborting."
    exit 2
fi

# Print confirmation
echo "Created ${ENV_FILE}."
echo "Created ${CREDENTIALS_FILE}."

# Create mount directory
if [ ! -d "$MOUNT_DIR" ]; then
    mkdir $MOUNT_DIR
    echo "Created ${MOUNT_DIR}."
else
    echo "${MOUNT_DIR} already exists."
fi

# Get UUID of mount partition
uuid_var=$(blkid -s UUID -o value $MOUNT_PARTITION)
blkid_line=$(blkid -o list -w /dev/null | grep $MOUNT_PARTITION)

# Check if mount partition is an ext4 partition
if [[ $blkid_line == *"ext4"* ]]; then
    echo "${MOUNT_PARTITION} is ext4 partition. OK."
else
    echo "${MOUNT_PARTITION} does not exist or is not ext4. Aborting."
    exit 1
fi

# List all:  blkid -o list -w /dev/null
# Add to fstab if it is not contained already
if grep -q "$uuid_var" "$FSTAB_FILE"; then
    echo "${FSTAB_FILE} already has an entry for this partition. Nothing to be done."
else
    echo "Created entry in ${FSTAB_FILE}."
    echo "UUID=${uuid_var} ${MOUNT_DIR} ext4 defaults,nofail 0 0" >> $FSTAB_FILE
fi

# Mount the device
mount -a
echo "Mounted the device."

# Overwrite MariaDB instance on storage device if wanted
if [ -d $MARIADB_DATA_DIR ]; then
    if [[ $@ == *"--keep-db"* ]]; then
        echo "--keep-db: Keeping existing MariaDB database."
    else
        while [ -z "$input_reset_db" ]; do
            echo "There is already a MariaDB database on your storage device. Do you want me to remove it? All data is going to be lost. [yes/no]"
            read input_reset_db
            if [[ $input_reset_db == "yes" ]]; then
                echo "Removing existing MariaDB installation from storage device."
                rm -rf $MARIADB_DATA_DIR
            else
                echo "Using existing MariaDB database on storage device. Make sure your MariaDB credentials are correct."
            fi
        done
    fi
fi

# Update packages
apt-get update -y && apt-get upgrade -y

# Install docker
if command_exists docker; then
    echo "Docker is already installed. OK"
else
    curl -sSL https://get.docker.com | sh
fi

# Install python
apt-get install -y libffi-dev libssl-dev
apt install -y python3-dev
apt-get install -y python3 python3-pip
apt-get install -y python3-pil

# Some Tools for CAN testing
apt-get install -y python3-numpy
pip3 install RPi.GPIO
pip3 install spidev 
pip3 install python-can
apt-get install -y can-utils

# Install docker-compose over pip
pip3 install docker-compose

# Install mosquitto to be able to use mosquitto_passwd on the host
apt install -y mosquitto

# Start containers on boot
systemctl enable docker

# Install requirements for kiosk mode
apt-get install -y chromium-browser
apt-get install -y unclutter

# Install BCM2835
if [ -f /usr/local/include/bcm2835.h ]; then
    echo "BCMS2835 library is already installed. OK."
else
    wget http://www.airspayce.com/mikem/bcm2835/bcm2835-1.60.tar.gz
    tar zxvf bcm2835-1.60.tar.gz 
    cd bcm2835-1.60/
    ./configure
    make
    make check
    make install
    cd ..
    rm -f bcm2835-1.60.tar.gz
    rm -rf bcm2835-1.60/
    # For More：http://www.airspayce.com/mikem/bcm2835/
fi

# Install wiringpi
apt-get install -y wiringpi

# Enable SPI and CAN
# https://www.waveshare.com/wiki/2-CH_CAN_HAT
dtparam spi=on
dtoverlay mcp2515-can1 oscillator=16000000 interrupt=25
dtoverlay mcp2515-can0 oscillator=16000000 interrupt=23

# Enable SPI and CAN on boot
# Dont do this if already done
if grep -q "dtoverlay=mcp2515-can0" /boot/config.txt; then
    echo "/boot/config.txt is already configured."
else
    echo "Configuring /boot/config.txt for CAN"
    echo "dtparam=spi=on" >> /boot/config.txt
    echo "dtoverlay=mcp2515-can1,oscillator=16000000,interrupt=25" >> /boot/config.txt
    echo "dtoverlay=mcp2515-can0,oscillator=16000000,interrupt=23" >> /boot/config.txt
fi

# Setup CAN interfaces
# Create startup service for setting up the CAN interfaces on boot
cp /docker/can-interfaces.service /lib/systemd/system/can-interfaces.service
chmod 644 /lib/systemd/system/can-interfaces.service
systemctl daemon-reload
systemctl enable can-interfaces.service
systemctl start can-interfaces
# /bin/bash can-interfaces.sh

# Create service to open homeassistant in chromium on boot
cp /docker/kioskapp.service /lib/systemd/system/kioskapp.service
chmod 644 /lib/systemd/system/kioskapp.service
systemctl daemon-reload
systemctl enable kioskapp.service

# Clone project repos
git config pull.rebase false
git clone https://github.com/SunshadeCorp/modbus4mqtt /docker/build/modbus4mqtt
git clone git@github.com:SunshadeCorp/relay-control.git --branch next-gen /docker/build/relay-service 
git clone git@github.com:SunshadeCorp/can-byd-raspi.git /docker/build/can-service
git clone git@github.com:SunshadeCorp/EasyBMS-master.git /docker/build/easybms-master
git clone https://github.com/isc-projects/bind9-docker --branch v9.11 /docker/build/bind9-docker

# Copy mqtt credentials configuration file into the service directories
cp -v /docker/credentials.yaml /docker/build/can-service
cp -v /docker/credentials.yaml /docker/build/relay-service
cp -v /docker/credentials.yaml /docker/build/easybms-master

# Create slave mapping file
if [ ! -f /docker/build/easybms-master/slave_mapping.yaml ]; then
    cp -v /docker/build/easybms-master/slave_mapping.example.yaml /docker/build/easybms-master/slave_mapping.yaml
    echo "Created /docker/build/easybms-master/slave_mapping.yaml."
else
    echo "/docker/build/easybms-master/slave_mapping.yaml already exists."
fi

# Overwrite mosquitto password file if it exists
if [ -f "$MOSQ_PW_FILE" ]; then
    rm $MOSQ_PW_FILE
    echo "Replacing ${MOSQ_PW_FILE}."
fi

# Create mosquitto password file
mosquitto_passwd -b -c $MOSQ_PW_FILE $ENV_MQTT_USER $ENV_MQTT_PW && \
echo "Created ${MOSQ_PW_FILE}."

# Remove mosquitto again to stop interfering with docker. Can this be done in a better way?
systemctl stop mosquitto
apt-get purge -y --remove mosquitto*

# Overwrite homeassistant secrets file if it exists
if [ -f "$HA_SECRETS_FILE" ]; then
    rm $HA_SECRETS_FILE
    echo "Replacing ${HA_SECRETS_FILE}."
fi

# Create baseline storage folder for homeassistant
if [ -d /docker/homeassistant/.storage ]; then
    cp -rv storage-template homeassistant/.storage
fi

# Create secrets file for home assistant
echo "recorder_db_url: mysql://${ENV_MARIADB_USER}:${ENV_MARIADB_PW}@mariadb/homeassistant?charset=utf8mb4" >> ${HA_SECRETS_FILE}
echo "mqtt_user: ${ENV_MQTT_USER}" >> ${HA_SECRETS_FILE}
echo "mqtt_password: ${ENV_MQTT_PW}" >> ${HA_SECRETS_FILE}
echo "Created ${HA_SECRETS_FILE}."

# Output credentials for debugging
echo "Use these credentials for debugging:"
cat /docker/.env
