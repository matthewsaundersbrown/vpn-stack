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

# check for existing config
if [ -f /etc/wireguard/clients/$config ]; then
  qrencode -t ansiutf8 < /etc/wireguard/clients/$config
else
  echo "config for $client $device does not exist"
fi
