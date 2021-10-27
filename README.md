# ministra-install-ubuntu-20.04
Ministra Portal auto install script

[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/donate?hosted_button_id=4H8VAGMLW5RMA) - You can make one-time donations via PayPal. I'll probably buy a coffe. :coffee: Thanks! :heart:

##### Runs on
[![Ubuntu](https://raw.githubusercontent.com/slaserx/icons/master/64x64/ubuntu.png)](https://www.ubuntu.com)

This script work only on Clean Ubuntu 20.04

Ministra auto install script
  * Version of Ministra 5.6.5

## Installation
```bash
apt-get install git
git clone https://github.com/madzharov/ministra-install-ubuntu-20.04.git
cd ministra-install-ubuntu-20.04/
```

Open minister_install_ubuntu.20.04.sh with your favorite text editor and change on line 17
```bas
mysql_root_pass="test123456"
```
- This is the root password for MySQL that will be set during the installation, you can change it with yours if you wish.


And on line 14 change
```bas
TIME_ZONE="Europe/Sofia"
```
- This is the time zone that will be set during the installation, you can change it with yours if you wish

The installation itself is as follows:
```bas
chmod +x ministra_install_ubuntu.20.04.sh
./ministra_install_ubuntu.20.04.sh
```

- Accordingly, during the installation, when executing the last command, phing will ask you for the root password for MySQL, enter the password you set on line 17



You can access your stalker portal at: http://ipadres/stalker_portal The username and password to login to the portal are your default
```
Login: admin
pass: 1
```

##Video

[![Click to Watch]()](https://www.youtube.com/watch?v=6b2vlc-jPPQ "Click to Watch")


[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/donate?hosted_button_id=4H8VAGMLW5RMA) - You can make one-time donations via PayPal. I'll probably buy a coffe. :coffee: Thanks! :heart:

