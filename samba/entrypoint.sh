#!/bin/bash

# ISO share

useradd -m -s /bin/bash iso 2>/dev/null
echo -e "${SAMBA_PASSWORD}\n${SAMBA_PASSWORD}" | passwd iso
(echo ${SAMBA_PASSWORD}; echo ${SAMBA_PASSWORD}) | smbpasswd -s -a iso

# We're employing incrontab(5) and scp(1) to notify
# the Core about subsequent changes in the ISO repository. 

ISO_FETCH_SCRIPT='/usr/local/bin/fetch-iso-list.sh'
cat << 'EOF' > ${ISO_FETCH_SCRIPT}
#/bin/bash

cd /home/iso/

list=`find $PWD -maxdepth 1 -name '*.iso' ! -name '.*' -type f -printf "%f\n"`

echo "$list" > iso_list

sshpass -p ${CORE_PASSWORD} scp -o stricthostkeychecking=no iso_list ${CORE_USER}@core:

EOF
chmod ug+x ${ISO_FETCH_SCRIPT}
echo "/home/iso/ IN_CREATE,IN_DELETE  ${ISO_FETCH_SCRIPT}" > /etc/incron.d/home_iso
incrond
${ISO_FETCH_SCRIPT}

# Admin instructions for ISO image naming and exposing

cat << 'EOF' > /home/iso/README

- Spaces are not allowed in the names of the images.

- ".iso" extension is mandatory.

- Hidden files are not exposed to end-users.

- Soft-links are not exposed to end-users.

EOF

# Each other driver gets an account 

## iDRAC
useradd -m -s /bin/bash idrac 2>/dev/null
mkdir -p /home/idrac/xml/
chown idrac:idrac /home/idrac/xml/
echo -e "${SAMBA_PASSWORD}\n${SAMBA_PASSWORD}" | passwd idrac
(echo ${SAMBA_PASSWORD}; echo ${SAMBA_PASSWORD}) | smbpasswd -s -a idrac

## Proxmox VE
useradd -m -s /bin/bash proxmox 2>/dev/null
### The /home/iso and /home/proxmox/template/iso directories
### share the same Docker volume. Please check the samba/Dockerfile
### for more detailed explanation on why this was necessary.
mkdir -p /home/proxmox/template/iso
chown -R proxmox:proxmox /home/proxmox/template/
echo -e "${SAMBA_PASSWORD}\n${SAMBA_PASSWORD}" | passwd proxmox
(echo ${SAMBA_PASSWORD}; echo ${SAMBA_PASSWORD}) | smbpasswd -s -a proxmox

smbd --foreground --debug-stdout --no-process-group
