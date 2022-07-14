# vpn-stack

A set of bash scripts for installing and managing a WireGuard VPN server.

## Download & Install

Start with basic Ubuntu 20.04 install with no extra services or packages installed.

```bash
cd /usr/local/src/
wget https://git.stack-source.com/stackaas/stack-vpn/archive/master.tar.gz
tar zxvf master.tar.gz
cd stack-vpn
chmod 750 wg-*.sh
mv wg-*.sh /usr/local/sbin/
/usr/local/sbin/wg-install.sh
```

## Configure Clients

Download and install client software from [wireguard.com](https://www.wireguard.com/install/).

Add a client configuration to the server and display a qr code that can be scanned by a client.

```bash
wg-client-add.sh username [device]
wg-client-qr-display.sh username [device]
```

If the device option is left off then a "default" device will be added for that client/username.
For example, to add a client config for a user named joe and display the qr code on the console screen run:

```bash
wg-client-add.sh joe
wg-client-qr-display.sh joe
```

## Todo

Complete documentation that describes in detail the configuration of the WireGuard server coming next. In the meantime review the comments in wg-install.sh to see details.

## License
Copyright (c) 2022 Matthew Saunders Brown <matthewsaundersbrown@gmail.com>
GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
