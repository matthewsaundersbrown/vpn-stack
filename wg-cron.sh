#!/bin/bash
#
# vpn-stack
# A set of bash scripts for installing and managing a WireGuard VPN server.
# https://git.stack-source.com/msb/vpn-stack
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#
# wg-cron.sh
# check for peers (clients) with connections older that two minutes
# remove them then add them back to wireguard
# this removes the endpoint (last connected IP) and transfer stats

# require root
if [ "${EUID}" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# get peer of clients with "minutes" in their last handshake
clients=($(wg|grep -B 4 minutes|grep peer|cut -d ' ' -f 2))

# get number of peers found above
clientCount=${#clients[@]}

# if any peers found cycle through them
if [ $clientCount -gt  0 ]; then

  for (( i=0; i<${clientCount}; i++ ));
  do
    # remove peer from wireguard
    wg set wg0 peer ${clients[$i]} remove
    config=$(grep ${clients[$i]} /etc/wireguard/peers/*.conf|cut -d : -f 1)
    # add peer back to wireguard
    wg addconf wg0 $config
  done

  # save to config so that changes survive wireguard restart
  wg-quick save wg0

fi
