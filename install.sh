CREDENTIALS_FILE=/docker/credentials.yaml
ENV_FILE=/docker/.env
MOSQ_PW_FILE=/docker/mosquitto/config/mosquitto.password_file
HA_SECRETS_FILE=/docker/homeassistant/secrets.yaml

# Prompt the user for the mqtt credentials
while [ -z "$input_mqtt_user" ]; do
    echo "Choose a user name for MQTT:"
    read input_mqtt_user
    if [ -z "$input_mqtt_user" ]; then
        echo "An empty value is not allowed. Try again."
    fi
done

while [ -z "$input_mqtt_password" ]; do
    echo "Choose a password for MQTT:"
    read input_mqtt_password
    if [ -z "$input_mqtt_password" ]; then
        echo "An empty value is not allowed. Try again."
    fi
done

# Create mariadb credentials
mariadb_user="homeassistant"
mariadb_password=$(date +%s | sha256sum | base64 | head -c 10 ; echo)
mariadb_root_password=$(date +%s | sha256sum | base64 | head -c 12 ; echo)
echo "mariadb password for homeassistant: ${mariadb_password}"
echo "mariadb password for root: ${mariadb_root_password}"

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

echo "MQTT_USER='${input_mqtt_user}'" >> $ENV_FILE
echo "MQTT_PASSWORD='${input_mqtt_password}'" >> $ENV_FILE
echo "ENV_MARIADB_USER='${mariadb_user}'" >> $ENV_FILE
echo "ENV_MARIADB_PW='${mariadb_password}'" >> $ENV_FILE
echo "ENV_MARIADB_ROOT_PW='${mariadb_root_password}'" >> $ENV_FILE

echo "username: '${input_mqtt_user}'" >> $CREDENTIALS_FILE
echo "password: '${input_mqtt_password}'" >> $CREDENTIALS_FILE
echo "mqtt_cert_path: 'path/to/cert.pem'" >> $CREDENTIALS_FILE

# Verify that credentials.yaml exists
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "$CREDENTIALS_FILE does not exist! Could not create credentials file."
    exit 2
fi

# Verify that .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo "$ENV_FILE does not exist! Could not create .env file."
    exit 2
fi

# Print confirmation
echo "Created ${ENV_FILE}."
echo "Created ${CREDENTIALS_FILE}."

# Update packages
sudo apt-get update -y && sudo apt-get upgrade -y

# Install docker
curl -sSL https://get.docker.com | sh

# Install python
sudo apt-get install -y libffi-dev libssl-dev
sudo apt install -y python3-dev
sudo apt-get install -y python3 python3-pip

# Install python over pip
sudo pip3 install docker-compose

# Install mosquitto to be able to use mosquitto_passwd on the host
sudo apt install -y mosquitto

# Start containers on boot
sudo systemctl enable docker

# Clone project repos
git clone https://github.com/SunshadeCorp/modbus4mqtt /docker/build/modbus4mqtt
git clone git@github.com:SunshadeCorp/relay-control.git /docker/build/relay-service
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
mosquitto_passwd -b -c $MOSQ_PW_FILE $input_mqtt_user $input_mqtt_password && \
echo "Created ${MOSQ_PW_FILE}."

# Remove mosquitto again to stop interfering with docker. Can this be done in a better way?
stop mosquitto
apt-get purge --remove mosquitto*

# Overwrite homeassistant secrets file if it exists
if [ -f "$HA_SECRETS_FILE" ]; then
    rm $HA_SECRETS_FILE
    echo "Replacing ${HA_SECRETS_FILE}."
fi

# Add database url to homeassistant configuration
echo "recorder_db_url: mysql://${mariadb_user}:${mariadb_password}@127.0.0.1/homeassistant?charset=utf8mb4" >> ${HA_SECRETS_FILE}
echo "Created ${HA_SECRETS_FILE}."
