#!/bin/bash
#
# vpn-stack
# A set of bash scripts for installing and managing a WireGuard VPN server.
# https://git.stack-source.com/msb/vpn-stack
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# load include file
source $(dirname $0)/wg.sh

help()
{
  thisfilename=$(basename -- "$0")
  echo "Add VPN client config."
  echo ""
  echo "usage: $thisfilename -c <client> [-h]"
  echo ""
  echo "  -h            Print this help."
  echo "  -c <client>   Name of the client configuration."
}

wg::getoptions "$@"

# check for client config name
if [[ -z $client ]]; then
  echo "client name is required"
  exit
fi

# set config file name
config=$client.conf

# check for existing config
if [ -f /etc/wireguard/clients/$config ] || [ -f /etc/wireguard/peers/$config ]; then
  echo "config for $client already exists"
  exit 1
fi

# set Endpoint to FQDN of this server
endpoint=`hostname -f`

# alternatively set Endpoint to primary IPv4 of this server
# assumes a single IP on a /24 subnet is provisioned on the server
# you can change this to fit your network, or just set to a specific IP
# this is the IP that clients use to establish vpn connection
# endpoint=`ip -4 -o addr show | awk '{ print $4 }' | grep '/24$' | cut -d / -f 1`

# get next available IP
# note that tests show this code is quick with a few hundred to low thousands of assigned client IPs
# but can take serveral minutes when assigned client IPs gets in to the 10s or 100s of thousands

# get array of assigned IPs - no longer used, memory usage too high when larger number of IPs assigned
# addresses=($(grep Address /etc/wireguard/clients/*.conf | cut -d ' ' -f 3 | cut -d "/" -f 1))

# address unassigned
address=0

# Network:   10.96.0.0/12
# HostMin:   10.96.0.1
# HostMax:   10.111.255.254

# 06 - 111
secondoctet=96
while [ $secondoctet -lt 112 ] && [ $address = 0 ]; do

  # 0 - 255
  thirdoctet=0
  while [ $thirdoctet -lt 256 ] && [ $address = 0 ]; do

    fourthoctet=1
    while [ $fourthoctet -lt 256 ] && [ $address = 0 ]; do

      testaddress=10.$secondoctet.$thirdoctet.$fourthoctet

      # skip reserved addresses
      if [ $testaddress = "10.96.0.1" ]; then
        fourthoctet=$[$fourthoctet+1]
      elif [ $testaddress = "10.111.255.255" ]; then
        echo "all available addresses used, can not add more clients"
        exit 1
      elif `grep -qr "$testaddress/" /etc/wireguard/clients/`; then
        fourthoctet=$[$fourthoctet+1]
      else
        address=$testaddress
      fi

    done

      thirdoctet=$[$thirdoctet+1]

  done

    secondoctet=$[$secondoctet+1]

done

# set temp umask for creating wiregaurd configs
UMASK=`umask`
umask 0077

# make sure clients config dir exists
if [[ ! -d /etc/wireguard/clients ]]; then
  install --owner=root --group=root --mode=700 --directory /etc/wireguard/clients
fi

# make sure peers config dir exists
if [[ ! -d /etc/wireguard/peers ]]; then
  install --owner=root --group=root --mode=700 --directory /etc/wireguard/peers
fi

key=$(wg genkey)
psk=$(wg genpsk)
publickey_server=$(cat /etc/wireguard/.publickey)
publickey_client=$(wg pubkey <<< $key)

# create server config for client (peer)
cat << EOF >> /etc/wireguard/peers/"$config"
[Peer]
PublicKey = $publickey_client
PresharedKey = $psk
AllowedIPs = $address/32
EOF

# enable client on server
wg addconf wg0 /etc/wireguard/peers/"$config"
# save newly added client to server config
wg-quick save wg0

# create config for client
cat << EOF > /etc/wireguard/clients/"$config"
[Interface]
Address = $address/32
DNS = 10.96.0.1
PrivateKey = $key

[Peer]
PublicKey = $publickey_server
PresharedKey = $psk
AllowedIPs = 0.0.0.0/0
Endpoint = $endpoint:51820
PersistentKeepalive = 25
EOF

# revert umask setting
umask $UMASK
