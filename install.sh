#!/bin/bash

echo -e " \e[32mUpdating system\e[0m"
sleep 2
apt-get update -y
apt-get upgrade -y
apt-get install net-tools curl lsb-release ca-certificates unzip -y 

VERSION="5.6.10"
TIME_ZONE="Europe/Amsterdam"
mysql_root_password="test123456"
repository="https://raw.githubusercontent.com/madzharov/stalker/main"

# SET LOCALE TO UTF-8
function setLocale {
	echo -e " \e[32mSetting locales\e[0m"
	locale-gen en_US.UTF-8 >> /dev/null 2>&1
	export LANG="en_US.UTF-8" >> /dev/null 2>&1
	echo -e " \e[32mDone.\e[0m"
}

# TWEAK SYSTEM VALUES
function tweakSystem {
	echo -ne "\e[32mTweaking system\e[0m"
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

echo -e " \e[32mAdd Sury PHP repository\e[0m"
curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
apt-get update -y

echo -e " \e[32mInstall required packages\e[0m"
sleep 2
apt-get install nginx nginx-extras -y 
/etc/init.d/nginx stop
apt-get install apache2 -y
/etc/init.d/apache2 stop

apt-get install php7.0-geoip php7.0-intl php7.0-tidy php7.0-igbinary php7.0-msgpack php7.0-mcrypt php7.0-mbstring php7.0-zip memcached php7.0-memcached php7.0 php7.0-xml php7.0-gettext php7.0-soap php7.0-mysql php-pear nodejs libapache2-mod-php7.0 php7.0-curl php7.0-imagick php7.0-sqlite3 unzip -y
update-alternatives --set php /usr/bin/php7.0

echo -e " \e[32mInstalling phing\e[0m"
# pear channel-discover pear.phing.info
# pear install --alldeps phing/phing-2.15.2
pear channel-discover pear.phing.info || true
pear install phing/phing-2.15.2

echo -e " \e[32mInstalling npm\e[0m"
apt-get install npm -y
npm config set strict-ssl false
npm install -g npm@2.15.11

echo -e " \e[32mSet Timezone\e[0m"
timedatectl set-timezone $TIME_ZONE

echo -e " \e[32mInstalling mysql server\e[0m"
sleep 3
export DEBIAN_FRONTEND="noninteractive"
echo "mysql-server mysql-server/root_password password $mysql_root_password" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $mysql_root_password" | sudo debconf-set-selections
apt-get install mysql-server -y

# Set IP listening to 0.0.0.0
sed -i 's/127\.0\.0\.1/0\.0\.0\.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf

# Add global compatibility settings for Stalker / Ministra
echo 'sql_mode=""' >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf
service mysql restart

# Create database and users directly with mysql_native_password
mysql -uroot -p$mysql_root_password -e "CREATE DATABASE IF NOT EXISTS stalker_db;"

# Configure root user
mysql -uroot -p$mysql_root_password -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysql_root_password';"
mysql -uroot -p$mysql_root_password -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$mysql_root_password';"
mysql -uroot -p$mysql_root_password -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"

# Create and configure the stalker user with mysql_native_password for localhost and %
mysql -uroot -p$mysql_root_password -e "CREATE USER IF NOT EXISTS 'stalker'@'%' IDENTIFIED WITH mysql_native_password BY '1';"
mysql -uroot -p$mysql_root_password -e "CREATE USER IF NOT EXISTS 'stalker'@'localhost' IDENTIFIED WITH mysql_native_password BY '1';"
mysql -uroot -p$mysql_root_password -e "GRANT ALL PRIVILEGES ON *.* TO 'stalker'@'%' WITH GRANT OPTION;"
mysql -uroot -p$mysql_root_password -e "GRANT ALL PRIVILEGES ON *.* TO 'stalker'@'localhost' WITH GRANT OPTION;"

mysql -uroot -p$mysql_root_password -e "FLUSH PRIVILEGES;"
service mysql restart

echo -e " \e[32mInstalling Ministra Portal $VERSION \e[0m"
cd /var/www/html/
wget $repository/ministra-$VERSION.zip
unzip ministra-$VERSION.zip
rm -rf *.zip

# If the stalker_portal folder does not exist and ministra-5.6.10 was created instead:
if [ -d "ministra-$VERSION" ]; then
    mv ministra-$VERSION stalker_portal
fi

sed -i 's/short_open_tag = Off/short_open_tag = On/g' /etc/php/7.0/apache2/php.ini
phpenmod mcrypt
a2enmod rewrite

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

rm -rf /var/www/html/stalker_portal/admin/vendor
cd /var/www/html/stalker_portal/admin
wget $repository/vendor.tar
tar -xvf vendor.tar
rm -rf vendor.tar
cd /var/www/html/stalker_portal
cp -a vendor vendor.backup-before-symfony 2>/dev/null || true
cp -a admin/vendor/symfony vendor/ 2>/dev/null || true

mkdir -p /var/www/.npm
chmod 777 /var/www/.npm

cd /var/www/html/stalker_portal/server
wget -O custom.ini $repository/custom.ini

cd /var/www/html/stalker_portal/deploy
sed -i 's#apt-get -y install zlibc curl php-sqlite3 php-soap php-intl php-gettext php-memcache php-memcached php-curl php-mysql php-mcrypt php-tidy php-imagick php-geoip curl npm git zip unzip php-zip#apt-get install -y zlib1g curl php7.0-sqlite3 php-soap php7.0-intl php7.0-gettext php7.0-memcache php7.0-memcached php7.0-curl php7.0-mysql php7.0-mcrypt php7.0-tidy php7.0-imagick php7.0-geoip curl npm git zip unzip php7.0-zip#g' build.xml
sed -i 's#php5enmod#phpenmod#g' build.xml
sed -i 's#php5dismod#phpdismod#g' build.xml
#sed -i 's#composer-5.5.9.lock#composer-7.0.lock#g' build.xml
#sed -i 's#composer-5.5.9-ministra.lock#composer-7.0-ministra.lock#g' build.xml
sed -i -e 's#zlibc#zlib1g#g' -e 's#php-gettext#gettext php7.0-mbstring#g' build.xml
sed -i 's#self-update 1.9.0#self-update 1.10.28#g' build.xml
sed -i '/composer.deploy.phar --working-dir=${project_path}\/deploy\/ install/i \        <exec command="php ${project_path}\/deploy\/composer\/composer.phar --working-dir=${project_path}\/deploy\/ install --no-dev --no-suggest --no-interaction" level="info" outputProperty="install.error.msg" returnProperty="install.error.code"\/>' build.xml
sed -i '/composer.deploy.phar --working-dir=${project_path}\/deploy\/ministra install/i \        <exec command="php ${project_path}\/deploy\/composer\/composer.phar --working-dir=${project_path}\/deploy\/ministra install --no-dev --no-suggest --no-interaction" level="info" outputProperty="install.error.msg" returnProperty="install.error.code"\/>' build.xml

# --- COMPOSER 1.9.0 ---
echo -e " \e[32m COMPOSER 1.9.0 \e[0m"
rm -rf  /var/www/html/stalker_portal/deploy/composer/composer.phar
cd /var/www/html/stalker_portal/deploy/composer/
wget $repository/composer_version_2.2.30.phar -O composer.phar
chmod +x composer.phar
cd /var/www/html/stalker_portal/deploy

phing

chown -R www-data:www-data /var/www/html/stalker_portal
systemctl restart apache2
systemctl restart nginx

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
