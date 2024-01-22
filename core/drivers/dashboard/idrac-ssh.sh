#!/bin/bash

function power_actions
{
 idrac-ssh-power-actions.sh -h ${HOST}':'${PORT} -u ${USERNAME} -p ${PASSWORD}
}

function optical_drive
{
 idrac-ssh-optical-drive.sh -h ${HOST}:${PORT} -u ${USERNAME} -p ${PASSWORD}
}

function factory_defaults
{	
 # Normally, users shouldn't be allowed to perform this operation:	
 #	
 # idrac-ssh-factory-defaults.sh -h ${HOST}:${PORT} -u ${USERNAME} -p ${PASSWORD}
 #
 # so instead, we're giving them a stub message:

        clear
        
        echo -e "
                                 
This operation is potentially destructive and for that reason not directly exposed to end-users.

Please consult your support team if you wish to restore original firmware settings on this server.

                " | fold -w 80 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

function printHelp
{
        clear
        
        echo -e "

Help/About 
                                
This interactive script acts as a top-level dashboard for the iDRAC based BMS nodes. It relies on the SSH to execute the appropriate OOB commands on the targeted servers.

If you notice anything missing or not functioning as expected, please contact your support team.

                " | fold -w 80 -s
        read -n 1 -s -p "Press any key to continue..."  
        clear
}

################################# MAIN ##############################################

source idrac-ssh-arguments.sh

PS3=$'\n'"Your choice: "

clear
all_done=0
while (( !all_done ))
do
        echo -e "\n************** Main menu ********************\n"
        select item in "Exit this script" "Power actions" "Virtual CD/DVD" "Factory defaults" "Help/About" ;
        do
                case "$REPLY" in
                        1 ) echo ; all_done=1 ; break ;;
                        2 ) power_actions ; break ;;
                        3 ) optical_drive ; break ;;
                        4 ) factory_defaults ; break ;;
                        5 ) printHelp ; break ;;
                        * ) echo -e "\nThe value \"$REPLY\" is not a valid choice. Please try again." ;;
                esac
        done
done

