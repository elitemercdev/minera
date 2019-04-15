#!/bin/bash
# This is the main install script for Minera https://github.com/getminera/minera
# This script, as Minera, is intended to be used on a Debian-like system

echo -e "-----\nSTART Minera Install script\n-----\n"
cd /var/www/minera

echo -e "-----\nFixing locales\n-----\n"
apt-get update
LANG=en_US.UTF-8
apt-get install -y locales
sed -i -e "s/# $LANG.*/$LANG.UTF-8 UTF-8/" /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales
update-locale LANG=$LANG

echo -e "-----\nInstall extra packages\n-----\n"
DEBIAN_FRONTEND=noninteractive apt-get -yq install build-essential libblkmaker-0.1-dev libtool libcurl4-openssl-dev libjansson-dev libudev-dev libncurses5-dev autoconf automake postfix redis-server git screen php7.0-cli php7.0-curl php7.0-fpm php7.0-readline php7.0-json wicd-curses uthash-dev libmicrohttpd-dev libevent-dev libusb-dev libusb-dev shellinabox supervisor lighttpd libssl-dev
echo -e "Adding Minera user\n-----\n"
adduser minera --gecos "" --disabled-password
echo "minera:minera" | chpasswd

echo -e "Adding groups to Minera\n-----\n"
usermod -a -G dialout,plugdev,tty,www-data minera

echo -e "Adding sudoers configuration for www-data and minera users\n-----\n"
echo -e "\n#Minera settings\nminera ALL = (ALL) NOPASSWD: ALL\nwww-data ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers

MINER_OPT="--gc3355-detect --gc3355-autotune --freq=850 -o stratum+tcp://us.multipool.us:7777 -u michelem.minera -p x --retries=1"
MINER_BIN=`pwd`"/minera-bin/"
MINERA_LOGS="/var/log/minera"
MINERA_CONF=`pwd`"/conf"
MINERA_OLD_LOGS=`pwd`"/application/logs"

echo -e "Adding SSL certificate\n-----\n"
mkdir /etc/lighttpd/certs
cp $MINERA_CONF/lighttpd.pem /etc/lighttpd/certs/
chmod 400 /etc/lighttpd/certs/lighttpd.pem

echo -e "Copying Lighttpd conf\n-----\n"
cp $MINERA_CONF/lighttpd.conf /etc/lighttpd/
cp $MINERA_CONF/10-fastcgi.conf /etc/lighttpd/conf-available/10-fastcgi.conf
cp $MINERA_CONF/15-php-fpm.conf /etc/lighttpd/conf-available/15-php-fpm.conf
ln -s /etc/lighttpd/conf-available/10-fastcgi.conf /etc/lighttpd/conf-enabled/10-fastcgi.conf
ln -s /etc/lighttpd/conf-available/15-php-fpm.conf  /etc/lighttpd/conf-enabled/15-php-fpm.conf 
service lighttpd restart

echo -e "Playing with minera dirs\n-----\n"
chown -R minera.minera `pwd`
mkdir -p $MINERA_LOGS
chmod 777 $MINERA_LOGS
chmod 777 $MINERA_CONF
chmod 777 minera-bin/cgminerStartupScript
chown -R minera.minera $MINERA_LOGS
rm -rf $MINERA_OLD_LOGS
ln -s $MINERA_LOGS $MINERA_OLD_LOGS

echo -e "Adding Minera logrotate\n-----\n"
cp `pwd`"/minera.logrotate" /etc/logrotate.d/minera
service rsyslog restart

echo -e "Adding default startup settings to redis\n-----\n"
echo -n $MINER_OPT | redis-cli -x set minerd_settings
echo -n "70e880b1effe0f770849d985231aed2784e11b38" | redis-cli -x set minera_password
echo -n "1" | redis-cli -x set guided_options
echo -n "0" | redis-cli -x set manual_options
echo -n "1" | redis-cli -x set minerd_autodetect
echo -n "1" | redis-cli -x set anonymous_stats
echo -n "0" | redis-cli -x set browserMining
echo -n "1" | redis-cli -x set is_ads_free
echo -n "cpuminer" | redis-cli -x set minerd_software
echo -n '["132","155","3"]' | redis-cli -x set dashboard_coin_rates
#echo -e '[{"url":"stratum+tcp://us.multipool.us:7777","username":"michelem.minera","password":"x"}]'  | redis-cli -x set minerd_pools
redis-cli del mac
redis-cli del minera_system_id

echo -e "Adding minera startup command to rc.local\n-----\n"
chmod 777 /etc/rc.local

RC_LOCAL_CMD='su - minera -c "/usr/bin/screen -dmS cpuminer '$MINER_BIN'minerd '$MINER_OPT'"\nexit 0'

sed -i.bak "s/exit 0//g" /etc/rc.local

echo -e $RC_LOCAL_CMD >> /etc/rc.local

echo -e "Adding cron file in /etc/cron.d\n-----\n"

echo -e "*/1 * * * * www-data php `pwd`/index.php app cron" > /etc/cron.d/minera

echo -e "Configuring shellinabox\n-----\n"
sudo cp conf/shellinabox /etc/default/
sudo service shellinabox restart

echo -e "Copying cg/bfgminer udev rules\n-----\n"
sudo cp conf/01-cgminer.rules /etc/udev/rules.d/
sudo cp conf/70-bfgminer.rules /etc/udev/rules.d/
sudo service udev restart

echo -e "Installing NVM and Node requirements\n-----\n"
su - minera -c /var/www/minera/install_nvm.sh

echo -e "Generating unique SSH keys\n-----\n"
sudo rm /etc/ssh/ssh_host_*
sudo dpkg-reconfigure openssh-server
sudo service ssh restart

echo -e "Building miners, this will take loooooooot of time in a low resource system, I strongly suggest you to take a beer (better two) and relax a while. Your Minera will be ready after this.\n-----\n"
su - minera -c "/var/www/minera/build_miner.sh all"

echo -e 'DONE! Minera is ready!\n\nOpen the URL: http://'$(hostname -I | tr -d ' ')'/minera/\n\nAnd happy mining!\n'
