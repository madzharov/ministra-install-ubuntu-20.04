#!/bin/bash

echo "Updateing system"
sleep 2
apt-get update -y
apt-get upgrade -y
apt-get install net-tools -y

VER="5.6.5"
PRODUCT="Ministra Portal"
PORTAL_WAN="http://`wget -qO- http://ipecho.net/plain | xargs echo`/stalker_portal"
PORTAL_LAN="http://`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`/stalker_portal"
SUPPORTED="Ubuntu 20.04 LTS"
TIME_ZONE="Europe/Amsterdam" #


mysql_root_pass="test123456"
repo="http://vancho.xyz/stalker"





# SET LOCALE TO UTF-8
function setLocale {
	echo "Setting locales..."
	locale-gen en_US.UTF-8  >> /dev/null 2>&1
	export LANG="en_US.UTF-8" >> /dev/null 2>&1
	echo "Done."
}

# TWEAK SYSTEM VALUES
function tweakSystem {
	echo -ne "Tweaking system"
	echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "fs.file-max = 327680" >> /etc/sysctl.conf
	echo "kernel.core_uses_pid = 1" >> /etc/sysctl.conf
	echo "kernel.core_pattern = /var/crash/core-%e-%s-%u-%g-%p-%t" >> /etc/sysctl.conf
	echo "fs.suid_dumpable = 2" >> /etc/sysctl.conf
	sysctl -p >> /dev/null 2>&1
	echo "Done."
}

setLocale;
tweakSystem;

sleep 3

add-apt-repository ppa:ondrej/php -y


echo "Installing libs"
sleep 3
apt-get install nginx nginx-extras -y 
/etc/init.d/nginx stop
sleep 1
apt-get install apache2 -y
/etc/init.d/apache2 stop
sleep 1

apt-get -y install php7.0-geoip php7.0-intl php7.0-memcached php7.0-tidy php7.0-igbinary php7.0-msgpack php7.0-mcrypt php7.0-mbstring php7.0-zip memcached php7.0-memcache php7.0 php7.0-xml php7.0-gettext php7.0-soap php7.0-mysql php-pear nodejs libapache2-mod-php php7.0-curl php7.0-imagick php7.0-sqlite3 unzip net-tools
update-alternatives --set php /usr/bin/php7.0

sleep 2

echo "Installing phing"
sleep 3
pear channel-discover pear.phing.info
pear install --alldeps phing/phing-2.15.2

echo "installing npm 2.15.11"
sleep 3
# Install NPM  2.15.11
apt-get install npm -y
npm config set strict-ssl false
npm install -g npm@2.15.11
ln -s /usr/bin/nodejs /usr/bin/node

echo "Configure timezone"
sleep 3
echo "$TIME_ZONE" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata


echo "Installing mysql server"
sleep 3
export DEBIAN_FRONTEND="noninteractive"
echo "mysql-server mysql-server/root_password password $mysql_root_pass" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $mysql_root_pass" | sudo debconf-set-selections
apt-get install -y mysql-server
sed -i 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/mysql/my.cnf
mysql -uroot -p$mysql_root_pass -e "USE mysql; UPDATE user SET Host='%' WHERE User='root' AND Host='localhost'; DELETE FROM user WHERE Host != '%' AND User='root'; FLUSH PRIVILEGES;"
mysql -uroot -p$mysql_root_pass -e "create database stalker_db;"
mysql -uroot -p$mysql_root_pass -e "ALTER USER root IDENTIFIED WITH mysql_native_password BY '"$mysql_root_pass"';"
mysql -uroot -p$mysql_root_pass -e "CREATE USER stalker IDENTIFIED BY '1';"
mysql -uroot -p$mysql_root_pass -e "GRANT ALL ON *.* TO stalker WITH GRANT OPTION;"
mysql -ustalker -p1 -e "ALTER USER stalker IDENTIFIED WITH mysql_native_password BY '1';"


echo 'sql_mode=""' >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf
service mysql restart

echo "Installing " $PRODUCT $VER " . . "
sleep 3
cd /var/www/html/
wget $repo/ministra-$VER.zip
unzip ministra-$VER.zip
rm -rf *.zip


sed -i 's/short_open_tag = Off/short_open_tag = On/g' /etc/php/7.0/apache2/php.ini
ln -s /etc/php/7.0/mods-available/mcrypt.ini /etc/php/8.0/mods-available/
phpenmod mcrypt
a2enmod rewrite
apt-get purge libapache2-mod-php5filter > /dev/null


cd /etc/apache2/sites-enabled/
rm -rf *
wget $repo/000-default.conf
cd /etc/apache2/
rm -rf ports.conf
wget $repo/ports.conf
cd /etc/nginx/sites-available/
rm -rf default
wget $repo/default
/etc/init.d/apache2 restart
/etc/init.d/nginx restart
sleep 1
rm -rf /var/www/html/stalker_portal/admin/vendor
cd /var/www/html/stalker_portal/admin
wget $repo/vendor.tar
tar -xvf vendor.tar
sleep 1


# Fix Smart Launcher Applications
mkdir /var/www/.npm
chmod 777 /var/www/.npm

#Patch Composer
cd /var/www/html/stalker_portal
wget $repo/composer_version_1.9.1.patch
patch -p1 < composer_version_1.9.1.patch

cd /var/www/html/stalker_portal/server
wget -O custom.ini $repo/custom.ini
cd

cd /var/www/html/stalker_portal/deploy
sed -i 's/php-gettext/php7.0-gettext/g' build.xml
sudo phing
sleep 1

echo ""
echo "-------------------------------------------------------------------"
echo ""
echo " Install Complete !"
echo ""
echo " Default username is: admin"
echo " Default password is: 1"
echo ""
echo " PORTAL WAN : $PORTAL_WAN"
echo " PORTAL LAN : $PORTAL_LAN"
echo " Mysql User : root"
echo " MySQL Pass : $mysql_root_pass"
echo ""
echo " Change admin panel password :"
echo " mysql -u root -p"
echo " use stalker_db;"
echo " update administrators set pass=MD5('new_password_here') where login='admin';"
echo " quit;"
echo " Logout from web panel and Login with new password."
echo ""
echo " Remove all channels from the database through the terminal:"
echo " mysql -u root -p stalker_db"
echo " truncate ch_links;"
echo " truncate itv;"
echo " quit;"
echo ""
echo "--------------------------------------------------------------------"
echo ""
