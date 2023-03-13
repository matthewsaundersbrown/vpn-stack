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

# load include file
source $(dirname $0)/wg.sh

# prints a table with username & device split in to columns
(echo "Client" && echo "---------------" && cd /etc/wireguard/clients/ && ls -1 *.conf)|sed 's|\.conf$||g'
