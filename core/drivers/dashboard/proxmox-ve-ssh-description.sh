source proxmox-ve-ssh-arguments.sh

clear

echo -e '\n\n\n--------------------------------------------------------------------------'

output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm config ${VM_ID} | grep -E '^description:' | cut -d':' -f2 "`

urlencode -d ${output}

echo -e '--------------------------------------------------------------------------\n\n'

read -n 1 -s -p "Press any key to continue..."    clear

clear
