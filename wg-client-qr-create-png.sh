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
  echo "Create PNG QR file for client config."
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

# set config and image file names
config=$client.conf
image=$config.png

# check for existing config
if [ -f /etc/wireguard/clients/$config ]; then

  if [ ! -d /var/lib/wireguard ]; then
    install --owner=root --group=root --mode=700 --directory /var/lib/wireguard
  fi
  qrencode -t png -r /etc/wireguard/clients/$config -o /var/lib/wireguard/$image

else
  echo "config for $client does not exist"
fi
