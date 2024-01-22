FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get -y install samba perl wget patch vim incron sshpass && \
    cp /etc/samba/smb.conf /etc/samba/smb.conf.original

# Each driver (idrac, proxmox,...) gets a home;
# check the entrypoint.sh script for more details.
VOLUME /home/

# Proxmox VE enforces its own directory structure.
# For this reason the volume below has two mount
# points under the main docker-compose (hard links
# do not work with directories while mkdir() used
# by Proxmox VE attachment script does not accept
# pre-exsiting soft links).  
VOLUME /home/iso

COPY smb.conf /etc/samba/smb.conf

COPY entrypoint.sh .

EXPOSE 137/udp 138/udp 139/tcp 445/tcp

ENTRYPOINT ["./entrypoint.sh"]
