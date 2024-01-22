#!/bin/bash

#
# This script should never be exposed to end-users!
#
# It's meant to be used by operators only. Bugs in iDRAC, 
# Guacamole or this script itself could potentially lead
# to a loss of control over the server, mainly by exposing
# the Console session while Lifecycle Controller (LCC) is enabled... 
#
# The purpose of this script is to quickly restore the
# server's firmware settings to their initial state. This
# includes BIOS, NICs, RAID controllers, etc. The initial settings 
# are stored in a separate XML for each server, and exposed via CIFS
# protocol.
#
# The Lifecycle XML files should be named as idrac-<iDRAC-MAC>.xml
# where <iDRAC-MAC> represents the MAC address in lowercase dash-notation,
# i.e. 11-22-33-aa-bb-cc and not 11:22:33:aa:bb:cc or 11:22:33:AA:BB:CC.
#  
# Unlike other drivers from this category, the iDRAC user executing
# the "racadm" commands needs to have full administrative privileges.  

function factory_defaults
{
  clear ; echo ''

  local sure=0
  while ((!sure))
  do
    echo -e "WARNING: All data on your server will be permanently lost!"
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
    echo -e "WARNING: All data on your server will be permanently lost!"
    echo -e "\nYou are almost at the point of no return.\n\nDo you still wish to proceed with this operation?\n"
    select ac in "Abort" "Proceed"
    do
      case $ac in
        Abort     ) clear ; return ;;
        Proceed   ) sure2=1 ; break ;;
        *   ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again.\n" ; break ;;
       esac
    done
  done  

  clear ; echo -e '\nPlease wait, this may take some time.\n'
  
  # VNC --> OFF as we want to reduce the chances of end-users accessing the LCC through the console while XML import is in progress
  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.VNCServer.Enable 0' 1>/dev/null 2>&1
  if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get iDRAC.VNCServer.Enable' ) | grep -v -q 'Disabled'
  then
    echo -e "\nFAILED: Cannot disable VNC server!\n\nPlease try again or contact your support if the problem persists.\n\n"	  
    read -n 1 -s -p "Press any key to continue..."
    clear ; return
  fi	  
  clear ; echo -e '\nPlease wait, this may take some time..\n'
  
  # Power --> OFF because XML import can fail if the VGA output is currently displaying BIOS or any other firmware interface
  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm serveraction powerdown' 1>/dev/null 2>&1
  if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm serveraction powerstatus' ) | grep -v -q 'OFF'
  then
    echo -e "\nFAILED: Unable to power-off!\n\nPlease try again or contact your support if the problem persists.\n\n"	  
    read -n 1 -s -p "Press any key to continue..."
    clear ; return
  fi	  
  clear ; echo -e '\nPlease wait, this may take some time...\n'

  # Remove the ISO form the virtual optical drive
  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm remoteimage -d' 1>/dev/null 2>&1
  if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm remoteimage -s' ) | grep -v -q 'Disabled'
  then
    echo -e "\nFAILED: Unable to power-off!\n\nPlease try again or contact your support if the problem persists.\n\n"	  
    read -n 1 -s -p "Press any key to continue..."
    clear ; return
  fi	  
  clear ; echo -e '\nPlease wait, this may take some time....\n'
 
  # Lifecycle controller (LCC) --> ON; this MUST NOT happen if VNC server is enabled!
  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set LifecycleController.LCAttributes.LifecycleControllerState 1' 1>/dev/null 2>&1
  if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get LifecycleController.LCAttributes.LifecycleControllerState' ) | grep -v -q 'Enabled'
  then
    echo -e "\nFAILED: Cannot enable Lifecycle controller!\n\nPlease try again or contact your support if the problem persists.\n\n"	  
    read -n 1 -s -p "Press any key to continue..."
    clear ; return
  fi	  
  clear ; echo -e '\nPlease wait, this may take some time.....\n'
  
  # Fetch the iDRAC's MAC address and form the XML file name based on it
  MAC_LINE=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm getsysinfo' | grep -E '^MAC Address'`
  MAC_ADDR=`echo $MAC_LINE | cut -d'=' -f2 | tr ':' '-' | xargs` 
  MAC_ADDR=${MAC_ADDR^^} # To upper-case!
  IDRAC_XML='idrac-'${MAC_ADDR}'.xml'

  clear ; echo -e '\nPlease wait, this may take some time......\n'

  # Import the XML
  import=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set -t xml -f ${IDRAC_XML} -l //${PRIVATE_IP}/idrac//xml -u idrac -p ${SAMBA_PASSWORD} -s On"` 
  if echo ${import} | grep -i -q 'error'
  then
    echo -e "\nFAILED: Cannot import XML!\n\nPlease try again or contact your support if the problem persists.\n\n"
    echo -e "${import}\n\n" 
    read -n 1 -s -p "Press any key to continue..."
    clear ; return
  fi
  status_command=`echo $import | cut -d'"' -f2` 
  timeout 600 bash <<-EOF
	message=''
	while true
	do
		clear ; echo -e '\n'"\$message" ; sleep 5		
		# Close the STDIN file descriptor; otherwise, if the satus_command is empty, the user will get a unrestricted  CLI access (prompt)!
		message=\$(sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} ${status_command} 0<&-)
		if echo \${message} | grep -i -q SYS053
		then
			clear ; echo -e '\n'"\$message" ; sleep 5		
			echo -n -e '\nDone importing XML... Please wait a few more moments to wrap things up.'
			sleep 5
			break
		fi
	done 
	EOF
  loop_status=$?
  if [ $loop_status == 124 ] # see timeout(1) for more details
  then	  
    echo -e "\nFAILED: Import XML has timed out!\n\nPlease contact your support in order to resolve this problem.\n\n"
    read -n 1 -s -p "Press any key to continue..."
    clear ; return	  
  fi	  
  echo -n '.'

  # Lifecycle controller (LCC) --> OFF
  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set LifecycleController.LCAttributes.LifecycleControllerState 0' 1>/dev/null 2>&1
  if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get LifecycleController.LCAttributes.LifecycleControllerState' ) | grep -v -q 'Disabled'
  then
    clear	  
    echo -e "\nFAILED: Cannot disable Lifecycle controller!\n\nPlease try again or contact your support if the problem persists.\n\n"	  
    read -n 1 -s -p "Press any key to continue..."
    clear ; return
  fi	  
  echo -n '.'

  # VNC --> ON; this MUST NOT happen if LC is enabled!
  sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.VNCServer.Enable 1' 1>/dev/null 2>&1
  if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get iDRAC.VNCServer.Enable' ) | grep -q 'Disabled'
  then
    clear	  
    echo -e "\nFAILED: Cannot enable VNC server!\n\nPlease try again or contact your support if the problem persists.\n\n"         
    read -n 1 -s -p "Press any key to continue..."
    clear ; return
  fi
  echo -n '.' ; sleep 1

  clear
  echo -e "\nSuccess! The server has been restored to its initial state.\n" 
  read -n 1 -s -p "Press any key to continue..."  
  clear
}

function printHelp
{
        clear
        echo -e "

Help/About 
                                
This operation will restore the initial firmware (BIOS, NIC and RAID) settings on the server. Be careful as it almost certainly results in a permanent data loss (including your operating system)!

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
	select item in "Exit this script" 'Restore firmware settings (!)' "Help/About" ;
        do
                case "$REPLY" in
                        1 ) echo ; all_done=1 ; break ;;
                        2 ) factory_defaults ; break ;;
                        3 ) printHelp ; break ;;
                        * ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again." ;;
                esac
        done
done

clear

) 9>/var/lock/${FLOCK}.lock

