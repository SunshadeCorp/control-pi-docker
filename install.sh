CREDENTIALS_FILE=/docker/credentials.yaml
ENV_FILE=/docker/.env

echo "Choose a user name for MQTT:"
read input_mqtt_user

echo "Choose a password for MQTT:"
read input_mqtt_pw

# Overwrite credentials file if it exists
if [ -f "$CREDENTIALS_FILE" ]; then
    rm $CREDENTIALS_FILE
fi

# Overwrite .env file if it exists
if [ -f "$ENV_FILE" ]; then
    rm $ENV_FILE
fi

echo "MQTT_USER='${input_mqtt_user}'" >> $ENV_FILE
echo "MQTT_PASSWORD='${input_mqtt_password}'" >> $ENV_FILE

echo "username: '${input_mqtt_user}'" >> $CREDENTIALS_FILE
echo "password: '${input_mqtt_password}'" >> $CREDENTIALS_FILE
echo "mqtt_cert_path: 'path/to/cert.pem'" >> $CREDENTIALS_FILE

# Verify that credentials.yaml exists
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "$CREDENTIALS_FILE does not exist! Could not create credentials file"
    exit 2
fi

# Verify that .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo "$ENV_FILE does not exist! Could not create .env file"
    exit 2
fi

# Output contents of the created files
echo "Created ${ENV_FILE}:"
cat $ENV_FILE

echo "Created ${CREDENTIALS_FILE}:"
cat $CREDENTIALS_FILE

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
