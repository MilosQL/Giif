#!/bin/bash

# NOTE: ${MYSQL_DATABASE}, ${MYSQL_ROOT_PASSWORD} and ${PROJECT_CONNECTION_GROUP}
# variables are fetched from the runtime environment, as set in docker-compose.yaml  

mariadb --user=root --password="${MYSQL_ROOT_PASSWORD}" <<EOF 

USE ${MYSQL_DATABASE}; 

CREATE TABLE pagw_slots (
    id INT NOT NULL AUTO_INCREMENT,
    ip VARCHAR(15) NOT NULL COMMENT 'Public IPv4 address' ,
    ignored BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Can be used as a filter for manual scheduling policies',
    environment VARCHAR(5000) NOT NULL COMMENT 'A list of VAR=VAL settings used for build_and_deploy.sh',
    PRIMARY KEY (id)
);

CREATE TABLE pagw_instances (
    pagw_slots_id INT UNIQUE NOT NULL,
    connection_group_id INT UNIQUE NOT NULL,

    PRIMARY KEY (pagw_slots_id, connection_group_id),

    -- RESTRICT prevents accidental loss of environment settings
    FOREIGN KEY(pagw_slots_id) REFERENCES pagw_slots(id) ON DELETE RESTRICT ON UPDATE RESTRICT,

    -- CASCADE is chosen in order for Guacamole to be able to remove a connection group
    FOREIGN KEY(connection_group_id) REFERENCES guacamole_connection_group(connection_group_id) ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE TABLE pagw_default_slot (
   id int PRIMARY KEY REFERENCES pagw_slots(id) ON DELETE RESTRICT ON UPDATE RESTRICT,

   -- This column is needed in order to achieve the single-row (singleton) effect in MariaDB  
   dummy_column ENUM('This_table_is_a_singleton') NOT NULL DEFAULT 'This_table_is_a_singleton'
);
-- The index will prevent more than one row in the above table
CREATE UNIQUE INDEX force_singleton ON pagw_default_slot (dummy_column);


-- The pagw_default_slot(dummy_column) is not needed in newer versions of PostrgeSQL and MySQL
-- as functional indexes can be used to achieve the desired singleton effect:
-- CREATE UNIQUE INDEX force_singleton ON pagw_default_slot ((true));

INSERT INTO guacamole_connection_group(connection_group_name) VALUES('${PROJECT_CONNECTION_GROUP}');

EOF

# Developer's note: The tables above should not be directly accessed nor modified
# from any routine other than Core's driver-scripts. Also, Core driver-scripts
# should practice strict flock(1)-ing discipline on /var/lock/pagw-instances.lock
# file when messing with these tables.
#
# The PROJECT_NAME variable is not known until runtime (the project owner
# needs to come up with  the name) and is stored separately, in the 
# "guacamole_connection_group" table. The associative table called
# "pagw_instances" glues together "pagw_slots" and "guacamole_connection_group"
# to represent any currently active projects and their running PAGW instances.
#
# The "pagw_default_slot" table is a singleton pointer for the "default" project.  
 
#
# Next we load the actual PAGW slots. The first slot to be encountered
# during this record loading will be reserved for the "default" project.
#
SCRIPT_PATH=$(dirname $(realpath -s $0))
SLOTS=${SCRIPT_PATH}'/pagw-slots'
test -f ${SLOTS} && source ${SLOTS}
