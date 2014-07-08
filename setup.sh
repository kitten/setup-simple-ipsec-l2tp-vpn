#!/bin/sh
#    Setup Simple IPSec/L2TP VPN server for Ubuntu and Debian
#
#    Copyright (C) 2014 Phil Plückthun <phil@plckthn.me>
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
  read -p "Please enter your preferred password: " VPN_PASSWORD
  if [ "x$VPN_USER" = "x" ]
  then
    echo "Please enter a valid password!"
  else
    break
  fi
done

echo ""

PUBLICIP=`wget -q -O - http://ipecho.net/plain`
if [ "x$PUBLICIP" = "x" ]
then
  echo "Your server's external IP address could not get detected!"
  echo "Please enter the IP yourself:"
  read -p "" PUBLICIP
else
  echo "Detected your server's external IP address: $PUBLICIP"
fi

echo ""
echo "============================================================"
echo ""

echo "Installing necessary dependencies..."

apt-get update > /dev/null
apt-get install libnss3-dev libnspr4-dev pkg-config libpam0g-dev libcap-ng-dev libcap-ng-utils libselinux1-dev libcurl4-nss-dev libgmp3-dev flex bison gcc make libunbound-dev libnss3-tools wget -y  > /dev/null

if [ "$?" = "0" ]
then
  echo "An unexpected error occured!"
  exit 0
fi

echo "Installing XL2TPD..."
apt-get install xl2tpd -y > /dev/null

if [ "$?" = "0" ]
then
  echo "An unexpected error occured!"
  exit 0
fi

# Compile and install Libreswan
mkdir -p /opt/src
cd /opt/src
echo "Downloading LibreSwan's source..."
wget -qO- https://download.libreswan.org/libreswan-3.8.tar.gz | tar xvz > /dev/null
cd libreswan-3.8
echo "Compiling LibreSwan..."
make programs
echo "Installing LibreSwan..."
make install

if [ "$?" = "0" ]
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
  left=$PUBLICIP
  leftid=$PUBLICIP
  leftsubnet=$PUBLICIP/32
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
$PUBLICIP  %any  : PSK "$IPSEC_PSK"
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

/bin/cp -f /etc/sysctl.conf /etc/sysctl.conf.old
cat > /etc/sysctl.conf <<EOF
kernel.sysrq = 0
kernel.core_uses_pid = 1
net.ipv4.tcp_syncookies = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
kernel.randomize_va_space = 1
net.core.wmem_max=12582912
net.core.rmem_max=12582912
net.ipv4.tcp_rmem= 10240 87380 12582912
net.ipv4.tcp_wmem= 10240 87380 12582912
EOF

/bin/cp -f /etc/iptables.rules /etc/iptables.rules.old
cat > /etc/iptables.rules <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:ICMPALL - [0:0]
:ZREJ - [0:0]
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p icmp --icmp-type 255 -j ICMPALL
-A INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p udp -m multiport --dports 500,4500 -j ACCEPT
-A INPUT -p udp --dport 1701 -m policy --dir in --pol ipsec -j ACCEPT
-A INPUT -p udp --dport 1701 -j DROP
-A INPUT -j ZREJ
-A FORWARD -i eth+ -o ppp+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i ppp+ -o eth+ -j ACCEPT
-A FORWARD -j ZREJ
-A ICMPALL -p icmp --fragment -j DROP
-A ICMPALL -p icmp --icmp-type 0 -j ACCEPT
-A ICMPALL -p icmp --icmp-type 3 -j ACCEPT
-A ICMPALL -p icmp --icmp-type 4 -j ACCEPT
-A ICMPALL -p icmp --icmp-type 8 -j ACCEPT
-A ICMPALL -p icmp --icmp-type 11 -j ACCEPT
-A ICMPALL -p icmp -j DROP
-A ZREJ -p tcp -j REJECT --reject-with tcp-reset
-A ZREJ -p udp -j REJECT --reject-with icmp-port-unreachable
-A ZREJ -j REJECT --reject-with icmp-proto-unreachable
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 192.168.42.0/24 -o eth+ -j SNAT --to-source $PUBLICIP
COMMIT
EOF

cat > /etc/network/if-pre-up.d/iptablesload <<EOF
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.rules
exit 0
EOF

/bin/cp -f /etc/rc.local /etc/rc.local.old
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
/usr/sbin/service ipsec restart
/usr/sbin/service xl2tpd restart
echo 1 > /proc/sys/net/ipv4/ip_forward
exit 0
EOF

echo "Applying changes..."

if [ ! -f /etc/ipsec.d/cert8.db ] ; then
   echo > /var/tmp/libreswan-nss-pwd
   /usr/bin/certutil -N -f /var/tmp/libreswan-nss-pwd -d /etc/ipsec.d
   /bin/rm -f /var/tmp/libreswan-nss-pwd
fi

/sbin/sysctl -p
/bin/chmod +x /etc/network/if-pre-up.d/iptablesload
/sbin/iptables-restore < /etc/iptables.rules

echo "Starting IPSec and XL2TP services..."

/usr/sbin/service ipsec restart
/usr/sbin/service xl2tpd restart

echo "Success!"
echo ""

echo "============================================================"
echo "Host: $PUBLICIP (Or a domain pointing to your server)"
echo "IPSec PSK Key: $IPSEC_PSK"
echo "Username: $VPN_USER"
echo "Password: $VPN_PASSWORD"
echo "============================================================"

sleep 2
exit 0
