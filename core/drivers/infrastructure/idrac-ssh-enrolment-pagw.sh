#!/bin/bash

# This script is executed in the context of the main enrolment routine!

# Fecth the environment from the default PAGW slot 
PAGW_ENV=$(mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"
SELECT CONCAT('PAGW_ADDRESS=',ip), environment
FROM pagw_slots
WHERE id IN (SELECT id FROM pagw_default_slot);
")
  
[ -z "$PAGW_ENV" ] && { echo -e "\nDefault PAGW slot not present.\n" ; exit ${RET_iDRAC_PAGW} ; }

# Extract PAGW-slot variables needed for the rest of this script. 
eval "$PAGW_ENV"

PROJECT_NAME=$(mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"
SELECT connection_group_name
FROM pagw_default_slot,pagw_instances, guacamole_connection_group
WHERE guacamole_connection_group.connection_group_id=pagw_instances.connection_group_id 
AND pagw_instances.pagw_slots_id=pagw_default_slot.id;
")
  
[ -z "$PROJECT_NAME" ] && { echo -e "\nDefault PAGW connection not found.\n" ; exit ${RET_iDRAC_PAGW} ; }

# Fetch the base name of this (sourced!) script and invoke the driver 
. `basename ${BASH_SOURCE[0]} .sh`-${PAGW_DEPLOY_DRIVER}".sh"
