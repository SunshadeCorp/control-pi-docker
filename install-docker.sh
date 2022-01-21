# Update packages
sudo apt-get update && sudo apt-get upgrade

# Install docker
curl -sSL https://get.docker.com | sh

# Install python
sudo apt-get install -y libffi-dev libssl-dev
sudo apt install -y python3-dev
sudo apt-get install -y python3 python3-pip

# Install python over pip
sudo pip3 install -y docker-compose

# Start containers on boot
sudo systemctl enable docker
