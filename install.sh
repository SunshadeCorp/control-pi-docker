#!/bin/bash

CREDENTIALS_FILE=/docker/credentials.yaml
ENV_FILE=/docker/.env
MOSQ_PW_FILE=/docker/mosquitto/config/mosquitto.password_file
HA_SECRETS_FILE=/docker/homeassistant/secrets.yaml
FSTAB_FILE=/etc/fstab
MOUNT_PARTITION=/dev/sda1
MOUNT_DIR=/mnt/ssd

source $ENV_FILE

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
while [ -z "$ENV_MARIADB_PW" ]; do
    echo "Choose a password for MariaDB user 'homeassistant':"
    read ENV_MARIADB_PW
    if [ -z "$ENV_MARIADB_PW" ]; then
        echo "An empty value is not allowed. Try again."
    fi
done

# Choose password for MariaDB user root
while [ -z "$ENV_MARIADB_ROOT_PW" ]; do
    echo "Choose a password for MariaDB user 'root':"
    read ENV_MARIADB_ROOT_PW
    if [ -z "$ENV_MARIADB_ROOT_PW" ]; then
        echo "An empty value is not allowed. Try again."
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

# Print confirmation
echo "Created ${ENV_FILE}."
echo "Created ${CREDENTIALS_FILE}."

echo "ENV_MQTT_USER='${ENV_MQTT_USER}'" >> $ENV_FILE
echo "ENV_MQTT_PASSWORD='${ENV_MQTT_PW}'" >> $ENV_FILE
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

# Create mount directory
if [ ! -d "$MOUNT_DIR" ]; then
    mkdir $MOUNT_DIR
    echo "Created ${MOUNT_DIR}"
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
    echo "no ext4 partition found. aborting."
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

# Update packages
sudo apt-get update -y && sudo apt-get upgrade -y

# Install docker
curl -sSL https://get.docker.com | sh

# Install python
sudo apt-get install -y libffi-dev libssl-dev
sudo apt install -y python3-dev
sudo apt-get install -y python3 python3-pip

# Install docker-compose over pip
sudo pip3 install docker-compose

# Install mosquitto to be able to use mosquitto_passwd on the host
sudo apt install -y mosquitto

# Start containers on boot
sudo systemctl enable docker

# Clone project repos
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
cp -v /docker/build/easybms-master/slave_mapping.example.yaml /docker/build/easybms-master/slave_mapping.yaml

# Overwrite mosquitto password file if it exists
if [ -f "$MOSQ_PW_FILE" ]; then
    rm $MOSQ_PW_FILE
    echo "Replacing ${MOSQ_PW_FILE}."
fi

# Create mosquitto password file
mosquitto_passwd -b -c $MOSQ_PW_FILE $ENV_MQTT_USER $ENV_MQTT_PASSWORD && \
echo "Created ${MOSQ_PW_FILE}."

# Remove mosquitto again to stop interfering with docker. Can this be done in a better way?
stop mosquitto
apt-get purge -y --remove mosquitto*

# Overwrite homeassistant secrets file if it exists
if [ -f "$HA_SECRETS_FILE" ]; then
    rm $HA_SECRETS_FILE
    echo "Replacing ${HA_SECRETS_FILE}."
fi

# Create secrets file for home assistant
echo "recorder_db_url: mysql://${ENV_MARIADB_USER}:${ENV_MARIADB_PW}@mariadb/homeassistant?charset=utf8mb4" >> ${HA_SECRETS_FILE}
echo "mqtt_user: ${ENV_MQTT_USER}" >> ${HA_SECRETS_FILE}
echo "mqtt_password: ${ENV_MQTT_PW}" >> ${HA_SECRETS_FILE}
echo "Created ${HA_SECRETS_FILE}."

# Output credentials for debugging
echo "Use these credentials for debugging:"
cat /docker/.env
