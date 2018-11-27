#!/bin/sh -ex
# Initial implementation is here: https://github.com/Quentin-M/weave-tc

DELAY="4ms"
DNSMASQ_PORT=53
# Calico with IPIP creates tunl0.
NET_OVERLAY_IF="tunl0"

# Traffic leaving the $NET_OVERLAY_IF interface onto the default interface will be IPIP
# encapsulated therefore, we may only do traffic shaping work on this interface.
#
# The $NET_OVERLAY_IF interface is a virtual interface, which is set to noqueue by default and does
# not support mq nor multiq. Therefore, we go directly to the point and create a a 2-bands
# priomap, that sends all traffic (regardless of the TOS octet) to the 2nd band, a simple 
# fq_codel. We then define the 1st band as a netem with the a small delay, that appears to 
# be avoid the race in a statistically satisfying manner, and that is controlled by a pareto
# distribution (k=4ms, a=1ms) and route traffic marked by 0x100/0x100 to it.
#
# Using iptables, we mark 0x100/0x100 the UDP traffic destined to port $DNSMASQ_PORT, that have
# the DNS query bits set (fast check) and then that contain at least one question with QTYPE=AAAA.
while ! ip link | grep "$NET_OVERLAY_IF" > /dev/null; do sleep 1; done

tc qdisc del dev $NET_OVERLAY_IF root 2>/dev/null || true
tc qdisc add dev $NET_OVERLAY_IF root handle 1: prio bands 2 priomap 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1

tc qdisc add dev $NET_OVERLAY_IF parent 1:2 handle 12: fq_codel

tc qdisc add dev $NET_OVERLAY_IF parent 1:1 handle 11: netem delay $DELAY 1ms distribution pareto
tc filter add dev $NET_OVERLAY_IF protocol all parent 1: prio 1 handle 0x100/0x100 fw flowid 1:1
iptables -A POSTROUTING -t mangle -p udp --dport $DNSMASQ_PORT -m string -m u32 --u32 "28 & 0xF8 = 0" --hex-string "|00001C0001|" --algo bm --from 40 -j MARK --set-mark 0x100/0x100

while sleep 3600; do :; done
