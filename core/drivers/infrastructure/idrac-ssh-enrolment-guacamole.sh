#!/bin/bash

# This script is executed in the context of the main enrolment routine!
 
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
VALUES (@resources_cg_id, '${iDRAC_FULL_NAME}');
SELECT LAST_INSERT_ID()
INTO @bms_group_id;

-- Add VGA output entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('VGA output', @bms_group_id, 'vnc', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @vga_output_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@vga_output_id, 'hostname', '${iDRAC_OOB_IP}'),
(@vga_output_id, 'port', '5901'),
(@vga_output_id, 'password', '${iDRAC_VNC_PASSWORD}');

-- Add Dashboard entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('Dashboard', @bms_group_id, 'ssh', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @dashboard_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@dashboard_id, 'hostname', 'core'),
(@dashboard_id, 'port', '22'),
(@dashboard_id, 'username', '${CORE_USER}'),
(@dashboard_id, 'password', '${CORE_PASSWORD}'),
(@dashboard_id, 'command', 'idrac-ssh.sh -h ${iDRAC_OOB_IP}:22 -u ${operator} -p ${iDRAC_USER_PASSWORDS[${operator}]}');

-- Add Firmware reset entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('Firmware reset', @bms_group_id, 'ssh', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @firmware_reset_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@firmware_reset_id, 'hostname', 'core'),
(@firmware_reset_id, 'port', '22'),
(@firmware_reset_id, 'username', '${CORE_USER}'),
(@firmware_reset_id, 'password', '${CORE_PASSWORD}'),
(@firmware_reset_id, 'command', 'idrac-ssh-firmware-reset.sh -h ${iDRAC_OOB_IP}:22 -u ${operator} -p ${iDRAC_USER_PASSWORDS[${operator}]}');

-- Add Factory defaults entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('Factory defaults', @bms_group_id, 'ssh', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @factory_defaults_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@factory_defaults_id, 'hostname', 'core'),
(@factory_defaults_id, 'port', '22'),
(@factory_defaults_id, 'username', '${CORE_USER}'),
(@factory_defaults_id, 'password', '${CORE_PASSWORD}'),
(@factory_defaults_id, 'command', 'idrac-ssh-defaults-restore.sh -h ${iDRAC_OOB_IP}:22 -u ${admin} -p ${iDRAC_USER_PASSWORDS[${admin}]}');

-- SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Manually triggered rollback!';     

COMMIT;   
"
TXN_STATUS=$? ; [ $TXN_STATUS -ne 0 ] && { echo 'Transaction rollbacked.' ; exit ${RET_iDRAC_GUACAMOLE} ; }
