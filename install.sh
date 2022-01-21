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
