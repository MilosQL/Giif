#!/bin/bash

# Exit codes in the sub-scripts
RET_SUCCESS=0
RET_ABORTED=9
RET_VM_ID_NOT_FOUND=1

# The SSH parameters on a default Proxmox VE setup
USERNAME=root
PORT=22

TIMEOUT="${INTERACTIVE_TIMEOUT:-5}"

function print_intro
{
    clear
    echo -e "

Introduction
                                
This script will perform the enrolment of the specified Proxmox-VE VM. 

It assumes the following:

- The VM has been fully provisioned (either manually or through some reservation driver).
- It has exactly one networking interface connected to the default project-management segment.
- The MAC addresses and roles of all networking ports are described in the Notes section of the VM.
- The VNC port is (locally) unique and calculated as (5900 + VM-id). 

Please refer to the infrastructure/ documentation for more details. 
                " | fold -w 100 -s
                
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
      [ -z "$PROXMOX_VE_IP" ] && read -p 'Enter Proxmox-VE IP address: ' PROXMOX_VE_IP
      echo 

      [ -z "$PROXMOX_VE_ROOT_PASSWORD" ] && read -sp 'Enter Proxmox-VE root password: ' PROXMOX_VE_ROOT_PASSWORD
      echo -e "\n" 

      # Check SSH credentials and SSH connectivity
      sshpass -p ${PROXMOX_VE_ROOT_PASSWORD} ssh -q -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${PROXMOX_VE_IP} 'cat /etc/os-release' 1>/dev/null 2>&1
      [ $? == 0 ] && break
      
      echo -e "\nUnable to establish SSH connection against ${PROXMOX_VE_IP}.\n\nPlease re-enter the desired destination parameters or check your server.\n" >&2
      unset PROXMOX_VE_IP PROXMOX_VE_ROOT_PASSWORD
   done

   [ -z "$PROXMOX_VE_VM_ID" ] && read -p 'Enter Proxmox-VE id of this VM: ' PROXMOX_VE_VM_ID
   echo
}

print_intro
collect_input

# Use simpler variable names
IP=${PROXMOX_VE_IP}
PASSWORD=${PROXMOX_VE_ROOT_PASSWORD}
ID=${PROXMOX_VE_VM_ID}

VM_NAME=`sshpass -p ${PASSWORD} ssh -q -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${IP} "qm config ${ID} | grep -E '^name:' | cut -d':' -f2 | xargs"`
if [ -z $VM_NAME ]
then
        echo -e "\nVM-$ID not found on the host. Aborting...\n"
        exit ${RET_VM_ID_NOT_FOUND}
fi

PROXMOX_VE_HOSTNAME=`sshpass -p ${PASSWORD} ssh -q -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${IP} 'hostname'`

VM_GUACAMOLE_NAME="<vm-${ID} on ${PROXMOX_VE_HOSTNAME}, ${VM_NAME}>"

VNC_PORT=$((5900 + $ID))

# Developer's note: Checking whether or not the VM has been attached 
# to the --default proj. mgmt. segment is not a simple 
# task as it requires database records with network information 
# about each VM-host. This may come later.

mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"

START TRANSACTION;

SELECT connection_group_id 
INTO @project_roof_id
FROM guacamole_connection_group 
WHERE connection_group_name='${PROJECT_CONNECTION_GROUP}';

SELECT connection_group_name
INTO @default_project_cg_name
FROM pagw_default_slot,pagw_instances, guacamole_connection_group
WHERE guacamole_connection_group.connection_group_id=pagw_instances.connection_group_id 
AND pagw_instances.pagw_slots_id=pagw_default_slot.id;

SELECT connection_group_id
INTO @project_cg_id
FROM guacamole_connection_group
WHERE parent_id = @project_roof_id
AND connection_group_name=@default_project_cg_name;

SELECT connection_group_id
INTO @resources_cg_id
FROM guacamole_connection_group
WHERE parent_id = @project_cg_id
AND connection_group_name='${PROJECT_RESOURCES}';

-- Create the server's subdirectory and save its ID
INSERT INTO guacamole_connection_group(parent_id, connection_group_name) 
VALUES (@resources_cg_id, '${VM_GUACAMOLE_NAME}');
SELECT LAST_INSERT_ID()
INTO @vm_group_id;

-- Add VGA output entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('VGA output', @vm_group_id, 'vnc', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @vga_output_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@vga_output_id, 'hostname', '${IP}'),
(@vga_output_id, 'port', '${VNC_PORT}');

-- Add Dashboard entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('Dashboard', @vm_group_id, 'ssh', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @dashboard_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@dashboard_id, 'hostname', 'core'),
(@dashboard_id, 'port', '22'),
(@dashboard_id, 'username', '${CORE_USER}'),
(@dashboard_id, 'password', '${CORE_PASSWORD}'),
(@dashboard_id, 'command', 'proxmox-ve-ssh.sh -h ${PROXMOX_VE_IP}:22 -u ${USERNAME} -p ${PASSWORD} -m ${ID} ');

-- Add Snapshot-management entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('Snapshots', @vm_group_id, 'ssh', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @snapshots_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@snapshots_id, 'hostname', 'core'),
(@snapshots_id, 'port', '22'),
(@snapshots_id, 'username', '${CORE_USER}'),
(@snapshots_id, 'password', '${CORE_PASSWORD}'),
(@snapshots_id, 'command', 'proxmox-ve-ssh-snapshots.sh -h ${PROXMOX_VE_IP}:22 -u ${USERNAME} -p ${PASSWORD} -m ${ID} ');

-- Add Backup-management entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('Backups', @vm_group_id, 'ssh', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @backups_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@backups_id, 'hostname', 'core'),
(@backups_id, 'port', '22'),
(@backups_id, 'username', '${CORE_USER}'),
(@backups_id, 'password', '${CORE_PASSWORD}'),
(@backups_id, 'command', 'proxmox-ve-ssh-backups.sh -h ${PROXMOX_VE_IP}:22 -u ${USERNAME} -p ${PASSWORD} -m ${ID} ');

-- SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Manually triggered rollback!';     

COMMIT;   
"
TXN_STATUS=$? ; [ $TXN_STATUS -ne 0 ] && { echo 'Transaction rollbacked.' ; exit ${RET_iDRAC_GUACAMOLE} ; }
