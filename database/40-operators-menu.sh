#!/bin/bash

# NOTE: ${MYSQL_DATABASE}, ${MYSQL_ROOT_PASSWORD}, ${CORE_USER} 
# and ${CORE_PASSWORD} variables are all fetched from 
# the runtime environment, as specified in the docker-compose.yaml  

mariadb --user=root --password="${MYSQL_ROOT_PASSWORD}" <<EOF

USE ${MYSQL_DATABASE};

INSERT INTO guacamole_connection (connection_id, connection_name, protocol, proxy_port, proxy_hostname) VALUES (1,'Operator\'s menu', 'ssh', 4822, 'guacd');
INSERT INTO guacamole_connection_parameter VALUES  
(1, 'command', 'operators-menu.sh'),
(1,'hostname', 'core'),
(1,'password', '${CORE_PASSWORD}'),
(1,'port', 22),
(1,'username', '${CORE_USER}');

INSERT INTO guacamole_connection_permission VALUES  
(1, 1, 'READ'),
(1, 1, 'UPDATE'),
(1, 1, 'DELETE'),
(1, 1, 'ADMINISTER');

EOF
