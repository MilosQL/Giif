#!/bin/bash

#############################################################
#
# Successfully tested against Proxmox VE versions: 6.4
#
#############################################################
#
# Environment variables used by this script:
#
# PAGW_HOST - Proxmox VE IP address
# PAGW_HOST_USER - typically root
# PAGW_HOST_HOME - typically /root
#
# PROJECT_NAME - used as a name of the PAGW instance
#
# PAGW_HOST_MGMT_BRIDGE - Unified project-management and BMS plane bridge
# PAGW_MGMT_VLAN - VLAN tag assigned to the project for the bridge above 
#
# PAGW_HOST_PUB_BRIDGE - public-plane bridge
# PAGW_PUB_VLAN - empty/unset or a VLAN tag used for the bridge above
#
# PAGW_STORAGE_POOL - targeted storage volume
#  
#############################################################

[[ ! -z "$PAGW_PUB_VLAN" ]] && PUB_TAG=",tag=${PAGW_PUB_VLAN}"

ssh -o "StrictHostKeyChecking=no" -i ssh_privkey ${PAGW_HOST_USER}@${PAGW_HOST} "

NEXTID=\$(pvesh get /cluster/nextid)
qm create \${NEXTID} --name PAGW-${PROJECT_NAME} \
                     --onboot 1 \
                     --ostype l26 \
                     --cdrom none \
                     --scsihw virtio-scsi-pci \
                     --bootdisk scsi0 \
                     --sockets 1 --cores 2 \
                     --memory 2048  \
                     --net0 model=virtio,bridge=${PAGW_HOST_MGMT_BRIDGE},tag=${PAGW_MGMT_VLAN} \
                     --net1 model=virtio,bridge=${PAGW_HOST_PUB_BRIDGE}${PUB_TAG} \
                     --agent enabled=1

qm importdisk \${NEXTID} ${PAGW_HOST_HOME}/${PROJECT_NAME}.img ${PAGW_STORAGE_POOL}
qm set \${NEXTID} --scsi0 ${PAGW_STORAGE_POOL}:vm-\${NEXTID}-disk-0
qm set \${NEXTID} --boot legacy=c
qm start \${NEXTID}

rm ${PAGW_HOST_HOME}/${PROJECT_NAME}.img
"
