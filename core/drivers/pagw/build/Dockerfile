FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

ARG CLOUD_IMAGE_URL=https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

WORKDIR /root

ARG QCOW2_SIZE=10G

RUN echo 'nameserver 8.8.8.8' > /etc/resolv.conf \
    && apt-get update \
    && apt-get install -y libguestfs-tools linux-image-generic \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && curl ${CLOUD_IMAGE_URL} -o downloaded.img \
    && virt-filesystems --long -h --all -a downloaded.img \
    && virt-filesystems --long -h --all -a downloaded.img \
    && qemu-img create -f qcow2 pagw.img ${QCOW2_SIZE} \
    && virt-resize --expand /dev/sda1 downloaded.img pagw.img \
    && rm downloaded.img \
    && virt-customize -a pagw.img \
    --install \
openssh-server,\
ifupdown,\
fail2ban,\
isc-dhcp-server,\
openvswitch-switch,\
arp-scan,\
pptpd,\
wireguard,\
iptables-persistent,\
tcpdump,\
git,\
vim,\
ncdu,\
traceroute,\
qemu-guest-agent \
    --delete '/var/cache/apt/archives/*.deb' \
    --update \
    --delete '/var/cache/apt/archives/*.deb' \
# Note: Nmap and other had to be isolated and installed separately in order to avoid disk space problems
    && virt-customize -a pagw.img  --install nmap --delete '/var/cache/apt/archives/*.deb' \
    && virt-customize -a pagw.img  --install docker-compose --delete '/var/cache/apt/archives/*.deb'

# Operator's account 
ARG SUDO_USER
ENV SUDO_USER=${SUDO_USER:-pagw}

# ARP-scan account
ARG ARPSCAN_USER
ENV ARPSCAN_USER=${ARPSCAN_USER:-arpscan}
 
# PPTP management account for Guacamole SSH connection
ARG PPTP_USER
ENV PPTP_USER=${PPTP_USER:-pptp}

# Wireguard management account for Guacamole SSH connection
ARG WG_USER
ENV WG_USER=${WG_USER:-wireguard}

# Primary and fallback DNS
ARG DNS1
ENV DNS1=${DNS1:-8.8.8.8}
ARG DNS2
ENV DNS2=${DNS2:-1.1.1.1}

COPY sensible-editor/ ./sensible-editor
RUN echo 'nameserver 8.8.8.8' > /etc/resolv.conf \
    && virt-customize -a pagw.img \
                      --run-command 'grub-install /dev/sda' \
                      --install cgroupfs-mount \
                      --delete '/var/cache/apt/archives/*.deb' \
                      --copy-in sensible-editor/:/root/ \
                      --run '/root/sensible-editor/docker-build.sh'

COPY pagw-customizer.sh .

ENTRYPOINT ./pagw-customizer.sh
