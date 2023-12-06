# need a login shell for running rvm and ruby
# reference: https://stackoverflow.com/questions/9336596/rvm-installation-not-working-rvm-is-not-a-function
#
# If you connect via SSH, run this file using the following command:
# /bin/bash --login install.sh

# update packages
echo "update packages"
sudo apt -y update
sudo apt -y upgrade

# install other required packages
echo "install other required packages"
sudo apt install -y net-tools
sudo apt install -y gnupg2
sudo apt install -y nginx
sudo apt install -y sshpass
sudo apt install -y xterm
sudo apt install -y bc
sudo apt install -y unzip

# get private key for RVM
echo "get private key for RVM"
gpg2 --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
# move into a writable location such as the /tmp to download RVM
# download RVM
echo "download rvm"
cd /tmp
curl -sSL https://get.rvm.io -o rvm.sh
# install the latest stable Rails version
echo "install rvm"
bash /tmp/rvm.sh
# install and run Ruby 3.1.2
echo "install Ruby 3.1.2"
~/.rvm/bin/rvm install 3.1.2
# set 3.1.2 as default Ruby version
echo "set 3.1.2 as default Ruby version"
rvm --default use 3.1.2
# check ruby installed
#ruby -v

# install git
echo "install git"
sudo apt install -y git
# install PostgreSQL dev package with header of PostgreSQL
echo "install PostgreSQL dev package with header of PostgreSQL"
sudo apt-get install -y libpq-dev
# install bundler
echo "install bundler"
gem install bundler -v '2.3.7'

# Install Chrome Driver
# Reference:
# - https://stackoverflow.com/questions/50642308/webdriverexception-unk
#
sudo wget https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/116.0.5845.96/linux64/chromedriver-linux64.zip
sudo chmod 777 chromedriver-linux64.zip
unzip chromedriver-linux64.zip
sudo mv chromedriver-linux64 /usr/bin/chromedriver
sudo chown root:root /usr/bin/chromedriver
sudo chmod +x /usr/bin/chromedriver

