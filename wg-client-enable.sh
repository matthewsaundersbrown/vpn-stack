#!/bin/bash
#
# vpn-stack
# A set of bash scripts for installing and managing a WireGuard VPN server.
# https://git.stack-source.com/msb/vpn-stack
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# require root
if [ "${EUID}" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# check for and set client name
if [ -n "$1" ]; then
  client=$1
  # set beginning of config file name
  config=$client
else
  echo "client name not set"
  exit 1
fi

# check if device name was set
if [ -n "$2" ]; then
  device=$2
else
  device=default
fi

# add device name & .conf to config file name
config=$config.$device.conf

# check for server config
if [ -f /etc/wireguard/peers/$config ]; then
  peer=$(grep PublicKey /etc/wireguard/peers/$config|cut -d ' ' -f 3)
  status=$(wg |grep -c $peer)
  if [ $status = 0 ]; then
    wg addconf wg0 /etc/wireguard/peers/$config
    wg-quick save wg0
    echo "peer for $client $device enabled"
  elif [ $status = 1 ]; then
    echo "peer for $client $device already enabled"
  else
    echo "unexpected status for peer $client $device ($status)"
  fi
elif [ -f /etc/wireguard/clients/$config ]; then
  # create server config
  # enable server config
  echo "server config for $client $device not found, but client config exists."
  echo "add programming here to create server config and enable"
else
  echo "no configs for $client $device found"
fi
