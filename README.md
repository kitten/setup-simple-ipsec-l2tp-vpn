# Setup a simple IPSec/L2TP VPN server for Ubuntu, Arch Linux and Debian

> NOTE: As far as I know, IPSec/L2TP is considered to be one of the most secure protocols!
> Still I cannot guarantee 100% security!

> https://www.ivpn.net/pptp-vs-l2tp-vs-openvpn

Script has been tested on:

- Digital Ocean: Ubuntu 14.04 x64 (Trusty)
- Online.net: Arch Linux
- Amazon Web Services EC2: Arch Linux
- Amazon Web Services EC2: Ubuntu 14.04 x64 HVM (Trusty)

**Feel free to test it on more distributions and please report back to me!**

Copyright (C) 2014-2015 Phil Plückthun <phil@plckthn.me><br>
Hotfixes - Edwin Ang <edwin@theroyalstudent.com><br>
Adapting script for Arch Linux - Dennis Anfossi <danfossi@itfor.it>

[Based on the work of Lin Song](https://gist.github.com/hwdsl2/9030462) (Copyright 2014)<br>
[Based on the work of Viljo Viitanen](https://github.com/viljoviitanen/setup-simple-pptp-vpn) (Setup Simple PPTP VPN server for Ubuntu and Debian)
Based on the work of Thomas Sarlandie (Copyright 2012)

# Installation

## For Ubuntu and Debian

```
wget https://raw.github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/master/setup.sh
sudo sh setup.sh
```

This will install a new service called `ipsec-assist`. With it you can safely start, stop and restart the VPN server:

```
sudo service ipsec-assist stop
sudo service ipsec-assist start
sudo service ipsec-assist restart
```

## For Arch Linux

```
wget https://raw.github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/master/setup_archlinux.sh
sudo sh setup_archlinux.sh
```

## For Fedora

```
wget https://raw.github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/master/setup_fedora.sh
sudo sh setup_fedora.sh
```

The script will lead you through the installation process.

During installation you have to enter an IPSec PSK Key, a custom username if you wish, and a password.

Ports `1701`, `500` and `4500` must be opened for the VPN to work!

Enjoy your very own (secure) VPN!

# Warning!

> June 1st, 2015: CVE-2015-3204: malicious payload causing IKE daemon restart

**If you've used the script before the 14th of June, please update LibreSwan on the server!**

# Some Notes

Clients are configured to use Google's Public DNS servers, when
the VPN connection is active:
https://developers.google.com/speed/public-dns/

Only one VPN account is generated!
To add more accounts, see the file `/etc/ppp/chap-secrets`

*In the future I might add the ability to generate more accounts.*

Before connecting with a Windows client please see: [http://support.microsoft.com/kb/926179](http://support.microsoft.com/kb/926179)

If you plan to keep the VPN server generated with this script on the internet for a
long time (a day or more), consider securing it to possible attacks!

If you run this script on EC2, the IP used in the config files will be different to the instance's public-facing IP. This is because Amazon performs one-to-one NAT on EC2 instances.
