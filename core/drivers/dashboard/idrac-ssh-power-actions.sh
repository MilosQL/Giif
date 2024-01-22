#!/bin/bash

function power_status
{
  clear ; echo ''
 
  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm serveraction powerstatus'

  read -n 1 -s -p "
Press any key to continue..."  
  clear
}

function power_down
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm serveraction powerdown'

  read -n 1 -s -p "
Press any key to continue..." 
  clear
}

function power_up
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm serveraction powerup'

  read -n 1 -s -p "
Press any key to continue..."  
  clear
}

function power_cycle
{
  clear ; echo '' 

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm serveraction powercycle'

  read -n 1 -s -p "
Press any key to continue..."  
  clear
}

function hard_reset
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm serveraction hardreset'

  read -n 1 -s -p "
Press any key to continue..."  
  clear
}

function graceful_shutdown
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm serveraction graceshutdown'

  read -n 1 -s -p "
Press any key to continue..."  
  clear
}

function printHelp
{
        clear
        echo -e "

Help/About 
                                
Power actions available to this BMS node:

- Power status      - Displays the current power status (ON or OFF). 
- Power down        - Powers down the managed system. 
- Power up          - Powers up the managed system. 
- Power cycle       - Cold reboot. 
- Hard reset        - Warm reboot. 
- Graceful shutdown - If the operating system on the server cannot shut down completely, then this operation is not performed.

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
        echo -e "\n************** Power actions ********************\n"
	select item in "Exit this script" "Power status" "Power down" "Power up" "Power cycle" "Hard reset" "Graceful shutdown" "Help/About" ;
        do
                case "$REPLY" in
                        1 ) echo ; all_done=1 ; break ;;
                        2 ) power_status ; break ;;
                        3 ) power_down ; break ;;
                        4 ) power_up ; break ;;
                        5 ) power_cycle ; break ;;
                        6 ) hard_reset ; break ;;
                        7 ) graceful_shutdown ; break ;;
                        8 ) printHelp ; break ;;
                        * ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again." ;;
                esac
        done
done

clear

) 9>/var/lock/${FLOCK}.lock
