#!/bin/bash

# Exit codes in the sub-scripts
RET_SUCCESS=0
RET_ABORTED=9
RET_iDRAC_SECURITY=10
RET_iDRAC_VNC=20
RET_iDRAC_USERS=30
RET_iDRAC_XML=40
RET_iDRAC_PAGW=50
RET_iDRAC_GUACAMOLE=60

# The SSH parameters on iDRAC in factory default state
USERNAME=root
PORT=22

TIMEOUT="${INTERACTIVE_TIMEOUT:-20}"

function print_intro
{
    clear
    echo -e "

Introduction
                                
This script will perform the initial setup of your iDRAC-based BMS server. 

It assumes the server is semi-ready for the inclusion:

- Networking is fully set up, including the iDRAC's IP configuration.  
- Firmware has been upgraded to the desired version.
- Root password has been changed.
- The relevant firmware settings are in their factory-default state.

Please refer to the infrastructure/ documentation for more details. 
                " | fold -w 80 -s
                
    # Enable intercative user to abort the script
    echo -e "To abort the script, press any key in the following ${TIMEOUT} seconds.\n"
    IFS=
    if read -r -s -n 1 -t ${TIMEOUT} key
    then
        echo -e "Exiting...\n"
        sleep 3
        exit ${RET_ABORTED}
    fi
}

function collect_input
{

   while true
   do	   
      [ -z "$iDRAC_OOB_IP" ] && read -p 'Enter OOB IP address: ' iDRAC_OOB_IP
      echo 

      [ -z "$iDRAC_ROOT_PASSWORD" ] && read -sp 'Enter BMS root password: ' iDRAC_ROOT_PASSWORD
      echo -e "\n" 

      # Check SSH credentials and SSH connectivity
      sshpass -p ${iDRAC_ROOT_PASSWORD} ssh -q -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${iDRAC_OOB_IP} 'version' 1>/dev/null 2>&1
      [ $? == 0 ] && break
      
      echo -e "\nUnable to establish SSH connection against ${iDRAC_OOB_IP}.\n\nPlease re-enter the desired destination parameters or check your server.\n" >&2
      unset iDRAC_OOB_IP iDRAC_ROOT_PASSWORD
   done

   [ -z "$iDRAC_FULL_NAME" ] && read -p 'Enter Guacamole name for this server, e.g. [paris-bms3, Mgmt: A0:12:36:11:22:FE]: ' iDRAC_FULL_NAME
   echo

   if [ -z "$iDRAC_VNC_PASSWORD" ] 
   then
      while true
      do	
         read -sp 'Enter VNC server password: ' iDRAC_VNC_PASSWORD
         echo -e "\n" 
         read -sp 'Confirm VNC server password: ' iDRAC_VNC_PASSWORD_TMP
         echo -e "\n"
			
	 [ "$iDRAC_VNC_PASSWORD" == "$iDRAC_VNC_PASSWORD_TMP" ] && break 
			
         echo -e "\nPasswords do not match. Please try again.\n" 
         unset iDRAC_VNC_PASSWORD iDRAC_VNC_PASSWORD_TMP
      done	
   fi

   [ -z "$BMS_IC_VLAN" ] && read -p 'Enter VLAN id assigned to this server: ' BMS_IC_VLAN
   echo 
}

print_intro
collect_input

# Use simpler variable names
PASSWORD=${iDRAC_ROOT_PASSWORD}
HOST=${iDRAC_OOB_IP}
VLAN=${BMS_IC_VLAN}

# Lock down the server
. idrac-ssh-enrolment-security.sh

# Configure VNC server
. idrac-ssh-enrolment-vnc.sh

# Set the local iDRAC users
. idrac-ssh-enrolment-user-accounts.sh

# LCC profile export and XML edit
. idrac-ssh-enrolment-xml-profile.sh

# Attach the BMS instance to the default PAGW
. idrac-ssh-enrolment-pagw.sh

# Create Guacamole connections for this BMS instance
. idrac-ssh-enrolment-guacamole.sh
