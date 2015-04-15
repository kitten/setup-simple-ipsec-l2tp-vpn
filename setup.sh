#!/bin/sh
#
#    Copyright (C) 2015 Dennis Anfossi <danfossi@itfor.it>
#
#    This work is licensed under the Creative Commons Attribution-ShareAlike 3.0
#    Unported License: http://creativecommons.org/licenses/by-sa/3.0/
#
#

#clean screen
clear

if [ `id -u` -ne 0 ]
then
  echo "Please start this script with root privileges!"
  echo "Try again with sudo."
  exit 1
fi

echo ""
echo "This script allows the installation of a simple IPSec/L2TP VPN server for Ubuntu, Debian, Fedora, CentOS and Arch Linux."
echo ""
echo "Identifying current system.."
echo ""

#check release
if   [ -f /etc/ubuntu-release ]; then
	echo "Downloading correct setup file.."
        wget -q https://raw.github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/master/setup_debian.sh
	echo ""
        echo "Running setup.."
	echo ""
        sh ./setup_debian.sh
	exit 0

elif [ -f /etc/debian_version ]; then
	echo "Downloading correct setup file.."
        wget -q https://raw.github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/master/setup_debian.sh
	echo ""
        echo "Running setup.."
	echo ""
        sh ./setup_debian.sh
	exit 0

elif [ -f /etc/centos-release ]; then
	echo "Downloading correct setup file.."
	wget -q https://raw.github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/master/setup_centos.sh
	echo ""
        echo "Running setup.."
	echo ""
        sh ./setup_centos.sh
	exit 0

elif [ -f /etc/arch-release ]; then
	echo "Downloading correct setup file.."
	wget -q https://raw.github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/master/setup_archlinux.sh
	echo ""
        echo "Running setup.."
	echo ""
        sh ./setup_archlinux.sh
	exit 0

elif [ -f /etc/fedora-release ]; then
	echo "Downloading correct setup file.."
	wget -q https://raw.github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/master/setup_centos.sh
	echo ""
	echo "Running setup.."
	echo ""
	sh ./setup_centos.sh
	exit 0
else
	echo "Unable to identify current system; You need to download the setup manually from:"
	echo "https://github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/"
	echo ""
	exit 1
fi
