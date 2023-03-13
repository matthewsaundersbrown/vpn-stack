#!/bin/bash
#
# vpn-stack
# A set of bash scripts for installing and managing a WireGuard VPN server.
# https://git.stack-source.com/msb/vpn-stack
# Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# any script that includes this conf file will force user to be root
if [ "$USER" != "root" ]; then
  exec sudo -u root $0 $@
fi

# constants

# functions

# crude but good enough domain name format validation
function wg::validate_domain () {
  local my_domain=$1
  if [[ $my_domain =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}$ ]] ; then
    return 0
  else
    return 1
  fi
}

function wg::getoptions () {
  local OPTIND
  while getopts "c:e:h" opt ; do
    case "${opt}" in
        h ) # display help and exit
          help
          exit
          ;;
        c ) # client/config name
          client=${OPTARG,,}
          ;;
        e ) # email address
          email=${OPTARG,,}
          if [[ $email =~ "@" ]] ; then
            mbox=${email%@*}
            domain=${email##*@}
            if [ -z $mbox ] ; then
              echo "ERROR: No local part in $email."
              exit 1
            elif [ -z $domain ] ; then
              echo "ERROR: No domain in $email."
              exit 1
            elif ! wg::validate_domain $domain; then
              echo "ERROR: $domain is not a valid domain name."
              exit 1
            fi
          else
            echo "ERROR: $email is not a valid email."
            exit 1
          fi
          ;;
        \? )
          echo "Invalid option: $OPTARG"
          exit 1
          ;;
        : )
          echo "Invalid option: $OPTARG requires an argument"
          exit 1
        ;;
    esac
  done
  shift $((OPTIND-1))
}

