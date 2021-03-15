#!/bin/bash
#
# vpn-stack
# A set of bash scripts for installing and managing a WireGuard VPN server.
# https://git.stack-source.com/msb/vpn-stack
# MIT License Copyright (c) 2021 Matthew Saunders Brown

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
  wg set wg0 peer $peer remove
  wg-quick save wg0
  echo "peer for $client $device disabled"
fi
