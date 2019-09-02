#!/bin/bash

ttl=65

if [[ -n "$1" ]]; then
    sh -c "echo $1 > /proc/sys/net/ipv4/ip_default_ttl "
    exit
fi

sh -c "echo $ttl > /proc/sys/net/ipv4/ip_default_ttl "
# sudo iptables -t mangle -A POSTROUTING -j TTL --ttl-set 130

