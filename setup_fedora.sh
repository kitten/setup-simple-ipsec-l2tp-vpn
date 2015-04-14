#!/bin/sh
#    Setup Simple IPSec/L2TP VPN server for Fedora Linux
#
#    Dennis Anfossi <danfossi@itfor.it> Copyright (C) 2015 
#	    Porting of work of Phil Plückthun <phil@plckthn.me> on Fedora
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

if [ ! -f /etc/fedora-release ]
then
  echo "This script was designed to run on Fedora Linux!"
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
  IPSEC_PSK="$P1$P2$P3"
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

echo "Making sure that yum is updated.."

yum check-update > /dev/null

echo "Checking for wget and net-tools"

if (yum info wget >/dev/null) ; then
	echo "Wget is installed"
else
	yum install wget -y > /dev/null
fi

if (yum info net-tools >/dev/null) ; then
        echo "net-tools are installed"
else
        yum install net-tools -y > /dev/null
fi

PUBLICIP=`wget -q -O - http://wtfismyip.com/text`
if [ "x$PUBLICIP" = "x" ]
then
  echo "Your server's external IP address could not be detected!"
  echo "Please enter the IP yourself:"
  read -p "" PUBLICIP
else
  echo "Detected your server's external IP address: $PUBLICIP"
fi

PRIVATEIP=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
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

yum groupinstall "Development tools" -y 

if [ "$?" = "1" ]
then
  echo "An unexpected error occured!"
  exit 0
fi

yum install unbound nss libcap-ng curl bison flex xmlto -y

if [ "$?" = "1" ]
then
  echo "An unexpected error occured!"
  exit 0
fi

echo "Installing XL2TPD..."
yum install xl2tpd -y > /dev/null

if [ "$?" = "1" ]
then
  echo "An unexpected error occured!"
  exit 0
fi

# Dopwnloa and install Libreswan
echo "Installing LibreSwan.."
if (yum libreswan wget >/dev/null) ; then
        echo "Libreswan is installed"
else
        yum install libreswan -y
fi

if [ "$?" = "1" ]
then
  echo "An unexpected error occured!"
  exit 0
fi

echo "Preparing various configuration files..."

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

cat > /etc/ipsec.secrets <<EOF
$IPADDRESS  %any  : PSK "$IPSEC_PSK"
EOF

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701
;debug avp = yes
;debug network = yes
;debug state = yes
;debug tunnel = yes
[lns default]
ip range = 192.168.42.10-192.168.42.250
local ip = 192.168.42.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
;ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

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

cat > /etc/ppp/chap-secrets <<EOF
# Secrets for authentication using CHAP
# client  server  secret  IP addresses
$VPN_USER  l2tpd  $VPN_PASSWORD  *
EOF

cat > /usr/lib/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local compatibility

[Service]
Type=oneshot
ExecStart=/etc/rc.local
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

#Enabling systemd support to rc.local

cat > /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
/usr/sbin/iptables --table nat --append POSTROUTING --jump MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward
for each in /proc/sys/net/ipv4/conf/*
do
  echo 0 > $each/accept_redirects
  echo 0 > $each/send_redirects
done
/usr/bin/systemctl restart ipsec.service
/usr/bin/systemctl restart xl2tpd.service
EOF

#Enable execution flag
chmod a+x /etc/rc.local

#Enabling rc.local service
/usr/bin/systemctl enable rc-local.service

#Make sure that iptables is installed
if (yum info iptables >/dev/null) ; then
	echo "iptables is installed"
else
	yum install iptables -y > /dev/null
 fi

echo "Applying changes..."

/usr/sbin/iptables --table nat --append POSTROUTING --jump MASQUERADE > /dev/null
echo 1 > /proc/sys/net/ipv4/ip_forward
for each in /proc/sys/net/ipv4/conf/*
do
  echo 0 > $each/accept_redirects
  echo 0 > $each/send_redirects
done

if [ ! -f /etc/ipsec.d/cert8.db ] ; then
   echo > /var/tmp/libreswan-nss-pwd
   /usr/bin/certutil -N -f /var/tmp/libreswan-nss-pwd -d /etc/ipsec.d > /dev/null
   /bin/rm -f /var/tmp/libreswan-nss-pwd
fi

/usr/bin/sysctl --system > /dev/null 2>&1

echo "Starting IPSec and XL2TP services..."

/usr/bin/systemctl enable ipsec.service
/usr/bin/systemctl enable xl2tpd.service

/usr/bin/systemctl restart ipsec.service
/usr/bin/systemctl restart xl2tpd.service

echo "Success!"
echo " "

clear

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
echo ""
echo "Note:"
echo "* Before connect with windows client see: http://support.microsoft.com/kb/926179"
echo "* Ports 1701, 500 and 4500 must be opened for the VPN to work!"
echo "* If you plan to keep the VPN server generated with this script on the internet for a long time (a day or more), consider securing it to possible attacks!"

sleep 1
exit 0
