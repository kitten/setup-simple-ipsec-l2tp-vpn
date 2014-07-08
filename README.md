# Setup a simple IPSec/L2TP VPN server for Ubuntu and Debian

> NOTE: As far as I know, IPSec/L2TP is considered to be one of the most secure protocols!
> Still I cannot guarantee 100% security!

> https://www.ivpn.net/pptp-vs-l2tp-vs-openvpn

Script has been tested on:

- Digital Ocean: Ubuntu 14.04 x64 (Trusty)

**Feel free to test it on more distributions and please report back to me!**

Copyright (C) 2014 Phil Plückthun <phil@plckthn.me><br>
[Based on the work of Lin Song](https://gist.github.com/hwdsl2/9030462) (Copyright 2014)<br>
[Based on the work of Viljo Viitanen](https://github.com/viljoviitanen/setup-simple-pptp-vpn) (Setup Simple PPTP VPN server for Ubuntu and Debian)
Based on the work of Thomas Sarlandie (Copyright 2012)

# Installation

```
wget https://raw.github.com/philplckthun/setup-simple-ipsec-l2tp-vpn/master/setup.sh
sudo sh setup.sh
```

The script will lead you through the installation process.

During installation you have to enter an IPSec PSK Key, a custom username if you wish, and a password.

Enjoy your very own (secure) VPN!

Some Notes
==========

Clients are configured to use Google's Public DNS servers, when
the VPN connection is active:
https://developers.google.com/speed/public-dns/

Only one VPN account is generated!
To add more accounts, see the file `/etc/ppp/chap-secrets`

*In the future I might add the ability to generate more accounts.*

If you keep the VPN server generated with this script on the internet for a
long time (days or more), consider securing it to possible attacks!
