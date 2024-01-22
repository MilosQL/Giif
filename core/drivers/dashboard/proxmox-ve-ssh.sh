#!/bin/bash

function description
{
 proxmox-ve-ssh-description.sh -h ${HOST}':'${PORT} -u ${USERNAME} -p ${PASSWORD} -m ${VM_ID} 
}

function power_actions
{
 proxmox-ve-ssh-power-actions.sh -h ${HOST}':'${PORT} -u ${USERNAME} -p ${PASSWORD} -m ${VM_ID} 
}

function optical_drive
{
 proxmox-ve-ssh-optical-drive.sh -h ${HOST}':'${PORT} -u ${USERNAME} -p ${PASSWORD} -m ${VM_ID} 
}

function snapshots
{
 # Normally, users shouldn't be allowed to perform this operation:	
 #	
 # proxmox-ve-ssh-napshots.sh -h ${HOST}:${PORT} -u ${USERNAME} -p ${PASSWORD} -m ${VM_ID}
 #
 # so instead, we're giving them a stub message:

        clear
        
        echo -e "
                                 
This operation is resource demanding and for that
reason not directly exposed to end-users.

Please consult your support team for more information.

                " | fold -w 80 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

function backups
{
 # Normally, users shouldn't be allowed to perform this operation:	
 #	
 # proxmox-ve-ssh-backups.sh -h ${HOST}:${PORT} -u ${USERNAME} -p ${PASSWORD} -m ${VM_ID}
 #
 # so instead, we're giving them a stub message:

        clear
        
        echo -e "
                                 
This operation is resource demanding and for that 
reason not directly exposed to end-users.

Please consult your support team for more information.

                " | fold -w 80 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

function printHelp
{
        clear
        echo -e "

Help/About 
                                
This interactive script acts as a top-level dashboard
for the VMs running on Proxmox VE. 

If you notice anything missing or not functioning as expected, 
please contact your support team.



                " | fold -w 80 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

################################# MAIN ##############################################

source proxmox-ve-ssh-arguments.sh

PS3=$'\n'"Your choice: "

clear
all_done=0
while (( !all_done ))
do
        echo -e "\n************** Main menu ********************\n"
        select item in "Exit this script" "Description" "Power actions" "Virtual CD/DVD" "Snapshots" "Backups" "Help/About" ;
        do
                case "$REPLY" in
                        1 ) echo ; all_done=1 ; break ;;
                        2 ) description ; break ;;
                        3 ) power_actions ; break ;;
                        4 ) optical_drive ; break ;;
                        5 ) snapshots ; break ;;
                        6 ) backups ; break ;;
                        7 ) printHelp ; break ;;
                        * ) echo "The value \"$REPLY\" is not a valid choice. Please try again." ;;
                esac
        done
done
