#!/bin/bash

# This script is executed in the context of the main enrolment routine!

clear ; echo -e '\nLCC export in progress...\n'

# Lifecycle controller (LCC) --> ON
sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set LifecycleController.LCAttributes.LifecycleControllerState 1' 1>/dev/null 2>&1
if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get LifecycleController.LCAttributes.LifecycleControllerState' ) | grep -v -q 'Enabled'
then
   echo -e "\nFAILED: Cannot enable Lifecycle controller!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_XML}
fi

# Fetch the iDRAC's MAC address and form the XML file name based on it
MAC_LINE=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm getsysinfo' | grep -E '^MAC Address'`
MAC_ADDR=`echo $MAC_LINE | cut -d'=' -f2 | tr ':' '-' | xargs` 
MAC_ADDR=${MAC_ADDR^^} # To upper-case!
IDRAC_XML='idrac-'${MAC_ADDR}'.xml'

# Export the XML
export=`sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} "racadm get -t xml -f ${IDRAC_XML} -l //${PRIVATE_IP}/idrac//xml -u idrac -p ${SAMBA_PASSWORD}"` 
if echo ${export} | grep -i -q 'error'
then
   echo -e "\nFAILED: Cannot export XML!\n\nPlease try again or contact your support if the problem persists.\n\n"
   echo -e "${export}\n\n" 
   read -n 1 -s -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_XML}
fi
status_command=`echo $export | tr '\n' ' ' | cut -d'"' -f2`

timeout 600 bash <<-EOF
message=''
while true
do
   clear ; echo -e '\n'"\$message" ; sleep 5		
   # Close the STDIN file descriptor; otherwise, if the satus_command is empty, 
   # the user will get a unrestricted  CLI access (prompt)!
   message=\$(sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} ${status_command} 0<&-)
   if echo \${message} | grep -i -q SYS043
   then
      clear ; echo -e '\n'"\$message" ; sleep 5		
      echo -e -n '\nDone exporting XML... Please wait a few more moments to wrap things up... '
      sleep 5
      break
   fi
done 
EOF
loop_status=$?
if [ $loop_status == 124 ] # see timeout(1) for more details
then	  
   echo -e "\nFAILED: Export XML has timed out!\n\nPlease contact your support in order to resolve this problem.\n\n"
   read -n 1 -s -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_XML}	  
fi	  

# Lifecycle controller (LCC) --> OFF
sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm set LifecycleController.LCAttributes.LifecycleControllerState 0' 1>/dev/null 2>&1
if echo $( sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm get LifecycleController.LCAttributes.LifecycleControllerState' ) | grep -v -q 'Disabled'
then
   echo -e "\nFAILED: Cannot enable Lifecycle controller!\n\nPlease try again or contact your support if the problem persists.\n\n"
   read -n 1 -s -t ${TIMEOUT} -p "Press any key to continue..."
   clear ; exit ${RET_iDRAC_XML}
fi

# Best effort shut-down of the server
sshpass -p ${PASSWORD} ssh -q -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'racadm serveraction powerdown' 1>/dev/null 2>&1

# Pull the XML file from the Samba container   
echo -en '\n\nSMBCLIENT: '
smbclient //${PRIVATE_IP}/idrac -Uidrac%${SAMBA_PASSWORD} -c "cd xml; get ${IDRAC_XML}; rename ${IDRAC_XML} ${IDRAC_XML}.original"

# Note: XML editing with tools like "sed" and "awk" is hihgly unreliable!
# The LCC XML schema is described in: 
# https://downloads.dell.com/solutions/general-solution-resources/White%20Papers/LC%20XML%20Schema%20Guide_02_26_2015.pdf

# Insert missing encoding line to avoid bug described here:
# https://sourceforge.net/p/xmlstar/discussion/226076/thread/493856c2/
sed -i '1s/^/<?xml version="1.0" encoding="ISO-8859-1"?> \n/' ${IDRAC_XML}

# Delete the relevant user elements 
xmlstarlet ed -L -d '//Component[@FQDD="iDRAC.Embedded.1"]/Attribute[starts-with(@Name,"Users.")]' ${IDRAC_XML}

# Delete the relevant user comments except the first one
xmlstarlet ed -L -d '//Component[@FQDD="iDRAC.Embedded.1"]/comment()[contains(.,"Users.")][position()>=2]' ${IDRAC_XML}

# Replace the text of the remaining comment with the placeholder
old_comment=`xmlstarlet sel  -t -c '//Component[@FQDD="iDRAC.Embedded.1"]/comment()[contains(.,"Users.")]' ${IDRAC_XML}`
set +H
perl -pi -e "s|\Q$old_comment\E|<!-- Users used to be here -->|" ${IDRAC_XML} 

# Clear and reset all RAID controllers
xmlstarlet ed -L -d '//Component[starts-with(@FQDD, "RAID.")]/Attribute[@Name="RAIDresetConfig"]/following-sibling::*' ${IDRAC_XML}
xmlstarlet ed -L -d '//Component[starts-with(@FQDD, "RAID.")]/Attribute[@Name="RAIDresetConfig"]/preceding-sibling::*' ${IDRAC_XML}
xmlstarlet ed -L -d '//Component[starts-with(@FQDD, "RAID.")]/comment()' ${IDRAC_XML}
xmlstarlet ed -L -u '//Component[starts-with(@FQDD, "RAID.")]/Attribute[@Name="RAIDresetConfig"]' -v 'True' ${IDRAC_XML}

# Disable VNC server
xmlstarlet ed -L -u '//Attribute[@Name="VNCServer.1#Enable"]' -v 'Disabled' ${IDRAC_XML}

# Push the modified XML back to the Samba container
echo -en '\nSMBCLIENT: '
smbclient //${PRIVATE_IP}/idrac -Uidrac%${SAMBA_PASSWORD} -c "cd xml; put ${IDRAC_XML}"

rm ${IDRAC_XML}
