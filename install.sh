#!/bin/bash
#
# vpn-stack
# A set of bash scripts for installing and managing a WireGuard VPN server.
# https://git.stack-source.com/msb/vpn-stack
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#
# wireguard installer for Ubuntu 20.04
#
# this installer expects a clean Ubuntu 20.04 install with
# wireguard, stubby & dnsmasq *not* previously installed

# require root
if [ "${EUID}" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# do some basic pre-install checks - these are *not* exhaustive
os_id=`lsb_release -is`
os_release=`lsb_release -rs`
if [ $os_id != Ubuntu ] || [ $os_release != 22.04 ]; then
  echo "this installer only runs on Ubuntu 22.04, bailing out"
  exit 1
fi

if [ -d /etc/wiregaurd ]; then
  echo "looks like wireguard is already installed, bailing out"
  exit 1
fi

if [ -d /etc/stubby/ ]; then
  echo "looks like stubby is already installed, bailing out"
  exit 1
fi

if [ -d /etc/dnsmasq.d ]; then
  echo "looks like dnsmasq is already installed, bailing out"
  exit 1
fi

# check for / set hostname

# assumes a single IP on a /24 subnet is provisioned on the server
# you can change this to fit your network, or just set to a specific IP
# used by wireguard for vpn connections & stubby for DNS queries
IPv4=`ip -4 -o addr show | awk '{ print $4 }' | grep '/24$' | cut -d / -f 1`

# update system
apt -y update
# update grub first, by itself, as it requires special overrides to run unattended
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install grub-common grub2-common grub-pc grub-pc-bin
DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
DEBIAN_FRONTEND=noninteractive apt-get -y autoremove

# set system variables
echo "# for wireguard vpn" > /etc/sysctl.d/60-wireguard.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/60-wireguard.conf
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.d/60-wireguard.conf
echo "# for dnsmasq (dns)" >> /etc/sysctl.d/60-wireguard.conf
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.d/60-wireguard.conf
echo "net.ipv6.ip_nonlocal_bind = 1" >> /etc/sysctl.d/60-wireguard.conf
/sbin/sysctl --system

# DNS over TLS (DoT) for OS
sed -i 's|#DNS=|DNS=1.1.1.1|g' /etc/systemd/resolved.conf
sed -i 's|#FallbackDNS=|FallbackDNS=1.0.0.1|g' /etc/systemd/resolved.conf
sed -i "s|#Domains=|Domains=`hostname -d`|g" /etc/systemd/resolved.conf
sed -i 's|#DNSOverTLS=no|DNSOverTLS=yes|g' /etc/systemd/resolved.conf
sed -i 's|#Cache=.*|Cache=no|g' /etc/systemd/resolved.conf
systemctl restart systemd-resolved

# configure a minimal smtp server so automated emails (cron etc) can be sent
DEBIAN_FRONTEND=noninteractive apt-get -y install exim4-daemon-light mailutils
sed -i "s|dc_eximconfig_configtype='local'|dc_eximconfig_configtype='internet'|g" /etc/exim4/update-exim4.conf.conf
/usr/sbin/update-exim4.conf
systemctl restart exim4

# configure automatic updates
DEBIAN_FRONTEND=noninteractive apt-get -y install unattended-upgrades
sed -i 's|APT::Periodic::Download-Upgradeable-Packages "0";|APT::Periodic::Download-Upgradeable-Packages "1";|g' /etc/apt/apt.conf.d/10periodic
sed -i 's|APT::Periodic::AutocleanInterval "0";|APT::Periodic::AutocleanInterval "7";|g' /etc/apt/apt.conf.d/10periodic
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/10periodic
sed -i 's|//     "${distro_id}:${distro_codename}-updates";|       "${distro_id}:${distro_codename}-updates";|g' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i 's|//Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|g' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i 's|//Unattended-Upgrade::Remove-Unused-Dependencies "false";|Unattended-Upgrade::Remove-Unused-Dependencies "true";|g' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i 's|//Unattended-Upgrade::Automatic-Reboot "false";|Unattended-Upgrade::Automatic-Reboot "true";|g' /etc/apt/apt.conf.d/50unattended-upgrades
# between 8:00 and 9:59am UTC, change to suit your needs
REBOOT_TIME=$(printf "%02d" $((8 + RANDOM % 2))):$(printf "%02d" $((0 + RANDOM % 60)))
sed -i "s|//Unattended-Upgrade::Automatic-Reboot-Time \"02:00\";|Unattended-Upgrade::Automatic-Reboot-Time \"$REBOOT_TIME\";|g" /etc/apt/apt.conf.d/50unattended-upgrades

# stubby DNS Privacy stub resolver for wireguard clients
DEBIAN_FRONTEND=noninteractive apt-get -y install stubby
cp /etc/stubby/stubby.yml /etc/stubby/stubby.yml.default
echo 'resolution_type: GETDNS_RESOLUTION_STUB' > /etc/stubby/stubby.yml
echo 'dns_transport_list:' >> /etc/stubby/stubby.yml
echo '  - GETDNS_TRANSPORT_TLS' >> /etc/stubby/stubby.yml
echo 'tls_authentication: GETDNS_AUTHENTICATION_REQUIRED' >> /etc/stubby/stubby.yml
echo 'tls_query_padding_blocksize: 128' >> /etc/stubby/stubby.yml
echo 'edns_client_subnet_private : 1' >> /etc/stubby/stubby.yml
echo 'round_robin_upstreams: 1' >> /etc/stubby/stubby.yml
echo 'idle_timeout: 10000' >> /etc/stubby/stubby.yml
echo 'listen_addresses:' >> /etc/stubby/stubby.yml
echo '  - 127.0.0.1' >> /etc/stubby/stubby.yml
echo '  - 0::1' >> /etc/stubby/stubby.yml
echo "  - $IPv4" >> /etc/stubby/stubby.yml
echo 'upstream_recursive_servers:' >> /etc/stubby/stubby.yml
echo '  - address_data: 1.1.1.1' >> /etc/stubby/stubby.yml
echo '    tls_auth_name: "one.one.one.one"' >> /etc/stubby/stubby.yml
echo '  - address_data: 1.0.0.1' >> /etc/stubby/stubby.yml
echo '    tls_auth_name: "one.one.one.one"' >> /etc/stubby/stubby.yml
echo '  - address_data: 2606:4700:4700::1111' >> /etc/stubby/stubby.yml
echo '    tls_auth_name: "one.one.one.one"' >> /etc/stubby/stubby.yml
echo '  - address_data: 2606:4700:4700::1001' >> /etc/stubby/stubby.yml
echo '    tls_auth_name: "one.one.one.one"' >> /etc/stubby/stubby.yml
systemctl restart stubby.service

# download adware + malware hosts file, used by dnsmasq
wget --output-document=/usr/local/etc/hosts https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

# dnsmasq will use adware + malware hosts file
# and listen on wireguard server private lan IP
# can be used by clients for adblocking

# create temporary policy-rc.d to stop dnsmasq from starting during install
# otherwise dnsmasq will fail to start due to ports in use and will show
# errors. not really a problem as later config resoves this, but the errors
# may cause concern for users running the install
install -m 755 /dev/null /usr/sbin/policy-rc.d
echo '#!/bin/sh' > /usr/sbin/policy-rc.d
echo 'exit 101' >> /usr/sbin/policy-rc.d
DEBIAN_FRONTEND=noninteractive apt-get -y install dnsmasq
echo "domain-needed" > /etc/dnsmasq.d/local.conf
echo "bogus-priv" >> /etc/dnsmasq.d/local.conf
echo "no-resolv" >> /etc/dnsmasq.d/local.conf
echo "no-poll" >> /etc/dnsmasq.d/local.conf
echo "server=127.0.0.1" >> /etc/dnsmasq.d/local.conf
echo "addn-hosts=/usr/local/etc/hosts" >> /etc/dnsmasq.d/local.conf
# cache is disabled for extra privacy, but this impacts performance
# enable cache for increased performance, at the expense of privacy
echo "cache-size=0" >> /etc/dnsmasq.d/local.conf
echo "no-negcache" >> /etc/dnsmasq.d/local.conf
echo "listen-address=10.96.0.1" >> /etc/dnsmasq.d/local.conf
echo "no-dhcp-interface=10.96.0.1" >> /etc/dnsmasq.d/local.conf
echo "bind-interfaces" >> /etc/dnsmasq.d/local.conf
# remove temporary policy-rc.d
rm -f /usr/sbin/policy-rc.d
systemctl restart dnsmasq.service

# install and configure ufw firewall
DEBIAN_FRONTEND=noninteractive apt-get -y install ufw
# enable wireguard port
ufw allow from any to $IPv4 port 51820 proto udp
# allow dns queries for wireguard clients
ufw allow from 10.96.0.0/12 to any port 53 proto udp
ufw allow from 10.96.0.0/12 to any port 53 proto tcp
# enable ssh for remote server management
# consider restricting this to specific IP(s) if you can
ufw allow 22/tcp
# nat/fowaring/masquerade rules for wireguard
# taken from https://www.linuxbabe.com/ubuntu/wireguard-vpn-server-ubuntu
# get line number of last ufw-before-forward entry in ufw before.rules config file
BRLINE=`grep -n 'ufw-before-forward' /etc/ufw/before.rules |tail -1|cut -f1 -d':'`
# insert/append after before.rules line number and increment
sed -i "$BRLINE""a # allow forwarding for trusted network, for wireguard" /etc/ufw/before.rules
BRLINE=$((BRLINE+1))
sed -i "$BRLINE""a -A ufw-before-forward -s 10.96.0.0/12 -j ACCEPT" /etc/ufw/before.rules
BRLINE=$((BRLINE+1))
sed -i "$BRLINE""a -A ufw-before-forward -d 10.96.0.0/12 -j ACCEPT" /etc/ufw/before.rules
# append to the end of before.rules
echo >> /etc/ufw/before.rules
echo "# NAT table rules" >> /etc/ufw/before.rules
echo "*nat" >> /etc/ufw/before.rules
echo ":POSTROUTING ACCEPT [0:0]" >> /etc/ufw/before.rules
echo "-A POSTROUTING -o eth0 -j MASQUERADE" >> /etc/ufw/before.rules
echo >> /etc/ufw/before.rules
echo "# End each table with the 'COMMIT' line or these rules won't be processed" >> /etc/ufw/before.rules
echo "COMMIT" >> /etc/ufw/before.rules

ufw --force enable

# install & configure wireguard
DEBIAN_FRONTEND=noninteractive apt-get -y install net-tools wireguard wireguard-tools qrencode

# this will be the private network used by wireguard server & clients
# Network:   10.96.0.0/12
# Address:   10.96.0.1
# Netmask:   255.240.0.0 = 12
# Wildcard:  0.15.255.255
# Broadcast: 10.111.255.255
# HostMin:   10.96.0.1
# HostMax:   10.111.255.254
# Hosts/Net: 1048574               (Private Internet)

# set temp umask for creating wiregaurd configs
UMASK=`umask`
umask 0077
# create keys
wg genkey > /etc/wireguard/.privatekey
cat /etc/wireguard/.privatekey | wg pubkey > /etc/wireguard/.publickey
# Generate wg0.conf
echo "[Interface]" >> /etc/wireguard/wg0.conf
echo "Address = 10.96.0.1/12" >> /etc/wireguard/wg0.conf
echo "ListenPort = 51820" >> /etc/wireguard/wg0.conf
echo "PrivateKey = "$(cat /etc/wireguard/.privatekey) >> /etc/wireguard/wg0.conf
echo "SaveConfig = true" >> /etc/wireguard/wg0.conf
echo >> /etc/wireguard/wg0.conf
# make backup copy of initial wg0.conf. can be used to reset server config
# and optionally re-enable peers if anything gets fubared
cp /etc/wireguard/wg0.conf /etc/wireguard/.wg0.conf
# make sure perms are correct. redundant, umask should have taken care of this
chmod 600 /etc/wireguard/*
chmod 600 /etc/wireguard/.wg0.conf

# create dirs for client & peer configs
install --owner=root --group=root --mode=700 --directory /etc/wireguard/clients
install --owner=root --group=root --mode=700 --directory /etc/wireguard/peers

# revert umask setting
umask $UMASK

systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service

# set up wireguard timer for wg-cron.sh
# removes inactive peers (clients) endpoint (last connected IP) data from wireguard
# /usr/lib/systemd/system/wg-cron.timer
echo '[Unit]' > /usr/lib/systemd/system/wg-cron.timer
echo 'Description=wiregaurd cron every 5 minutes' >> /usr/lib/systemd/system/wg-cron.timer
echo '' >> /usr/lib/systemd/system/wg-cron.timer
echo '[Timer]' >> /usr/lib/systemd/system/wg-cron.timer
echo 'OnCalendar=*:0/5' >> /usr/lib/systemd/system/wg-cron.timer
echo 'Unit=wg-cron.service' >> /usr/lib/systemd/system/wg-cron.timer
echo '' >> /usr/lib/systemd/system/wg-cron.timer
echo '[Install]' >> /usr/lib/systemd/system/wg-cron.timer
echo 'WantedBy=multi-user.target' >> /usr/lib/systemd/system/wg-cron.timer
# /usr/lib/systemd/system/wg-cron.service
echo '[Unit]' > /usr/lib/systemd/system/wg-cron.service
echo 'Description=wireguard cron' >> /usr/lib/systemd/system/wg-cron.service
echo '' >> /usr/lib/systemd/system/wg-cron.service
echo '[Service]' >> /usr/lib/systemd/system/wg-cron.service
echo 'Type=simple' >> /usr/lib/systemd/system/wg-cron.service
echo 'ExecStart=/usr/local/sbin/wg-cron.sh' >> /usr/lib/systemd/system/wg-cron.service
echo '' >> /usr/lib/systemd/system/wg-cron.service
echo '[Install]' >> /usr/lib/systemd/system/wg-cron.service
echo 'WantedBy=multi-user.target' >> /usr/lib/systemd/system/wg-cron.service
# enable wg-cront.timer
systemctl daemon-reload
systemctl enable wg-cron.timer
systemctl start wg-cron.timer

# install wg-*.sh scripts in to /usr/local/sbin/
cp wg-*.sh /usr/local/sbin/
chmod 755 /usr/local/sbin/wg-*.sh

# display installation confirmation message
echo "WireGuard is now installed and configured and running."
echo "You can begin adding clients with the wg-client-add.sh script."

# display instructions for enabling email notifications
echo ""
echo "To route system emails and to enable unattended upgrade notifications"
echo "run these two commands, replacing user@example.com with your email address."
echo ""
echo "echo \"root: user@example.com\" >> /etc/aliases"
echo "sed -i 's|//Unattended-Upgrade::Mail \"\";|Unattended-Upgrade::Mail \"user@example.com\";|g' /etc/apt/apt.conf.d/50unattended-upgrades"
