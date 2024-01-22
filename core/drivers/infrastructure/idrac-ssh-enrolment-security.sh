#!/bin/bash

# This script is executed in the context of the main enrolment routine!

clear ; echo -e '\nConfiguring iDRAC, this may take some time.\n'

# Disable local RACADM
sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.LocalSecurity.LocalConfig 1' 1>/dev/null 2>&1
if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get iDRAC.LocalSecurity.LocalConfig' ) | tail -1 | grep -v -q 'Enabled'
then
   echo -e "\nFAILED: Cannot disable local RACADM!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_SECURITY}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time..\n'

# Disable local preboot settings
sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.LocalSecurity.PrebootConfig 1' 1>/dev/null 2>&1
if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get iDRAC.LocalSecurity.PrebootConfig' ) | tail -1 | grep -v -q 'Enabled'
then
   echo -e "\nFAILED: Cannot disable local preboot settings!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_SECURITY}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time...\n'

# Disable OS-to-iDRAC pass-through
sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.OS-BMC.AdminState 0' 1>/dev/null 2>&1
if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get iDRAC.OS-BMC.AdminState' ) | tail -1 | grep -v -q 'Disabled'
then
   echo -e "\nFAILED: Cannot disable OS-to-iDRAC pass-through!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_SECURITY}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time....\n'
