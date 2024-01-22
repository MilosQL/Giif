#!/bin/bash

function wizard
{
  clear ; echo -e "\nSelect an optical device on this VM:\n"
 
  optical_drives=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm config ${VM_ID} | fgrep media=cdrom | cut -d',' -f1"`

  oldIFS=$IFS
  IFS=$'\n'
  choices=( $optical_drives )
  count=${#choices[@]}
  IFS=$oldIFS
  PS3=$'\n'"Invalid input will exit this wizard. Your choice: "
  select answer in "${choices[@]}"; do
    if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "$count" ]
    then
      iso_selection $answer
      continue 2
    else
      echo -e "\n\nThe value \"$REPLY\" is not a valid choice. Exiting..." 
      break 2
    fi
  done
  echo "$answer"

  read -n 1 -s -p "
Operation complete. Press any key to continue..."  
  clear
}

function iso_selection
{
  device=${1%:*}

  clear ; echo -e "\nSelect an ISO image for the \"$device\":\n"
 
  storage_list=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "pvesm status --content iso --enabled | tail -n+2 | cut -d' ' -f1"`

  iso_list=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'for i in '$storage_list'; do pvesm list ${i} --content iso ; done | fgrep -v Volid | cut -d" " -f1'`

  iso_list=$'none\n'${iso_list}

  oldIFS=$IFS
  IFS=$'\n'
  choices=( $iso_list )
  count=${#choices[@]}
  IFS=$oldIFS
  PS3=$'\n'"Invalid input will return you to the main menu. Your choice: "
  select answer in "${choices[@]}"; do
    if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "$count" ]
    then
      iso_path=${answer}
      echo
      sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm set ${VM_ID} --${device} media=cdrom,file=${iso_path}"
      echo
      read -n 1 -s -p "ISO operation complete. Press any key to continue..."
    else
      echo	    
      read -n 1 -s -p "The value \"$REPLY\" is not a valid choice. Returning to main menu..." 
    fi
    clear
    exit
  done
}

function printHelp
{
        clear
        echo -e "

Help/About 
                                
ISO actions available to this VM:

- Wizard      - Manage optical drives states. 

If you notice anything missing or not functioning as expected, please contact your support team.

                " | fold -w 100 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

################################# MAIN ##############################################

source proxmox-ve-ssh-arguments.sh

(
# This script requires shared locking
flock -x -n 9 || { 

        echo -e "\nThe server is performing another critical operation... Please try later.\n" ;
        echo -e "If the problem persists, contact your support.\n" ;
        read -n 1 -s -p "Press any key to continue..."
        clear

        exit 1  
}

PS3=$'\n'"Your choice: "

clear
all_done=0
while (( !all_done ))
do
  echo -e "\n************** ISO image operations ********************\n"
	select item in "Exit this script" "Optical drive wizard" "Help/About" ;
        do
                case "$REPLY" in
                        1 ) echo ; all_done=1 ; break ;;
                        2 ) wizard ; break ;;
                        3 ) printHelp ; break ;;
                        * ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again." ;;
                esac
        done
done

clear

) 9>/var/lock/${FLOCK}.lock
