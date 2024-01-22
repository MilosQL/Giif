#!/bin/bash

# This script is executed in the context of the main enrolment routine!

touch ssh_privkey
chmod 600 ssh_privkey
echo "$PAGW_SSH_PRIVKEY" > ssh_privkey

ssh -o "StrictHostKeyChecking=no" -i ssh_privkey ${PAGW_HOST_USER}@${PAGW_HOST} "

PAGW_ID=\`qm list | fgrep ' 'PAGW-${PROJECT_NAME}' ' | xargs | cut -d' ' -f1\`

NIC_SET=\`qm config \$PAGW_ID | grep -E '^net' | cut -d' ' -f1\`

# Note: Proxmox VE supports up to 30 NICs per single VM
for i in {0..31} 
do
   if ! (echo \$NIC_SET  | fgrep -q -w 'net'\$i':')
   then
      NIC_ID=\$i
      break 
   fi   
done

qm set \${PAGW_ID} --net\${NIC_ID} 'virtio,bridge=${PAGW_HOST_MGMT_BRIDGE},tag=${VLAN}'
"
