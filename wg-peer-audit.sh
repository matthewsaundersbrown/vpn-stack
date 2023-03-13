#!/bin/bash
#
# vpn-stack
# A set of bash scripts for installing and managing a WireGuard VPN server.
# https://git.stack-source.com/msb/vpn-stack
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#
# wg-peer-audit.sh
# check that peer config file exists for all currently active peers
# this is basis of a "cleanup" script to remove configs for invalid
# old or deleted clients

# load include file
source $(dirname $0)/wg.sh

# get all peers in running wireguard server
peers=($(wg|grep peer|cut -d ' ' -f 2))

# get number of peers found above
peersCount=${#peers[@]}

# if any peers found cycle through them
if [ $peersCount -gt  0 ]; then

  for (( i=0; i<${peersCount}; i++ ));
  do
    grep -q ${peers[$i]} /etc/wireguard/peers/*.conf
    match=$?
    if [[ $match != 0 ]]; then
      echo "did not find peer config for: ${peers[$i]}"
      echo "consider removing peer now"
      #wg set wg0 peer ${peers[$i]} remove
      #wg-quick save wg0
    fi
  done

fi
