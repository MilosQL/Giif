#!/bin/bash

 # Developer's note: The "at" command is used to prevent 
 # Guacamole users from issuing SIGINT (Ctrl-C) and other signals
 # which in turn disrupt the "qm" operations and can lead to VM locking!

function status
{
  clear ; echo ''
 
  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm status ${VM_ID}"

  read -n 1 -s -p "
Operation complete. Press any key to continue..."  
  clear
}

function start
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "/usr/bin/echo qm start ${VM_ID} | at -M now + 1 minute"

  read -n 1 -s -p "
Operation complete. Press any key to continue..." 
  clear
}

function shutdown
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm shutdown ${VM_ID} --timeout 15 --forceStop"

  read -n 1 -s -p "
Operation complete. Press any key to continue..."  
  clear
}

function stop
{
  clear ; echo '' 

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm stop ${VM_ID}"

  read -n 1 -s -p "
Operation complete. Press any key to continue..."  
  clear
}

function reboot
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm reboot ${VM_ID} --timeout 15" 1>/dev/null 2>&1

  read -n 1 -s -p "
Operation complete. Press any key to continue..."  
  clear
}

function reset
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm reset ${VM_ID}"

  read -n 1 -s -p "
Operation complete. Press any key to continue..."  
  clear
}

function pause
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm suspend ${VM_ID}"

  read -n 1 -s -p "
Operation complete. Press any key to continue..."  
  clear
}

function resume
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "qm resume ${VM_ID}"

  read -n 1 -s -p "
Operation complete. Press any key to continue..."  
  clear
}

function hibernate
{
  clear ; echo ''

  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "/usr/bin/echo qm suspend ${VM_ID} --todisk |  at -M now + 1 minute"

  read -n 1 -s -p "
Operation initiated. Press any key to continue..."  
  clear
}

function printHelp
{
        clear
        echo -e "

Help/About 
                                
Power actions available to this BMS node:

- Status            - Displays the current power status. 
- Start             - Powers up the VM. 
- Shutdown          - Tries to gracefully shut down the VM; stop forcefully otherwise.
- Stop              - Immediate power down. 
- Reboot            - Tries to gracefully reboot the VM. 
- Reset             - Power cycle. 
- Pause             - Freezes the execution of the VM.
- Resume            - Resume the execution of the paused VM.
- Hibernate         - Suspends the VM and saves its state to the disk. 

If you notice anything missing or not functioning as expected, please contact your support team.

                " | fold -w 100 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

################################# MAIN ##############################################

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

clear
all_done=0
while (( !all_done ))
do
        echo -e "\n************** Power actions ********************\n"
	select item in "Exit this script" "Status" "Start" "Shutdown" "Stop" "Reboot" "Reset" "Pause" "Resume" "Hibernate" "Help/About" ;
        do
                case "$REPLY" in
                        1 ) echo ; all_done=1 ; break ;;
                        2 ) status ; break ;;
                        3 ) start ; break ;;
                        4 ) shutdown ; break ;;
                        5 ) stop ; break ;;
                        6 ) reboot ; break ;;
                        7 ) reset ; break ;;
                        8 ) pause ; break ;;
                        9 ) resume ; break ;;
                       10 ) hibernate ; break ;;
                       11 ) printHelp ; break ;;
                        * ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again." ;;
                esac
        done
done

clear

) 9>/var/lock/${FLOCK}.lock
