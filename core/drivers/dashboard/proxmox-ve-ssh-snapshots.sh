#!/bin/bash

# Developer's note: The "at" command is used to prevent 
# Guacamole users from issuing SIGINT (Ctrl-C) and other signals
# which in turn disrupt the "qm" operations and can lead to VM locking!

# Developer's note: Taking user's input and 
# expanding it in a command-string is extremely risky! 
function create
{
  clear ; echo ''

  snap_name=Snap-`date -u +'%Y-%m-%d-%Hh-%Mmin-%Ssec'`

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "/bin/echo qm snapshot ${VM_ID} ${snap_name} | at -M now + 1 minute"

  read -n 1 -s -p "

The snapshot '$snap_name' is being created. Press any key to continue..."
  clear
}


# Note: Snapshots not created by this framework
# (i.e. that do not follow the "Snap-*" naming 
# convention) will remain hidden to ordinary users!  
function select_snap
{
  snap_name=''

  clear

  snapshot_list=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'qm listsnapshot '${VM_ID}' | awk '"'"'/Snap-/ {print $2}'"'"`

  if [ -z "$snapshot_list" ]
  then
    echo
    read -n 1 -s -p "The VM has no snapshots. Press any key to continue..."
    return
  fi

  echo -e "\n************** Snapshot selection ********************\n" 

  oldIFS=$IFS
  IFS=$'\n'
  choices=( $snapshot_list )
  count=${#choices[@]}
  IFS=$oldIFS
  PS3=$'\n'"Invalid selection will retrun you to the main menu. Your choice: "
  select answer in "${choices[@]}"; do
    if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "$count" ]
    then
      snap_name=${answer}
      break
    else
      echo	    
      read -n 1 -s -p "The value \"$REPLY\" is not a valid choice. Returning to main menu......"
      return 
    fi
  done
}

function confirm_selection
{
  operation=$1

  local sure=0
  while ((!sure))
  do
    clear ; echo ''
    echo -e "WARNING: Potentially destructive operation!"
    echo -e "\nAre you sure you want to proceed with the ${operation} of '${snap_name}'?\n"
    select yn in "Yes" "No"
    do
      case $yn in
        Yes ) sure=1 ; break ;;
        No  ) clear ; echo '' ; exit ;;
        *   ) echo ; read -n 1 -s -p "The value \"$REPLY\" is not a valid choice. Press any key to try again..." ; break ;;
       esac
    done
  done
}

function rollback
{
  select_snap
  if [ -z "$snap_name" ]
  then
    clear
    return
  fi

  confirm_selection "rollback"

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "/bin/echo qm rollback ${VM_ID} ${snap_name} | at -M now + 1 minute"

  read -n 1 -s -p "

The snapshot '$snap_name' is being restored. The VM will remain in OFF state.

Press any key to continue..."
  clear
}

function delete
{
  select_snap
  if [ -z "$snap_name" ]
  then
    clear
    return
  fi

  confirm_selection "removal"

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "/bin/echo qm delsnapshot ${VM_ID} ${snap_name} | at -M now + 1 minute"

  read -n 1 -s -p "

The snapshot '$snap_name' is being deleted.

Press any key to continue..."
  clear
}

function printHelp
{
        clear
        echo -e "

Help/About 
                                
Top-level menu for the snapshot management of the VMs 
hosted on the Proxmox VE platform. 

If you notice anything missing or not functioning as expected, 
please contact your support team.

                " | fold -w 80 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

################################# SNAPSHOT MANAGEMENT ##############################################

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
  echo -e "\n************** Snapshot management ********************\n"
  select item in "Exit this script" "Create" "Rollback" "Delete" "Help/About" ;
  do
    case "$REPLY" in
      1 ) echo ; all_done=1 ; break ;;
      2 ) create ; break ;;
      3 ) rollback ; break ;;
      4 ) delete ; break ;;
      5 ) printHelp ; break ;;
      * ) echo ; read -n 1 -s -p "The value \"$REPLY\" is not a valid choice. Press any key to try again..." ; break ;;
    esac
  done
done

) 9>/var/lock/${FLOCK}.lock
