#!/bin/bash

echo -e " \e[32mUpdateing system\e[0m"
sleep 2
apt-get update -y
apt-get upgrade -y
apt-get install net-tools -y 

VERSION="5.6.8"
TIME_ZONE="Europe/Amsterdam" #
mysql_root_password="test123456"
repository="https://bob-tv-previous-customize.trycloudflare.com/stalker"

# SET LOCALE TO UTF-8
function setLocale {
	echo -e " \e[32mSetting locales\e[0m"
	locale-gen en_US.UTF-8  >> /dev/null 2>&1
	export LANG="en_US.UTF-8" >> /dev/null 2>&1
	echo -e " \e[32mDone.\e[0m"
}

# TWEAK SYSTEM VALUES
function tweakSystem {
	echo -ne "\e[32mTweaking system"
	echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "fs.file-max = 327680" >> /etc/sysctl.conf
	echo "kernel.core_uses_pid = 1" >> /etc/sysctl.conf
	echo "kernel.core_pattern = /var/crash/core-%e-%s-%u-%g-%p-%t" >> /etc/sysctl.conf
	echo "fs.suid_dumpable = 2" >> /etc/sysctl.conf
	sysctl -p >> /dev/null 2>&1
	echo -e " \e[32mDone.\e[0m"
}

setLocale;
tweakSystem;

sleep 3

add-apt-repository ppa:ondrej/php -y

echo -e " \e[32mInstall required packages\e[0m"
sleep 3
apt-get install nginx nginx-extras -y 
/etc/init.d/nginx stop
sleep 1
apt-get install apache2 -y
/etc/init.d/apache2 stop
sleep 1

apt-get -y install php7.0-geoip php7.0-intl php7.0-tidy php7.0-igbinary php7.0-msgpack php7.0-mcrypt php7.0-mbstring php7.0-zip memcached php7.0-memcached php7.0 php7.0-xml php7.0-gettext php7.0-soap php7.0-mysql php-pear nodejs libapache2-mod-php7.0 php7.0-curl php7.0-imagick php7.0-sqlite3 unzip
update-alternatives --set php /usr/bin/php7.0

sleep 2

echo -e " \e[32mInstalling phing\e[0m"
sleep 3
pear channel-discover pear.phing.info
pear install --alldeps phing/phing-2.15.2

echo -e " \e[32minstalling npm 2.15.11\e[0m"
sleep 3
# Install NPM  2.15.11
apt-get install npm -y
npm config set strict-ssl false
npm install -g npm@2.15.11
# ln -s /usr/bin/nodejs /usr/bin/node

echo -e " \e[32mSet the Server Timezone to EDT\e[0m"
sleep 3
timedatectl set-timezone $TIME_ZONE
dpkg-reconfigure -f noninteractive tzdata


echo -e " \e[32mInstalling mysql server\e[0m"
sleep 3
export DEBIAN_FRONTEND="noninteractive"
echo "mysql-server mysql-server/root_password password $mysql_root_password" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $mysql_root_password" | sudo debconf-set-selections
apt-get install -y mysql-server
# sed -i 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/mysql/my.cnf
sed -i 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
mysql -uroot -p$mysql_root_password -e "USE mysql; UPDATE user SET Host='%' WHERE User='root' AND Host='localhost'; DELETE FROM user WHERE Host != '%' AND User='root'; FLUSH PRIVILEGES;"
mysql -uroot -p$mysql_root_password -e "create database stalker_db;"
mysql -uroot -p$mysql_root_password -e "ALTER USER root IDENTIFIED WITH mysql_native_password BY '"$mysql_root_password"';"
mysql -uroot -p$mysql_root_password -e "CREATE USER stalker IDENTIFIED BY '1';"
mysql -uroot -p$mysql_root_password -e "GRANT ALL ON *.* TO stalker WITH GRANT OPTION;"
mysql -ustalker -p1 -e "ALTER USER stalker IDENTIFIED WITH mysql_native_password BY '1';"


echo 'sql_mode=""' >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf
service mysql restart

echo -e " \e[32mInstalling Ministra Portal $VERSION \e[0m"
sleep 3
cd /var/www/html/
wget $repository/ministra-$VERSION.zip
unzip ministra-$VERSION.zip
rm -rf *.zip


sed -i 's/short_open_tag = Off/short_open_tag = On/g' /etc/php/7.0/apache2/php.ini
ln -s /etc/php/7.0/mods-available/mcrypt.ini /etc/php/8.0/mods-available/
phpenmod mcrypt
a2enmod rewrite
# apt-get purge libapache2-mod-php5filter > /dev/null


cd /etc/apache2/sites-enabled/
rm -rf *
wget $repository/000-default.conf
cd /etc/apache2/
rm -rf ports.conf
wget $repository/ports.conf
cd /etc/nginx/sites-available/
rm -rf default
wget $repository/default
/etc/init.d/apache2 restart
/etc/init.d/nginx restart
sleep 1
rm -rf /var/www/html/stalker_portal/admin/vendor
cd /var/www/html/stalker_portal/admin
wget $repository/vendor.tar
tar -xvf vendor.tar
sleep 1


# Fix Smart Launcher Applications
mkdir /var/www/.npm
chmod 777 /var/www/.npm

cd /var/www/html/stalker_portal/server
wget -O custom.ini $repository/custom.ini
cd

cd /var/www/html/stalker_portal/deploy
sed -i 's/apt-get -y install zlibc curl php-sqlite3 php-soap php-intl php-gettext php-memcache php-memcached php-curl php-mysql php-mcrypt php-tidy php-imagick php-geoip curl npm git zip unzip php-zip/apt-get -y install zlibc curl php7.0-sqlite3 php-soap php7.0-intl php7.0-gettext php7.0-memcache php7.0-memcached php7.0-curl php7.0-mysql php7.0-mcrypt php7.0-tidy php7.0-imagick php7.0-geoip curl npm git zip unzip php7.0-zip/' build.xml
sed -i 's/php5enmod/phpenmod/g' build.xml
sed -i 's/php5dismod/phpdismod/g' build.xml
sudo phing
sleep 1

echo -e " \e[32m-------------------------------------------------------------------"
echo -e " \e[0mInstall Complete !"
echo ""
echo -e " \e[0mDefault username is: \e[32madmin"
echo -e " \e[0mDefault password is: \e[32m1"
echo ""
echo -e " \e[0mPORTAL WAN : \e[32mhttp://`wget -qO- http://ipecho.net/plain | xargs echo`/stalker_portal"
echo -e " \e[0mPORTAL LAN : \e[32mhttp://`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`/stalker_portal"
echo -e " \e[0mMysql User : \e[32mroot"
echo -e " \e[0mMySQL Pass : \e[32m$mysql_root_password"
echo ""
echo -e " \e[0mChange admin panel password through the terminal :"
echo -e " \e[32mmysql -u root -p"
echo -e " \e[32muse stalker_db;"
echo -e " \e[32mupdate administrators set pass=MD5('new_password_here') where login='admin';"
echo -e " \e[32mquit;"
echo -e " \e[0mLogout from web panel and Login with new password."
echo ""
echo -e " \e[0mRemove all test channels from the database through the terminal :"
echo -e " \e[32mmysql -u root -p stalker_db"
echo -e " \e[32mtruncate ch_links;"
echo -e " \e[32mtruncate itv;"
echo -e " \e[32mquit;"
echo -e " \e[32m--------------------------------------------------------------------\e[0m"
