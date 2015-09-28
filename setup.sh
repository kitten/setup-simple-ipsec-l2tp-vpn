#!/bin/sh
#    Setup Simple IPSec/L2TP VPN server for Ubuntu and Debian
#
#    Copyright (C) 2014-2015 Phil Plückthun <phil@plckthn.me>
#    Copyright (C) 2015 Edwin Ang <edwin@theroyalstudent.com> for hotfixes
#    Based on the work of Lin Song (Copyright 2014)
#    Based on the work of Viljo Viitanen (Setup Simple PPTP VPN server for Ubuntu and Debian)
#    Based on the work of Thomas Sarlandie (Copyright 2012)
#
#    This work is licensed under the Creative Commons Attribution-ShareAlike 3.0
#    Unported License: http://creativecommons.org/licenses/by-sa/3.0/

if [ `id -u` -ne 0 ]
then
  echo "Please start this script with root privileges!"
  echo "Try again with sudo."
  exit 0
fi

lsb_release -c | grep trusty > /dev/null
if [ "$?" = "1" ]
then
  echo "This script was designed to run on Ubuntu 14.04 Trusty!"
  echo "Do you wish to continue anyway?"
  while true; do
    read -p "" yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) exit 0;;
      * ) echo "Please answer with Yes or No [y|n].";;
    esac
  done
  echo ""
fi

echo "This script will install an IPSec/L2TP VPN Server"
echo "Do you wish to continue?"

while true; do
  read -p "" yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) exit 0;;
    * ) echo "Please answer with Yes or No [y|n].";;
  esac
done

echo ""

# Generate a random key
generateKey () {
  P1=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
  P2=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
  P3=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
  P4=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
  IPSEC_PSK="$P1$P2$P3$P4"
}

echo "The VPN needs a private PSK key."
echo "Do you wish to set it yourself?"
echo "(Otherwise a random key is generated)"
while true; do
  read -p "" yn
  case $yn in
    [Yy]* ) echo ""; echo "Enter your preferred key:"; read -p "" IPSEC_PSK; break;;
    [Nn]* ) generateKey; break;;
    * ) echo "Please answer with Yes or No [y|n].";;
  esac
done

echo ""
echo "The key you chose is: '$IPSEC_PSK'."
echo "Please save it, because you'll need it to connect!"
echo ""

read -p "Please enter your preferred username [vpn]: " VPN_USER

if [ "$VPN_USER" = "" ]
then
  VPN_USER="vpn"
fi

echo ""

while true; do
  stty_orig=`stty -g`
  stty -echo
  read -p "Please enter your preferred password: " VPN_PASSWORD
  if [ "x$VPN_PASSWORD" = "x" ]
  then
    echo "Please enter a valid password!"
  else
    stty $stty_orig
    break
  fi
done

echo ""
echo ""

echo "Making sure that apt-get is updated and wget is installed..."
echo ""

apt-get update > /dev/null

if [ `sudo dpkg-query -l | grep wget | wc -l` = 0 ] ; then
  apt-get install wget -y  > /dev/null
fi

echo "What type of connection will you be using this VPN server on?"
echo "Enter the corresponding number for:"
echo "4) IPv4"
echo "6) IPv6"

while true; do
  read -p "" yn
  case $yn in
    [4]* ) PUBLICIP=`wget -q -O - http://ipv4.wtfismyip.com/text`; break;;
    [6]* ) PUBLICIP=`wget -q -O - http://ipv6.wtfismyip.com/text`; break;;
    * ) echo "Please answer with 4 or 6 [4|6].";;
  esac
done

if [ "x$PUBLICIP" = "x" ]
then
  echo "Your server's external IP address could not be detected!"
  echo "Please enter the IP yourself:"
  read -p "" PUBLICIP
else
  echo "Detected your server's external IP address: $PUBLICIP"
fi

PRIVATEIP=$(ip addr | awk '/inet/ && /eth0/{sub(/\/.*$/,"",$2); print $2}')
IPADDRESS=$PUBLICIP

echo ""
echo "Are you on Amazon EC2?"
echo "If you answer no to this and you are on EC2, clients will be unable to connect to your VPN."
echo "This is needed because EC2 puts your instance behind one-to-one NAT, and using the public IP in the config causes incoming connections to fail with auth failures."
while true; do
  read -p "" yn
  case $yn in
    [Yy]* ) IPADDRESS=$PRIVATEIP; break;;
    [Nn]* ) break;;
    * ) echo "Please answer with Yes or No [y|n].";;
  esac
done

echo "The IP address that will be used in the config is $IPADDRESS"

echo ""
echo "============================================================"
echo ""

echo "Installing necessary dependencies..."

apt-get install libnss3-dev libnspr4-dev pkg-config libpam0g-dev libcap-ng-dev libcap-ng-utils libselinux1-dev libcurl4-nss-dev libgmp3-dev flex bison gcc make libunbound-dev libnss3-tools libevent-dev xmlto -y  > /dev/null

if [ "$?" = "1" ]
then
  echo "An unexpected error occured!"
  exit 0
fi

echo "Installing XL2TPD..."
apt-get install xl2tpd -y > /dev/null

if [ "$?" = "1" ]
then
  echo "An unexpected error occured!"
  exit 0
fi

# Compile and install Libreswan
mkdir -p /opt/src
cd /opt/src
echo "Downloading LibreSwan's source..."
wget -qO- https://download.libreswan.org/libreswan-3.15.tar.gz | tar xvz > /dev/null
cd libreswan-3.15
echo "Compiling LibreSwan..."
make programs > /dev/null
echo "Installing LibreSwan..."
make install > /dev/null

echo "Preparing various configuration files..."

echo "/etc/ipsec.conf"

cat > /etc/ipsec.conf <<EOF
version 2.0
config setup
  dumpdir=/var/run/pluto/
  nat_traversal=yes
  virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:!192.168.42.0/24
  oe=off
  protostack=netkey
  nhelpers=0
  interfaces=%defaultroute
conn vpnpsk
  connaddrfamily=ipv4
  auto=add
  left=$IPADDRESS
  leftid=$IPADDRESS
  leftsubnet=$IPADDRESS/32
  leftnexthop=%defaultroute
  leftprotoport=17/1701
  rightprotoport=17/%any
  right=%any
  rightsubnetwithin=0.0.0.0/0
  forceencaps=yes
  authby=secret
  pfs=no
  type=transport
  auth=esp
  ike=3des-sha1,aes-sha1
  phase2alg=3des-sha1,aes-sha1
  rekey=no
  keyingtries=5
  dpddelay=30
  dpdtimeout=120
  dpdaction=clear
EOF

echo "/etc/ipsec.secrets"

if [ -f /etc/ipsec.secrets ];
then
  cp -f /etc/ipsec.secrets /etc/ipsec.secrets.old
  echo "Backup /etc/ipsec.secrets -> /etc/ipsec.secrets.old"
fi

cat > /etc/ipsec.secrets <<EOF
$IPADDRESS  %any  : PSK "$IPSEC_PSK"
EOF

echo "/etc/xl2tpd/xl2tpd.conf"

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701
;debug avp = yes
;debug network = yes
;debug state = yes
;debug tunnel = yes
[lns default]
ip range = 10.10.10.2-10.10.10.254
local ip = 10.10.10.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
;ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

echo "/etc/ppp/options.xl2tpd"

cat > /etc/ppp/options.xl2tpd <<EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
crtscts
idle 1800
mtu 1280
mru 1280
lock
lcp-echo-failure 10
lcp-echo-interval 60
connect-delay 5000
EOF

echo "/etc/ppp/chap-secrets"

if [ -f /etc/ppp/chap-secrets ];
then
  cp -f /etc/ppp/chap-secrets /etc/ppp/chap-secrets.old
  echo "Backup /etc/ppp/chap-secrets -> /etc/ppp/chap-secrets.old"
fi

cat > /etc/ppp/chap-secrets <<EOF
# Secrets for authentication using CHAP
# client  server  secret  IP addresses
"$VPN_USER" "*" "$VPN_PASSWORD" "*"
EOF

echo "/etc/init.d/ipsec-assist"

cat > /etc/init.d/ipsec-assist <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Service that starts up XL2TPD and IPSEC
# Description:       Service that starts up XL2TPD and IPSEC
### END INIT INFO
# Author: Phil Plückthun <phil@plckthn.me>

# Copyright (C) 2014-2015 Phil Plückthun <phil@plckthn.me>
# Built upon https://help.ubuntu.com/community/L2TPServer

case "$1" in
  start)
    echo "Starting up the goodness of IPSec and XL2TPD"
    iptables --table nat --append POSTROUTING --jump MASQUERADE
    echo 1 > /proc/sys/net/ipv4/ip_forward
    for each in /proc/sys/net/ipv4/conf/*
    do
      echo 0 > $each/accept_redirects
      echo 0 > $each/send_redirects
    done
    /usr/sbin/service ipsec start
    /usr/sbin/service xl2tpd start
    ;;
  stop)
    echo "Stopping IPSec and XL2TPD"
    iptables --table nat --flush
    echo 0 > /proc/sys/net/ipv4/ip_forward
    /usr/sbin/service ipsec stop
    /usr/sbin/service xl2tpd stop
    ;;
  restart)
    echo "Restarting IPSec and XL2TPD"
    iptables --table nat --append POSTROUTING --jump MASQUERADE
    echo 1 > /proc/sys/net/ipv4/ip_forward
    for each in /proc/sys/net/ipv4/conf/*
    do
      echo 0 > $each/accept_redirects
      echo 0 > $each/send_redirects
    done
    /usr/sbin/service ipsec restart
    /usr/sbin/service xl2tpd restart
    ;;
esac

exit 0
EOF

chmod 755 /etc/init.d/ipsec-assist

echo "Applying settings..."

if [ ! -f /etc/ipsec.d/cert8.db ] ; then
  echo > /var/tmp/libreswan-nss-pwd
  /usr/bin/certutil -N -f /var/tmp/libreswan-nss-pwd -d /etc/ipsec.d > /dev/null
  /bin/rm -f /var/tmp/libreswan-nss-pwd
fi

/sbin/sysctl -p > /dev/null

echo "Disabling the IPSec and XL2TP auto start..."

/usr/sbin/service ipsec stop
/usr/sbin/service xl2tpd stop

update-rc.d -f xl2tpd remove
update-rc.d -f ipsec remove

echo "Adding the new auto start..."

update-rc.d ipsec-assist defaults

echo "Starting up the VPN..."

/usr/sbin/service ipsec-assist start

echo "Done."
echo ""

echo "============================================================"
echo "Host: $PUBLICIP (Or a domain pointing to your server)"
echo "IPSec PSK Key: $IPSEC_PSK"
echo "Username: $VPN_USER"
echo "Password: ********"
echo "============================================================"

echo "Your VPN server password is hidden. Would you like to reveal it?"
while true; do
  read -p "" yn
  case $yn in
    [Yy]* ) clear; break;;
    [Nn]* ) exit 0;;
    * ) echo "Please answer with Yes or No [y|n].";;
  esac
done

echo "============================================================"
echo "Host: $PUBLICIP (Or a domain pointing to your server)"
echo "IPSec PSK Key: $IPSEC_PSK"
echo "Username: $VPN_USER"
echo "Password: $VPN_PASSWORD"
echo "============================================================"

echo "Note:"
echo "* Before connecting with a Windows client, please see: http://support.microsoft.com/kb/926179"
echo "* Ports 1701, 500 and 4500 must be opened for the VPN to work!"
echo "* If you plan to keep the VPN server generated with this script on the internet for a long time (a day or more), consider securing it to possible attacks!"

sleep 1
exit 0
