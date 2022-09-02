#!/bin/bash

set -e

trap 'exit' INT

# Check - https://github.com/jonathanio/update-systemd-resolved

# 1) Download and install script for intagration openvpn with systemd-resolved:
git clone https://github.com/jonathanio/update-systemd-resolved.git
cd update-systemd-resolved
sudo make


# 2) Enable systemd-resolved:
systemctl enable systemd-resolved.service
systemctl start systemd-resolved.service


# 3) Install stub resolver:
sudo mv /etc/resolv.conf /etc/resolv.conf.old
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf


# 4) Add command in .ovpn or '--config /usr/bin/update-systemd-resolved.conf':
# script-security 2
# setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# up /usr/bin/update-systemd-resolved
# up-restart
# down /usr/bin/update-systemd-resolved
# down-pre


# Check dns cmd:
# resolvectl status
