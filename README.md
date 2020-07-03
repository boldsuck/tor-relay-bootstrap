tor-relay-bootstrap
===================

This is a script to bootstrap a Debian server to be a set-and-forget Tor relay. I've tested it in Stretch & Buster, but it should work on any modern Debian or Ubuntu version. Pull requests are welcome.

tor-relay-bootstrap does this:

* Configures only recommended but not install suggested packages by default
* Upgrades all the software on the system
* Adds the deb.torproject.org repository to apt, so Tor updates will come directly from the Tor Project
* Installs and configures Tor to be a relay (but still requires you to manually edit torrc to set Nickname, ContactInfo, etc. for this relay)
* Configures sane default firewall rules
* Configures automatic updates
* Installs ntp to ensure time is synced
* Helps harden the ssh server
* Gives instructions on what the sysadmin needs to manually do at the end

To use it, set up a Debian server, SSH into it, switch to the root user ('su -' since Buster!), and:

* Get & use this script:
```sh
apt install -y git
git clone https://github.com/boldsuck/tor-relay-bootstrap.git
cd tor-relay-bootstrap
./bootstrap.sh
```

Recommendation before using this script. The very first time you log in to a new server:

* You should change given provider password! And create a Non-root user.
```sh
passwd
adduser user
```
* If you want to change the hostname:
```sh
hostname host.domain.tld
nano /etc/hostname
nano /etc/hosts
```
