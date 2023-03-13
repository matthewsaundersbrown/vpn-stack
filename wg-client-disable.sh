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
  echo "Disable VPN client config."
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

# check for server config
if [ -f /etc/wireguard/peers/$config ]; then
  peer=$(grep PublicKey /etc/wireguard/peers/$config|cut -d ' ' -f 3)
  wg set wg0 peer $peer remove
  wg-quick save wg0
  echo "peer for $client disabled"
fi
