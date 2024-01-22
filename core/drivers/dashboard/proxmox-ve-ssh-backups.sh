#!/bin/bash

# Developer's note: The "at" command is used to prevent 
# Guacamole users from issuing SIGINT (Ctrl-C) and other signals
# which in turn disrupt the "qm" operations and can lead to VM locking!

function create
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "vzdump ${VM_ID}"

  read -n 1 -s -p "
The backup operation seem to have ended. Press any key to continue..."
  clear
}

function delete
{
  clear ; echo ''

  storage_id=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "grep -E '^storage:' /etc/vzdump.conf | cut -d':' -f2"`

  vzdump_volumes=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "pvesm list --content backup --vmid ${VM_ID} ${storage_id} | fgrep vzdump-qemu | cut -d' ' -f1 "`

  vzdump_prefix=`echo "$vzdump_volumes" | cut -d'/' -f1 | uniq`
  vzdump_list=`echo "$vzdump_volumes" | cut -d'/' -f2` 

  if [ -z "$vzdump_list" ]
  then
    echo
    read -n 1 -s -p "The VM has no backups. Press any key to continue..."
    return
  fi

  echo -e "\n************** Backup selection ********************\n" 

  oldIFS=$IFS
  IFS=$'\n'
  choices=( $vzdump_list )
  count=${#choices[@]}
  IFS=$oldIFS
  PS3=$'\n'"Invalid selection will retrun you to the main menu. Your choice: "
  select answer in "${choices[@]}"; do
    if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "$count" ]
    then
      vzdump_name=${answer}
      break
    else
      echo	    
      read -n 1 -s -p "The value \"$REPLY\" is not a valid choice. Returning to main menu......"
      return 
    fi
  done

  local sure=0
  while ((!sure))
  do
    clear ; echo ''
    echo -e "WARNING: Potentially destructive operation!"
    echo -e "\nAre you sure you want to proceed with the removal of '${vzdump_name}'?\n"
    select yn in "Yes" "No"
    do
      case $yn in
        Yes ) sure=1 ; break ;;
        No  ) clear ; echo '' ; exit ;;
        *   ) echo ; read -n 1 -s -p "The value \"$REPLY\" is not a valid choice. Press any key to try again..." ; break ;;
       esac
    done
  done

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "pvesm free ${vzdump_prefix}'/'${vzdump_name}"

  read -n 1 -s -p "
The backup operation seem to have ended. Press any key to continue..."
  clear
}

function printHelp
{
        clear
        echo -e "

Help/About 
                                
The on-demand backup driver for the VMs hosted on 
the Proxmox VE platform. Please note that backup restoration
and periodically scheduled backups are not part of this driver.

If you notice anything missing or not functioning as expected, 
please contact your support team. 

                " | fold -w 80 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

################################# BACKUP MANAGEMENT ##############################################

source proxmox-ve-ssh-arguments.sh

(
# This script requires exclusive locking
flock -x -n 9 || { 

        echo -e "\nThe server is performing another critical operation... Please try later.\n" ;
        echo -e "If the problem persists, contact your support.\n" ;
        read -n 1 -s -p "Press any key to continue..."
        clear

        exit 1  
}

PS3=$'\n'"Your choice: "

all_done=0
while (( !all_done ))
do
  clear
  echo -e "\n************** On-demand backup management ********************\n"
  select item in "Exit this script" "Create" "Delete" "Help/About" ;
  do
    case "$REPLY" in
      1 ) echo ; all_done=1 ; break ;;
      2 ) create ; break ;;
      3 ) delete ; break ;;
      4 ) printHelp ; break ;;
      * ) echo ; read -n 1 -s -p "The value \"$REPLY\" is not a valid choice. Press any key to try again..." ; break ;;
    esac
  done
done

) 9>/var/lock/${FLOCK}.lock
