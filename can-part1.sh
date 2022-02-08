# https://www.waveshare.com/wiki/2-CH_CAN_HAT

wget http://www.airspayce.com/mikem/bcm2835/bcm2835-1.60.tar.gz
tar zxvf bcm2835-1.60.tar.gz 
cd bcm2835-1.60/
sudo ./configure
sudo make
sudo make check
sudo make install
# For More：http://www.airspayce.com/mikem/bcm2835/

# Remove build files
rm -f bcm2835-1.60.tar.gz
rm -r bcm2835-1.60/

sudo apt-get install wiringpi
#When used on Raspberry Pi 4B, you may need to upgrade first：
wget https://project-downloads.drogon.net/wiringpi-latest.deb
sudo dpkg -i wiringpi-latest.deb
gpio -v
# Run the command "gpio -v". If the version 2.52 is displayed, the installation is successful

#python2
sudo apt-get update
sudo apt-get install python-pip
sudo apt-get install python-pil
sudo apt-get install python-numpy
sudo pip install RPi.GPIO
sudo pip install spidev
sudo pip2 install python-can
#python3
sudo apt-get update
sudo apt-get install python3-pip
sudo apt-get install python3-pil
sudo apt-get install python3-numpy
sudo pip3 install RPi.GPIO
sudo pip3 install spidev 
sudo pip3 install python-can

echo "dtparam=spi=on" >> /boot/config.txt
echo "dtoverlay=mcp2515-can1,oscillator=16000000,interrupt=25" >> /boot/config.txt
echo "dtoverlay=mcp2515-can0,oscillator=16000000,interrupt=23" >> /boot/config.txt

sudo apt-get install can-utils
