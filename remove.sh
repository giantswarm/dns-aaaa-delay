#!/bin/sh -ex

DNSMASQ_PORT=53
NET_OVERLAY_IF="tunl0"

tc qdisc del dev $NET_OVERLAY_IF root
iptables -D POSTROUTING -t mangle -p udp --dport $DNSMASQ_PORT -m string -m u32 --u32 "28 & 0xF8 = 0" --hex-string "|00001C0001|" --algo bm --from 40 -j MARK --set-mark 0x100/0x100
