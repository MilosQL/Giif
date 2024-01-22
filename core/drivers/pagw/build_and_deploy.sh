#!/bin/bash

# 
# The script expects two environment variables:
#
# - PROJECT_NAME: If not unique or in a proper
#   basic-hostname format, the script will fail 
#   to proceed and exit.
#
# - PAGW_PASSWORD: Each PAGW instance is spawned 
#   with the default "pagw" user, which can elevate to
#   root privileges by the means of the "sudo" command.       
#   If omitted or left empty, the "pagw" account will be
#   left locked by an unknwon and randomly generated password.
#   (When invoked with the --default flag, the script instead
#   ignores this variable and relies on the DEFAULT_PAGW_PASSWORD
#   value from the top-level .env file.) 
#
# The --default flag is only used when spawning the PAGW
# instance for the so-called "Default project" which has
# a slightly different database workflow when compared
# to ordinary projects.
#
# The first part of the script is database related: finding
# an empty PAGW slot, marking it as taken and matching it with
# the ${PROJECT_NAME} represented as a Guacamole's connection
# group under the roof of ${PROJECT_CONNECTION_GROUP}. 
# All of this is done in a single database transaction.
# 
# Once the PAGW slot is allocated, it's environment parameters
# are fetched and used in the second part of the script which
# deals in the actual build and deployment of the PAGW instance.
#
# The script enforces exclusive locking. The return codes
# are as follows:
# 
# RET_DB_TXN_OK - database transaction was successful
# RET_EXCL_LOCK - exclusive locking is in place, try again later
# RET_DB_TXN_FAIL - database transaction failed to complete
# RET_INVALID_PROJ_NAME - ${PROJECT_NAME} doesn't follow the expected syntax
# RET_PROJ_RECORDS_MISSING - default project records missing
# RET_DEF_PROJ_PRESENT - default project has already been provisioned
# RET_PROJ_TOOLBOX_FAIL - unable to create project-toolbox entries
# RET_DUPLICATE_IP - possible duplicate use of the public IP address

RET_DB_TXN_OK=0
RET_EXCL_LOCK=1
RET_DB_TXN_FAIL=2
RET_INVALID_PROJ_NAME=3
RET_PROJ_RECORDS_MISSING=4
RET_DEF_PROJ_PRESENT=5
RET_PROJ_TOOLBOX_FAIL=6
RET_DUPLICATE_IP=7

# The zero return value only means the PAGW slot allocation was
# successful. The actual PAGW build and deployment process can 
# fail in many ways which are undetectable from the script and
# thus left to the operators (and perhaps end-users) to discover.
#

(
    flock -nx 9 || { 

        echo -e "\nThe PAGW slots in database have been locked by another execution thread... Please try later.\n" ;
        echo -e "If the problem persists, contact your support.\n" ;
     
        exit ${RET_EXCL_LOCK}  
    }


if [ "$1" != "--default" ]
then	
  
  # Trimm any leading and trailing spaces and check if it's a valid non-FQDN hostname
  PROJECT_NAME=`echo ${PROJECT_NAME} | xargs`
  [[ ! "$PROJECT_NAME" =~ ^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$ ]] && { echo 'Invalid project name.' ; exit ${RET_INVALID_PROJ_NAME} ; }
   
  if [ -z "$PAGW_PASSWORD" ] 
  then

    echo -e "\nThe env. variable PAGW_PASSWORD hasn't be set so a randomly generated on will be used instead.\n"
    echo -en "If you wish to interrupt this script (Ctrl-C) and start all over again, " 
    echo -e "please do so before the timer expires.\n"                
        
    for i in `seq 10 -1 1` ; do echo -ne "\r$i " ; sleep 1 ; done

    echo -e "\rProceeding...\n"
  fi

  mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"
  
  START TRANSACTION;
  
  -- Find a free PAGW slot and save its ID
  SELECT  id 
  INTO @free_slot_id 
  FROM pagw_slots    
  WHERE ignored=0 
  AND id NOT IN (SELECT pagw_slots_id FROM pagw_instances)
  LIMIT 1;
  
  -- Fetch the root container for all projects  
  SELECT connection_group_id 
  INTO @project_roof_id
  FROM guacamole_connection_group 
  WHERE connection_group_name='${PROJECT_CONNECTION_GROUP}';
  
  -- Create connection_group entry for the project and save its ID
  INSERT INTO guacamole_connection_group(parent_id, connection_group_name) 
  VALUES (@project_roof_id, '${PROJECT_NAME}');
  SELECT LAST_INSERT_ID()
  INTO @project_cg_id;
  
  -- Associate PAGW slot with project's connection group
  INSERT INTO pagw_instances(pagw_slots_id, connection_group_id) 
  VALUES (@free_slot_id, @project_cg_id);
  
  -- SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Manually triggered rollback!';
  
  COMMIT;
  "
  
  INSERT_STATUS=$? ; [ $INSERT_STATUS -ne 0 ] && { echo -e '\nUnable to create PAGW database entries.\n' ; exit ${RET_DB_TXN_FAIL} ; }
  
  PAGW_ENV=$(mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"
  SELECT CONCAT('PAGW_ADDRESS=',ip), environment
  FROM pagw_slots, pagw_instances, guacamole_connection_group
  WHERE guacamole_connection_group.connection_group_name='${PROJECT_NAME}'
  AND guacamole_connection_group.connection_group_id=pagw_instances.connection_group_id
  AND pagw_instances.pagw_slots_id=pagw_slots.id;
  ")

else 

  # We're building and deploying the --default project. 	

  # take the "sudo" password from the top-level .env file 
  PAGW_PASSWORD=${DEFAULT_PAGW_PASSWORD}

  # skip if the --default project has already been provisioned. 
  SKIP_DEFAULT='/var/lock/skip-default.lock'
  if [ -f $SKIP_DEFAULT ] 
  then
    echo -e -n "\nThe \`${SKIP_DEFAULT}\` file suggests that the \`--default\` instance has already been provisioned."
    echo -e ' Exiting.\n'  
    exit ${RET_DEF_PROJ_PRESENT} 
  fi

  PAGW_ENV=$(mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"
  SELECT CONCAT('PAGW_ADDRESS=',ip), environment
  FROM pagw_slots
  WHERE id IN (SELECT id FROM pagw_default_slot);
  ")
  
  [ -z "$PAGW_ENV" ] && { echo -e "\nDefault PAGW slot not present.\n" ; exit ${RET_PROJ_RECORDS_MISSING} ; }
  
  export PROJECT_NAME=$(mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"
  SELECT connection_group_name
  FROM pagw_default_slot,pagw_instances, guacamole_connection_group
  WHERE guacamole_connection_group.connection_group_id=pagw_instances.connection_group_id 
  AND pagw_instances.pagw_slots_id=pagw_default_slot.id;
  ")
  
  [ -z "$PROJECT_NAME" ] && { echo -e "\nDefault PAGW connection not found.\n" ; exit ${RET_PROJ_RECORDS_MISSING} ; }

  # Trimm any leading and trailing spaces and check if it's a valid non-FQDN hostname
  PROJECT_NAME=`echo ${PROJECT_NAME} | xargs`
  if [[ ! "$PROJECT_NAME" =~ ^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$ ]] 
  then
    echo -e '\nInvalid name for your default project. Use Guacamole portal to rename before re-running this script.\n' 
    exit ${RET_INVALID_PROJ_NAME} 
  fi

fi

# Create a reserve copy of the password as we don't wish it to be accidentally overriden by the next command.  
PRESERVED_PAGW_PASSWORD=${PAGW_PASSWORD}

# Export PAGW-slot variables needed for the rest of this script. 
eval "export $PAGW_ENV"

# The PAGW_PASSWORD should not be in the variable list above.
if [ "$PRESERVED_PAGW_PASSWORD" != "$PAGW_PASSWORD" ]
then

  echo -e '\nWARNING: Why do you have PAGW_PASSWORD stored as a part of the PAGW-slot in the database?!\n'
  PAGW_PASSWORD=${PRESERVED_PAGW_PASSWORD}

fi

if [ ! </dev/tcp/${PAGW_ADDRESS}/22 ] 
then

  echo -e "\nAnother host with the ${PAGW_ADDRESS} address is up and running.\n"

  [ "$1" == "--default" ] && exit ${RET_DUPLICATE_IP}
    
fi

# Prepare the ${PROJECT_TOOLBOX} 
mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"

START TRANSACTION;

SELECT connection_group_id 
INTO @project_roof_id
FROM guacamole_connection_group 
WHERE connection_group_name='${PROJECT_CONNECTION_GROUP}';

SELECT connection_group_id
INTO @project_cg_id
FROM guacamole_connection_group
WHERE parent_id = @project_roof_id
AND connection_group_name='${PROJECT_NAME}';

SELECT id
INTO @pagw_slot_id
FROM pagw_slots
WHERE ip = '${PAGW_ADDRESS}';
  
-- Create an empty resource subdirectory for storing BMS, VMs, links,...
INSERT INTO guacamole_connection_group(parent_id, connection_group_name) 
VALUES (@project_cg_id, '${PROJECT_RESOURCES}');

-- Create a project-toolbox subdirectory and save its ID
INSERT INTO guacamole_connection_group(parent_id, connection_group_name) 
VALUES (@project_cg_id, '${PROJECT_TOOLBOX}');
SELECT LAST_INSERT_ID()
INTO @toolbox_group_id;
  
-- Public IP is required by some toolbox entries
SELECT ip
INTO @pagw_address
FROM pagw_slots
WHERE id=@pagw_slot_id; 
  
-- Non-greedy regexp is used to extract PAGW_SSH_PRIVKEY= variable
SELECT REGEXP_SUBSTR(environment, 'PAGW_SSH_PRIVKEY="'"((.|\n)*?)"'"')
INTO @pagw_ssh_privkey
FROM pagw_slots
WHERE id=@pagw_slot_id; 
-- For toolbox, the actual value is needed 
SELECT TRIM(BOTH '\"' FROM REGEXP_SUBSTR(@pagw_ssh_privkey, '"'"((.|\n)*)"'"'))
INTO @pagw_ssh_privkey;
  
-- Add ARP-Scan toolbox entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('ARP Scan', @toolbox_group_id, 'ssh', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @arpscan_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@arpscan_id, 'hostname', @pagw_address),
(@arpscan_id, 'port', '22'),
(@arpscan_id, 'private-key', @pagw_ssh_privkey),
(@arpscan_id, 'username', 'arpscan');
  
-- Add Wireguard-VPN toolbox entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('Wireguard VPN', @toolbox_group_id, 'ssh',4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @wireguard_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@wireguard_id, 'hostname', @pagw_address),
(@wireguard_id, 'port', '22'),
(@wireguard_id,'private-key', @pagw_ssh_privkey),
(@wireguard_id,'username', 'wireguard');
  
-- Add PPTP-VPN toolbox entry
INSERT INTO guacamole_connection(connection_name, parent_id, protocol, proxy_port, proxy_hostname) 
VALUES ('PPTP VPN', @toolbox_group_id, 'ssh', 4822, 'guacd');
SELECT LAST_INSERT_ID()
INTO @pptp_id; 
INSERT INTO guacamole_connection_parameter(connection_id, parameter_name, parameter_value) VALUES 
(@pptp_id, 'hostname', @pagw_address),
(@pptp_id, 'port', '22'),
(@pptp_id,'private-key', @pagw_ssh_privkey),
(@pptp_id,'username', 'pptp');
  
-- SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Manually triggered rollback!';     

COMMIT;   
"

INSERT_STATUS=$? ; [ $INSERT_STATUS -ne 0 ] && { echo -e '\nUnable to create project-toolbox entries.\n' ; exit ${RET_PROJ_TOOLBOX_FAIL} ; }

SCRIPT_PATH=$(dirname $(realpath -s $0))
cd ${SCRIPT_PATH}

touch ssh_privkey
chmod 600 ssh_privkey
echo "$PAGW_SSH_PRIVKEY" > ssh_privkey

# SSH/SCP does not allow . as a path for security reasons
scp -o "StrictHostKeyChecking=no" -i ssh_privkey -r ${SCRIPT_PATH}/build ${PAGW_HOST_USER}@${PAGW_HOST}:${PAGW_HOST_HOME} 

# Check if 'sudo' or a similar prefix is needed
case ${PAGW_DEPLOY_DRIVER} in
    'proxmox-ve-ssh') SUDO='' ;;
    *)               SUDO='sudo' ;;
esac
ssh -o "StrictHostKeyChecking=no" -i ssh_privkey ${PAGW_HOST_USER}@${PAGW_HOST} "

source /etc/profile
cd /root/build/

${SUDO} docker run  --name pagw-builder       \
            -e PUBIP=${PAGW_ADDRESS}          \
            -e PUBMASK=${PAGW_MASK}           \
            -e PUBGW=${PAGW_GATEWAY}          \
            -e PAGW_HOSTNAME=${PROJECT_NAME}  \
            -e SUDO_PASSWORD=${PAGW_PASSWORD} \
            -e SSH_PUBKEY=\"${PAGW_SSH_PUBKEY}\"   \
            \$(docker build -q .)                          
${SUDO} docker cp pagw-builder:${PAGW_HOST_HOME}/pagw.img /tmp/         
${SUDO} docker container rm pagw-builder
${SUDO} mv ${PAGW_HOST_DOCKER_TMP}/pagw.img ${PAGW_HOST_HOME}/${PROJECT_NAME}.img
"

./deploy/${PAGW_DEPLOY_DRIVER}.sh

rm ssh_privkey

echo -e 'Done.\n'
echo -e 'Consider using a backup/snapshot scheme for your PAGW instance.\n'

[ "$1" == "--default" ] && touch ${SKIP_DEFAULT}

) 9>/var/lock/pagw-instances.lock
