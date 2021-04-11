#!/bin/bash

# check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# only install recommended but not suggested packages by default
echo "== Configuring no suggested packages"
cp $PWD/etc/apt/apt.conf.d/06norecommends /etc/apt/apt.conf.d/06norecommends

# update software
echo "== Updating software"
apt-get update
apt-get dist-upgrade -y

# install required software
apt-get install -y lsb-release gpg wget

# add official Tor repository
if ! grep -q "https://deb.torproject.org/torproject.org" /etc/apt/sources.list; then
    echo "== Adding the official Tor repository"
    echo "deb https://deb.torproject.org/torproject.org `lsb_release -cs` main" >> /etc/apt/sources.list
    wget -O - https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | apt-key add -
    apt-get update
fi

# install tor and related packages
echo "== Installing Tor and related packages"
apt-get install -y deb.torproject.org-keyring tor nyx tor-geoipdb
service tor stop

# configure tor
cp $PWD/etc/tor/torrc /etc/tor/torrc

# configure firewall rules
echo "== Configuring firewall rules"
apt-get install -y debconf-utils
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
apt-get install -y iptables iptables-persistent
cp $PWD/etc/iptables/rules.v4 /etc/iptables/rules.v4
cp $PWD/etc/iptables/rules.v6 /etc/iptables/rules.v6
chmod 600 /etc/iptables/rules.v4
chmod 600 /etc/iptables/rules.v6
/sbin/iptables-restore < /etc/iptables/rules.v4
/sbin/ip6tables-restore < /etc/iptables/rules.v6

apt-get install -y fail2ban

# configure automatic updates
echo "== Configuring unattended upgrades"
apt-get install -y unattended-upgrades apt-listchanges
# To disable|enable unattended upgrades run 'dpkg-reconfigure -plow unattended-upgrades'
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades
service unattended-upgrades restart

# apparmor is installed by default since Debian Buster
apt-get install -y apparmor apparmor-profiles apparmor-utils
if ! grep -q '^[^#].*apparmor=1' /etc/default/grub; then
sed -i.bak 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 apparmor=1 security=apparmor"/' /etc/default/grub
update-grub
fi

# install ntp & possibly missing software (some fail2ban action need curl)
apt-get install -y ntp unbound sudo curl htop man

# install monit
# Since Debian Buster monit is only in backports and systemd is standard now. With the setting 'Restart=on-failure'
# systemd will autorecovery a daemon if it stops running by a code exception or 'kill -9 <pid>'.

# configure sshd
ORIG_USER=$(logname)
if [ -n "$ORIG_USER" ]; then
	echo "== Configuring sshd"
	# only allow the current user to SSH in
	echo "AllowUsers $ORIG_USER" >> /etc/ssh/sshd_config
	echo "  - SSH login restricted to user: $ORIG_USER"
	if grep -q "Accepted publickey for $ORIG_USER" /var/log/auth.log; then
		# user has logged in with SSH keys so we can disable password authentication
		sed -i '/^#\?PasswordAuthentication/c\PasswordAuthentication no' /etc/ssh/sshd_config
		echo "  - SSH password authentication disabled"
		# adding the current user to sudo group and disable SSH login for the root user
		usermod -aG sudo $ORIG_USER
		sed -i '/^#\?PermitRootLogin/c\PermitRootLogin no' /etc/ssh/sshd_config
		echo "  - Root login disabled (use su/sudo now)"

		if [ $ORIG_USER == "root" ]; then
			# user logged in as root directly (rather than using su/sudo) so make sure root login is enabled
			sed -i '/^#\?PermitRootLogin/c\PermitRootLogin yes' /etc/ssh/sshd_config
		fi
	else
		# user logged in with a password rather than keys
		echo "  - You do not appear to be using SSH key authentication.  You should set this up manually now."
	fi
	service ssh reload
else
	echo "== Could not configure sshd automatically.  You will need to do this manually."
fi

# final instructions
# OnionTip.com & TorTip.com has been down for a long time :-(
echo ""
echo "== Try SSHing into this server again in a new window, to confirm the firewall isn't broken"
echo ""
echo "== Edit /etc/tor/torrc"
echo "  - Set Address, Nickname, Contact Info, and MyFamily for your Tor relay"
echo "  - Optional: If your host supports IPv6, please enable it."
echo "  - Optional: include a Monero (OpenAlias) donation address in the 'ContactInfo' line"
echo "    - Learn more about Monero & Bitcoin OpenAlias address:"
echo "      https://web.getmonero.org/de/resources/moneropedia/address.html"
echo "  - Optional: limit the amount of data transferred by your Tor relay (to avoid additional hosting costs)"
echo "    - Uncomment the lines beginning with '#AccountingMax' and '#AccountingStart'"
echo ""
echo "== Consider having /etc/apt/sources.list update over HTTPS and/or HTTPS+Tor"
echo "   see https://guardianproject.info/2014/10/16/reducing-metadata-leakage-from-software-updates/"
echo "   for more details"
echo ""
echo "== REBOOT THIS SERVER"
