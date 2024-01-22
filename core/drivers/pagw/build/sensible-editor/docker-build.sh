#!/bin/bash

/usr/bin/cgroupfs-mount

/usr/bin/containerd &

sleep 5

# Do not set iptables NAT rules as this tends to fail
/usr/bin/dockerd --iptables=false -H unix:// --containerd=/run/containerd/containerd.sock &

sleep 5

docker version

df -h /

lsblk

# The `--network host` avoids the need for the sometimes problematic ip_tables kernel module 
docker build --network host -t sensible-editor -f /root/sensible-editor/Dockerfile.sensible-editor /root/sensible-editor
