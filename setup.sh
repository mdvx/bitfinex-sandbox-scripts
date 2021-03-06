#!/bin/bash

# This script is executed inside docker container.

U=$(whoami)
if [ "$U" != "docker" ]; then
	echo "Existing. You should run this script inside docker container!"
	exit 2
fi
if [ -z $GITHUB_TOKEN ]; then
	echo "Please create a token at https://github.com/settings/tokens and set up a GITHUB_TOKEN variable!"
	exit 2
fi

branch=$1
port=$2
workDir="/home/docker"
gitRepo="https://$GITHUB_TOKEN@github.com/tetherto/bitfinex.git"

cd $workDir

# Clone project
git clone -b $branch $gitRepo app/

# Copy configs
sudo cp -r /docker/config/*.yml "$workDir/app/config"
cp /docker/server.rb "$workDir/app"
cp /docker/config/initializers/mailtrap.rb "$workDir/app/config/initializers"
sed -i -e "s/sandbox.bitfinex.com/sandbox.bitfinex.com:$port/g" $workDir/app/config/*.yml

# Install packages
cd "$workDir/app"
echo "gem: --no-rdoc --no-ri" > "$workDir/.gemrc"
source /home/docker/.rvm/scripts/rvm
rvm use 2.0.0
gem update --system
gem install bundler
bundle install -j2
npm install
sudo npm install forever -g

# Start services
sudo service mysql start
sudo service redis-server start

# Start scripts
cd "$workDir/app"
rake db:setup
rake db:migrate
rake db:seed ENABLE_TRADING=1

echo "GRANT ALL PRIVILEGES ON bfxdev.* TO 'remote'@'%' identified by 'AP5FZnadm029n'" | mysql --host=localhost --user=root --password="" bfxdev
export BITFINEX_BASE_URL="http://sandbox.bitfinex.com:$port"
export SIGN_KEY_SEC="$2a$10$OodvD3gpNpRQkezjbMLcDe"
./launchsandbox.sh development .
ruby server.rb
# tail -f log/*
