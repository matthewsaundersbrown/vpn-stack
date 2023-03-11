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

function vhost::set-virtualhostArray () {

  cd /srv/www
  virtualhostArray=(`ls -1|grep -v ^html$`)

}

function vhost::set-phpVersion () {

  PHP_MAJOR_VERSION=`php -r "echo PHP_MAJOR_VERSION;"`
  PHP_MINOR_VERSION=`php -r "echo PHP_MINOR_VERSION;"`
  phpVersion=$PHP_MAJOR_VERSION.$PHP_MINOR_VERSION

}

# crude but good enough domain name format validation
function wg::validate_domain () {
  local my_domain=$1
  if [[ $my_domain =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}$ ]] ; then
    return 0
  else
    return 1
  fi
}

-c client
-g config
-e email
-p peer ???

function wg:getoptions () {
  local OPTIND
  while getopts "cd:i:m:o:p:u:jhnvw" opt ; do
    case "${opt}" in
        h ) # display help and exit
          help
          exit
          ;;
        c ) # cvs - output in cvs format
          cvs=true
          ;;
        d ) # domain name (virtualhost) to act on
          domain=${OPTARG,,}
          if ! wg::validate_domain $domain; then
            echo "ERROR: $domain is not a valid domain name."
            exit
          fi
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
        i ) # User ID (UID) for new user
          uid=${OPTARG}
          ;;
        m ) # macro - Apache mod_macro name
          macro=${OPTARG}
          ;;
        o ) # option - usually applied to previously specified variable
            # e.g. could be subdomain or alias depending on the macro defined
          option=${OPTARG}
          ;;
        p ) # password
          password=${OPTARG}
          ;;
        u ) # username
          username=${OPTARG,,}
          ;;
        j ) # jail - if enabled user will be jailed
          jail=true
          ;;
        n ) # dry-run
          dryrun=true
          ;;
        v ) # verbose
          verbose=true
          ;;
        w ) # write - store data in file
          write=true
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

# check for local config, which can be used to override any of the above
if [[ -f /usr/local/etc/wg.conf ]]; then
  source /usr/local/etc/wg.conf
fi
