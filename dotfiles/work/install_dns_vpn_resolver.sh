#!/bin/bash

set -e
set -x

trap 'exit' INT

source ~/myconfig/scripts/common_funcs.sh

# Check - https://github.com/jonathanio/update-systemd-resolved

# 1) Download and install script for intagration openvpn with systemd-resolved:
cd /tmp/
rm -rf /tmp/update-systemd-resolved
gclonecd https://github.com/jonathanio/update-systemd-resolved.git
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
# up /usr/local/libexec/openvpn/update-systemd-resolved
# up-restart
# down /usr/local/libexec/openvpn/update-systemd-resolved
# down-pre


# Check dns cmd:
# resolvectl status
