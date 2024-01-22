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
#
# PROJECT_NAME - used as a name of the PAGW instance 
#
#############################################################

# Note: Many things can go sideways when releasing the PAGW
# instance in Proxmox VE. For instance, the VM may be in a locked
# state due to ongoing backup process. It's up to the operator
# confirm everything was cleared from the PAGW-host before
# database entries are removed. 

ssh -o "StrictHostKeyChecking=no" -i ssh_privkey ${PAGW_HOST_USER}@${PAGW_HOST} "

VMID=\`qm list | awk '/ PAGW-${PROJECT_NAME} /{print \$1;}'\`
qm stop \${VMID}
qm destroy \${VMID} --destroy-unreferenced-disks --purge
"

# Developer's note: The regular expression used for ${VMID} assignment
# must provide an exact match; otherwise there is a risk of fetching
# multiple IDs of the VMs with similar names (e.g. "PAGW-xyz" and "PAGW-xyzxyz"). 
