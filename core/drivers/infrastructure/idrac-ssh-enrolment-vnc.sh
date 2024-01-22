#!/bin/bash

# This script is executed in the context of the main enrolment routine!

# Enable VNC server
sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.VNCServer.Enable 1' 1>/dev/null 2>&1
if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get iDRAC.VNCServer.Enable' ) | tail -1 | grep -v -q 'Enabled'
then
   echo -e "\nFAILED: Cannot enable VNC server!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_VNC}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time.....\n'

# Set VNC password
output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.VNCServer.Password '${iDRAC_VNC_PASSWORD} | tail -1`
if ! echo ${output} | grep -i -q 'success'
then
   echo -e "\nFAILED: Cannot set VNC password!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_VNC}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time......\n'

# Set VNC timeout
output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.VNCServer.Timeout 300' | tail -1`
if ! echo ${output} | grep -i -q 'success'
then
   echo -e "\nFAILED: Cannot set VNC timeout!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_VNC}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time.......\n'

# Set VNC port
output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.VNCServer.Port 5901' | tail -1`
if ! echo ${output} | grep -i -q 'success'
then
   echo -e "\nFAILED: Cannot set VNC port!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_VNC}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time........\n'

# Disable SSL/TLS for VNC 
output=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set iDRAC.VNCServer.SSLEncryptionBitLength 0' | tail -1`
if ! echo ${output} | grep -i -q 'success'
then
   echo -e "\nFAILED: Cannot disable SSL/TLS for VNC!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_VNC}
fi
clear ; echo -e '\nConfiguring iDRAC, this may take some time.........\n'
