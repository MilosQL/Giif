#!/bin/bash

# 
# The only input expected is the ${PROJECT_NAME} env. variable.
#
# The script enforces exclusive locking. The return codes
# are as follows:
# 
# RET_SUCCESS - successful execution
# RET_EXCL_LOCK - exclusive locking is in place, try again later
# RET_PROJ_NAME_404 - ${PROJECT_NAME} not present in DB
# RET_PAGW_ZOMBIE - PAGW instance has not been successfully removed
# RET_ABORTED - aborted on operator's request 
# RET_DB_TXN_FAIL - delete transaction failed 

RET_SUCCESS=0
RET_EXCL_LOCK=1
RET_PROJ_NAME_MISSING=2
RET_PAGW_ZOMBIE=3
RET_ABORTED=4
RET_DB_TXN_FAIL=5

# The script tries to remove the PAGW infrastructure 
# before deleting the relevant database records. If the
# removal is unsuccessful (i.e. PAGW still responding to
# network probing), the script will not proceed with
# the record deletion. The operator can also abort
# the script prior to record deletion if he observes
# the PAGW removal is incomplete in some way. The goal
# of this is to prevent zombie PAGW instances.
# 

(
    flock -nx 9 || { 

        echo -e "\nThe PAGW slots in database have been locked by another execution thread... Please try later.\n" ;
        echo -e "If the problem persists, contact your support.\n" ;
     
        exit ${RET_EXCL_LOCK} 
    }

# Trimm any leading and trailing spaces and check if it's a valid non-FQDN hostname 
PROJECT_NAME=`echo ${PROJECT_NAME} | xargs`

PAGW_ENV=$(mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"

SELECT connection_group_id 
INTO @project_roof_id 
FROM guacamole_connection_group 
WHERE connection_group_name='${PROJECT_CONNECTION_GROUP}';

SELECT CONCAT('PAGW_ADDRESS=',ip), environment
FROM pagw_slots, pagw_instances, guacamole_connection_group
WHERE guacamole_connection_group.connection_group_name='${PROJECT_NAME}'
AND guacamole_connection_group.parent_id=@project_roof_id
AND guacamole_connection_group.connection_group_id=pagw_instances.connection_group_id
AND pagw_instances.pagw_slots_id=pagw_slots.id;
")

[ -z "$PAGW_ENV" ] && { echo 'Project name not found.' ; exit ${RET_PROJ_NAME_MISSING} ; }

eval "export $PAGW_ENV"

SCRIPT_PATH=$(dirname $(realpath -s $0))
cd ${SCRIPT_PATH}

touch ssh_privkey
chmod 600 ssh_privkey
echo "$PAGW_SSH_PRIVKEY" > ssh_privkey

./undeploy/${PAGW_DEPLOY_DRIVER}.sh

rm ssh_privkey

</dev/tcp/${PAGW_ADDRESS}/22 && { echo -e '\nPAGW still responding.\n' ; exit ${RET_PAGW_ZOMBIE} ; }

# Give the operator a chance to abort the database cleanup
echo -e "\nPlease verify the PAGW instance has been successfully removed.\n"
TIMEOUT=15
echo -e "To abort the database cleanup, press any key in the following ${TIMEOUT} seconds.\n"
IFS=
if read -r -s -n 1 -t ${TIMEOUT} key
then
    echo -e 'Input detected. No database records have been deleted. Exiting...\n'
    exit ${RET_ABORTED}
fi

echo -e 'Proceeding with the database record removal...\n'

mariadb --raw --skip-column-names -hdatabase -u${MYSQL_USER} -D${MYSQL_DATABASE} -p${MYSQL_PASSWORD} -e"
START TRANSACTION;

SELECT connection_group_id
INTO @project_roof_id
FROM guacamole_connection_group
WHERE connection_group_name='${PROJECT_CONNECTION_GROUP}';

DELETE FROM pagw_instances 
WHERE connection_group_id in (SELECT connection_group_id 
                              FROM guacamole_connection_group 
			      WHERE connection_group_name='${PROJECT_NAME}'
			      AND parent_id=@project_roof_id);

DELETE FROM guacamole_connection_group 
WHERE connection_group_name='${PROJECT_NAME}';

COMMIT;
"

DELETE_STATUS=$? ; [ $DELETE_STATUS -ne 0 ] && { echo 'Unable to delete database entries.' ; exit ${RET_DB_TXN_FAIL} ; }

echo -e '\nDone.\n'

) 9>/var/lock/pagw-instances.lock

