#!/bin/bash

function iso_status
{
  clear ; echo ''
 
  output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm remoteimage -s'`

  echo -n 'Current ISO image: '

  image=`echo "$output" | fgrep 'ShareName' | cut -d' ' -f2 | rev | cut -d/ -f1 | rev`

  image="${image:-(none)}"

  echo ${image}

  read -n 1 -s -p "
Press any key to continue..."  
  clear
}

function iso_eject
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm remoteimage -d' 1>/dev/null 2>&1

  echo 'Eject operation started. Please verify the ISO status.'

  read -n 1 -s -p "
Press any key to continue..." 
  clear
}

function iso_attach
{
  clear ; echo ''

  ISO_LIST="/home/${CORE_USER}/iso_list"

  touch ${ISO_LIST}

  if [ ! -s ${ISO_LIST} ]
  then

   echo "No ISO images were found. Please notify your support team." ; 

  else

    echo -e "\nInvalid choice will cancel this operation:\n"

    select opt in `cat ${ISO_LIST}` ; do
    case $opt in
      *.iso) 
        
	attach=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm remoteimage -c -u iso -p ${SAMBA_PASSWORD} -l //${PRIVATE_IP}/iso/${opt}"`
	
	clear ; echo ''

	echo "$attach" | fgrep -v 'racadm' | rev | cut -d':' -f1 | rev | xargs
        	
	break  
        ;;
      * ) 
	echo -e "\nThe value \"$REPLY\" is not a valid choice. Returning to previous menu."
        break 	
        ;;
     
    esac
    done
  fi

  read -n 1 -s -p "
Press any key to continue..."  
  clear
}

function printHelp
{
        clear
        echo -e "

Help/About 
                                
ISO image actions available to this BMS node:

- Status      - Show the current ISO image status.  
- Eject       - Disconnect the ISO image from the virtual drive. 
- Attach      - Select an ISO image and attach it to the virtual optical drive. 

If you notice anything missing or not functioning as expected, please contact your support team.

                " | fold -w 80 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

################################# MAIN ##############################################

source idrac-ssh-arguments.sh

(
# This script requires a shared lock
flock -s -n 9 || { 

        echo -e "\nThe server is performing another critical operation... Please try later.\n" ;
        echo -e "If the problem persists, contact your support.\n" ;
        read -n 1 -s -p "Press any key to continue..."
     
        exit 1  
}

PS3=$'\n'"Your choice: "

clear
all_done=0
while (( !all_done ))
do
        echo -e "\n************** ISO image actions ********************\n"
	select item in "Exit this script" "Status" "Eject" "Attach" "Help/About" ;
        do
                case "$REPLY" in
                        1 ) echo ; all_done=1 ; break ;;
                        2 ) iso_status ; break ;;
                        3 ) iso_eject ; break ;;
                        4 ) iso_attach ; break ;;
                        5 ) printHelp ; break ;;
                        * ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again." ;;
                esac
        done
done

clear

) 9>/var/lock/${FLOCK}.lock

