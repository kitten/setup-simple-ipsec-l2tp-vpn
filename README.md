# Setup a simple IPSec/L2TP VPN server for Ubuntu, Arch Linux and Debian

Tested on:

- Digital Ocean: Ubuntu 14.04 x64 (Trusty)
- Online.net: Arch Linux
- Amazon Web Services EC2: Arch Linux
- Amazon Web Services EC2: Ubuntu 14.04 x64 HVM (Trusty)

## **Deprecated!**

[**This script has been deprecated in favor for my other script "setup-strong-strongswan"**](https://github.com/philpl/setup-strong-strongswan)

This script is very fragmented. The other scripts for Arch Linux, CentOS and Fedora
are not up to date. They are insecure and don't feature a init.d startup and helper
script. Furthermore it uses libreswan, which is not as well maintained and documented as strongswan.

For these and other reasons I updated the strongswan script. It supports both
IPSec over L2TP and "pure" IPSec with the same installation. It is also based on
my work on a strongswan docker container, which will be much more regularly
maintained as well.

[philpl/setup-strong-strongswan](https://github.com/philpl/setup-strong-strongswan)

## Installation

### For Ubuntu and Debian

```
wget https://raw.github.com/philpl/setup-simple-ipsec-l2tp-vpn/master/setup.sh
sudo sh setup.sh
```

> NOTE: Debian 7 (Wheezy) does not have the newer libnss3 version (>=3.15) that Libreswan requires.
> The following workaround is required BEFORE running vpnsetup.sh.
> Thanks to @hwdsl2
>
> ```
> wget https://gist.githubusercontent.com/hwdsl2/5a769b2c4436cdf02a90/raw/e08a04d76240af8acbfe5d6f4e0057c1bf5c660e/vpnsetup-debian-7-workaround.sh
> sudo sh vpnsetup-debian-7-workaround.sh
> ```

This will install a new service called `ipsec-assist`. With it you can safely start, stop and restart the VPN server:

```
sudo service ipsec-assist stop
sudo service ipsec-assist start
sudo service ipsec-assist restart
```

### For Arch Linux

```
wget https://raw.github.com/philpl/setup-simple-ipsec-l2tp-vpn/master/setup_archlinux.sh
sudo sh setup_archlinux.sh
```

### For Fedora

```
wget https://raw.github.com/philpl/setup-simple-ipsec-l2tp-vpn/master/setup_fedora.sh
sudo sh setup_fedora.sh
```

The script will lead you through the installation process.

During installation you have to enter an IPSec PSK Key, a custom username if you wish, and a password.

Ports `1701`, `500` and `4500` must be opened for the VPN to work!

Enjoy your very own (secure) VPN!

## Some Notes

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

## License

Copyright notices and license notes are at the head of the script.
