#!/bin/bash

#
# The script performs a soft reset on iDRAC.
#
# It's mainly intended for the use by the operators. 
# It can also be exposed to the end users, typically on faulty
# servers which occasionally end-up with a distorted VGA output.
#
 
function firmware_reset
{
  clear ; echo ''

  local sure=0
  while ((!sure))
  do
    echo -e "WARNING: This operation can disrupt the normal functioning of the server!"
    echo -e "\nAre you sure you want to proceed with this operation?\n"
    select yn in "Yes" "No"
    do
      case $yn in
        Yes ) sure=1 ; break ;;
        No  ) clear ; echo '' ; return ;;
        *   ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again.\n" ; break ;;
       esac
    done
  done                          

  clear ; echo ''

  local sure2=0
  while ((!sure2))
  do
    echo -e "WARNING: The server is about to be disconnected due to a soft reset on iDRAC."
    echo -e "\nDo you still wish to proceed with this operation?\n"
    select ac in "Abort" "Proceed"
    do
      case $ac in
        Abort     ) clear ; return ;;
        Proceed   ) sure2=1 ; break ;;
        *   ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again.\n" ; break ;;
       esac
    done
  done  

  clear
  echo -e '\nPlease wait, it may take some time for iDRAC to re-establish its network connectivity.\n'
  echo -e '\nIf the server does not come online after a few minutes, please contact your support.\n' 

  
  # iDRAC soft reset using racadm command
  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm racreset soft' 1>/dev/null 2>&1
 
}

function printHelp
{
        clear
        echo -e "

Help/About 
                                
This operation will perform a soft reset on the iDRAC interface of this server. It's typically used to resolve the distorted VGA output caused by a glitch in iDRAC's VNC server.

Feel free to contact your support team if you don't wish for this option to be exposed to you or any other project members.

                " | fold -w 80 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

################################# MAIN ##############################################

source idrac-ssh-arguments.sh

(
# This script requires an exclusive lock
flock -x -n 9 || { 

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
        echo -e "\n************** Snapshot actions ********************\n"
	select item in "Exit this script" 'iDRAC soft reset (!)' "Help/About" ;
        do
                case "$REPLY" in
                        1 ) echo ; all_done=1 ; break ;;
                        2 ) firmware_reset ; break ;;
                        3 ) printHelp ; break ;;
                        * ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again." ;;
                esac
        done
done

clear

) 9>/var/lock/${FLOCK}.lock

