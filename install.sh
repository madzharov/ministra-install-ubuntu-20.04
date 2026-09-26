#!/usr/bin/env bash


echo ""
echo -e " \e[32mRunning Apt Update & Upgrade...\e[0m"
apt-get update 
apt-get upgrade -y

VERSION="5.6.10"
mysql_root_password="test123456"
stalkerpass="1"
TIME_ZONE="Europe/Amsterdam"
repository="https://raw.githubusercontent.com/madzharov/stalker/main"

echo -e " \e[32mInstalling Initial Packages...\e[0m"
apt-get install -y dialog net-tools wget git curl \
nano sudo unzip sl lolcat software-properties-common \
aview cron lsb-release ca-certificates locales

echo -e " \e[32mSetting locales...\e[0m"
locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo -e " \e[32mTWEAK SYSTEM VALUES\e[0m"
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

echo -e " \e[32mSetting up PHP 7.0 Repository...\e[0m"
#sudo apt-get install -y software-properties-common
#add-apt-repository ppa:ondrej/php -y
curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
#echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ jammy main" | sudo tee /etc/apt/sources.list.d/php.list
apt-get update

echo -e " \e[32mInstalling Nginx...\e[0m"
apt-get install nginx nginx-extras -y
/etc/init.d/nginx stop

echo -e " \e[32mInstalling Apache2...\e[0m"
apt-get install apache2 -y
/etc/init.d/apache2 stop

echo -e " \e[32mInstalling Additional Packages...\e[0m"
apt-get -y install php7.0-dev php7.0-mcrypt php7.0-intl \
php7.0-mbstring php7.0-zip memcached php7.0-memcache \
php7.0 php7.0-xml php7.0-gettext php7.0-soap php7.0-mysql \
php7.0-geoip php-pear nodejs libapache2-mod-php php7.0-curl \
php7.0-imagick php7.0-sqlite3 unzip

echo -e " \e[32mChanging PHP Version...\e[0m"
update-alternatives --set php /usr/bin/php7.0

echo -e " \e[32mInstalling Phing...\e[0m"
pear channel-discover pear.phing.info
pear install phing/phing-2.15.2

echo -e " \e[32mInstalling npm 2.5.11...\e[0m"
apt-get install npm -y
npm config set strict-ssl false
npm install -g npm@2.15.11
ln -sf /usr/bin/nodejs /usr/bin/node || true

echo -e " \e[32mConfiguring Timezone...\e[0m"
sudo ln -sf /usr/share/zoneinfo/Europe/Kyiv /usr/share/zoneinfo/Europe/Kiev
sudo ln -fs /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
sudo dpkg-reconfigure --frontend noninteractive tzdata

echo -e " \e[32mInstalling MySQL Server ...\e[0m"
export DEBIAN_FRONTEND="noninteractive"
echo "mysql-server mysql-server/root_password password $mysql_root_password" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $mysql_root_password" | sudo debconf-set-selections
apt-get install -y mysql-server

echo -e " \e[32mCreating MySQL Users...\e[0m"
mysql -uroot -p$mysql_root_password -e "create database stalker_db;"
mysql -uroot -p$mysql_root_password -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_root_password}';"
mysql -uroot -p$mysql_root_password -e "CREATE USER 'stalker'@'localhost' IDENTIFIED BY '${stalkerpass}';"
mysql -uroot -p$mysql_root_password -e "GRANT ALL ON stalker_db.* TO 'stalker'@'localhost' WITH GRANT OPTION;"
mysql -uroot -p$mysql_root_password -e "ALTER USER 'stalker'@'localhost' IDENTIFIED WITH mysql_native_password BY '${stalkerpass}';"
mysql -uroot -p$mysql_root_password -e "FLUSH PRIVILEGES;"

echo -e " \e[32mConfiguring MySQL...\e[0m"
echo 'sql_mode=""' >> /etc/mysql/mysql.conf.d/mysqld.cnf
#echo 'extension=geoip.so' >> /etc/php/7.0/apache2/php.ini
echo 'default_authentication_plugin=mysql_native_password' >> /etc/mysql/mysql.conf.d/mysqld.cnf
service mysql restart

echo -e " \e[32mInstalling Ministra-$VERSION\e[0m"
cd /var/www/html/
wget $repository/ministra-$VERSION.zip
unzip ministra-5.6.10.zip
rm -rf *.zip
rm /var/www/html/index*
touch /var/www/html/index.php
echo '<?php' >> /var/www/html/index.php
echo 'header("Location:stalker_portal/c/");' >> /var/www/html/index.php
echo '?>' >> /var/www/html/index.php

echo -e " \e[32mConfiguring PHP...\e[0m"
sed -i 's/short_open_tag = Off/short_open_tag = On/g' /etc/php/7.0/apache2/php.ini
ln -s /etc/php/7.0/mods-available/mcrypt.ini /etc/php/8.1/mods-available/
sudo a2dismod mpm_event
sudo a2enmod php7.0
phpenmod mcrypt
a2enmod rewrite
#apt-get purge libapache2-mod-php5filter > /dev/null || true

echo -e " \e[32mSetting up Apache2 Config File...\e[0m"
cd /etc/apache2/sites-enabled/
rm -rf *
wget $repository/000-default.conf
cd /etc/apache2/
rm -rf ports.conf
wget $repository/ports.conf

echo -e " \e[32mSetting up Nginx Config File...\e[0m"
cd /etc/nginx/sites-available/
rm -rf default
wget $repository/default

echo -e " \e[32mSetting up Vendor\e[0m"
rm -rf /var/www/html/stalker_portal/admin/vendor
cd /var/www/html/stalker_portal/admin
wget $repository/vendor.tar
tar -xvf vendor.tar
rm -rf vendor.tar
cd /var/www/html/stalker_portal
cp -a vendor vendor.backup-before-symfony 2>/dev/null || true
cp -a admin/vendor/symfony vendor/ 2>/dev/null || true


echo -e " \e[32mRestarting Apache2 & Nginx...\e[0m"
/etc/init.d/apache2 restart
/etc/init.d/nginx restart

echo -e " \e[32mFixing Smart Launcher...\e[0m"
mkdir /var/www/.npm
chmod 777 /var/www/.npm

# --- COMPOSER 2.2.30 ---
echo -e " \e[32mCOMPOSER 2.3.30\e[0m"
rm -rf  /var/www/html/stalker_portal/deploy/composer/composer.phar
cd /var/www/html/stalker_portal/deploy/composer/
wget $repository/composer_version_2.2.30.phar -O composer.phar
chmod +x composer.phar

echo -e " \e[32mInstalling custom.ini...\e[0m"
cd /var/www/html/stalker_portal/server
wget -O custom.ini $repository/custom.ini

echo -e " \e[32mRunning Phing...\e[0m"
cd /var/www/html/stalker_portal/deploy
sed -i -e 's#zlibc#zlib1g#g' -e 's#php-gettext#gettext php7.0-mbstring#g' build.xml
sed -i 's#self-update 1.9.0#self-update 1.10.28#g' build.xml
sed -i '/composer.deploy.phar --working-dir=${project_path}\/deploy\/ install/i \        <exec command="php ${project_path}\/deploy\/composer\/composer.phar --working-dir=${project_path}\/deploy\/ install --no-dev --no-suggest --no-interaction" level="info" outputProperty="install.error.msg" returnProperty="install.error.code"\/>' build.xml
sed -i '/composer.deploy.phar --working-dir=${project_path}\/deploy\/ministra install/i \        <exec command="php ${project_path}\/deploy\/composer\/composer.phar --working-dir=${project_path}\/deploy\/ministra install --no-dev --no-suggest --no-interaction" level="info" outputProperty="install.error.msg" returnProperty="install.error.code"\/>' build.xml
sed -i "s/mysql -u root -p mysql/mysql -u root -p$mysql_root_password mysql/g" build.xml
sed -i "s/mysql_pass = 1/mysql_pass = $stalkerpass/g" /var/www/html/stalker_portal/server/config.ini


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
echo ""
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
