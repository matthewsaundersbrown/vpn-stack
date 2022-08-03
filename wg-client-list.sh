#!/bin/bash
#
# vpn-stack
# A set of bash scripts for installing and managing a WireGuard VPN server.
# https://git.stack-source.com/msb/vpn-stack
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#
# wg-client-list.sh
# list all client configs available on the server

# require root
if [ "${EUID}" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# prints a table with username & device split in to columns
(echo "Client.Config" && echo "--------.------" && cd /etc/wireguard/clients/ && ls -1 *.conf)|sed 's|\.conf$||g'|sed 's|\.| |g'|column -t
