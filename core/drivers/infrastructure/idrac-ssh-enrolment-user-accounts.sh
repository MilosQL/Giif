#!/bin/bash

# This script is executed in the context of the main enrolment routine!

# Enable IPMI-over-LAN globally 
output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.IPMILan.Enable 1' | tail -1`
if ! echo ${output} | grep -i -q 'success'
then
   echo -e "\nFAILED: Cannot enable IPMI-over-LAN globally!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_USERS}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time..........\n'

# Cap the global IPMI-over-LAN level to read-only: 2 - (User), 3 - (Operator) or 4 - (Administrator) 
output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.IPMILan.PrivLimit 3' | tail -1`
if ! echo ${output} | grep -i -q 'success'
then
   echo -e "\nFAILED: Unable to limit the global IPMI-over-LAN!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_USERS}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time...........\n'

operator="${iDRAC_OPERATOR_NAME:-bms-operator}"
admin="${iDRAC_OPERATOR_NAME:-bms-admin}"
monitor="${iDRAC_OPERATOR_NAME:-bms-monitor}"

declare -A iDRAC_USER_INDEXES
iDRAC_USER_INDEXES[${operator}]="${iDRAC_OPERATOR_INDEX:-3}"
iDRAC_USER_INDEXES[${admin}]="${iDRAC_ADMIN_INDEX:-4}"
iDRAC_USER_INDEXES[${monitor}]="${iDRAC_MONITOR_INDEX:-5}"

declare -A iDRAC_USER_PASSWORDS
iDRAC_USER_PASSWORDS[${operator}]="${iDRAC_OPERATOR_PASSWORD:-`tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''`}"
iDRAC_USER_PASSWORDS[${admin}]="${iDRAC_ADMIN_PASSWORD:-`tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''`}"
iDRAC_USER_PASSWORDS[${monitor}]="${iDRAC_MONITOR_PASSWORD:-`tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''`}"

declare -A iDRAC_USER_PRIVILEGES
iDRAC_USER_PRIVILEGES[${operator}]='0x1f3'
iDRAC_USER_PRIVILEGES[${admin}]='0x1ff'
iDRAC_USER_PRIVILEGES[${monitor}]='0x001'

declare -A iDRAC_IPMI_LAN_PRIVILEGES
iDRAC_IPMI_LAN_PRIVILEGES[${operator}]='15'
iDRAC_IPMI_LAN_PRIVILEGES[${admin}]='15'
iDRAC_IPMI_LAN_PRIVILEGES[${monitor}]='3'

for key in "${!iDRAC_USER_INDEXES[@]}" 
do
   i=${iDRAC_USER_INDEXES[$key]}

   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.UserName $key" | tail -1`
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Unable to rename the user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi

   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.Password ${iDRAC_USER_PASSWORDS[$key]}" | tail -1`
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Unable to set the password for the user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi

   # Note: User cannot be enabled if either username or password is empty (ERROR: SWC0296)!  
   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.Enable 1" | tail -1`
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Cannot enable user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi

   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.Privilege ${iDRAC_USER_PRIVILEGES[$key]}" | tail -1`
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Unable to limit the iDRAC permissions for the user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi

   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.IpmiLanPrivilege ${iDRAC_IPMI_LAN_PRIVILEGES[$key]}" | tail -1`
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Unable to limit the IPMI-LAN permissions for the user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi

   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.IpmiSerialPrivilege 15" | tail -1`
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Unable to limit the IPMI-over-Serial permissions for the user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi

   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.SolEnable 0" | tail -1` 
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Unable to disable IPMI-over-Serial for the user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi

   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.SNMPv3Enable 0" | tail -1`
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Unable to disable SNMPv3 for the user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi

   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.SNMPv3AuthenticationType 2" | tail -1`
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Unable to set SNMPv3 authentication type for the user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi

   output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm set iDRAC.Users.${i}.SNMPv3PrivacyType 2" | tail -1`
   if ! echo ${output} | grep -i -q 'success'
   then
      echo -e "\nFAILED: Unable to set SNMPv3 privacy type for the user ${key}!\n\nPlease try again or contact your support if the problem persists.\n\n"
      read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
      clear ; exit ${RET_iDRAC_USERS}
   fi
   
done
