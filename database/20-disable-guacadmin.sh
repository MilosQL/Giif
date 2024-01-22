#!/bin/bash

# NOTE: ${MYSQL_DATABASE}, ${MYSQL_ROOT_PASSWORD} and ${MYSQL_GUACADMIN_PASSWORD} 
# variables are fetched from the runtime environment, as set in docker-compose.yaml  

mariadb --user=root --password="${MYSQL_ROOT_PASSWORD}" <<EOF

USE ${MYSQL_DATABASE};
UPDATE guacamole_user SET disabled=1 WHERE entity_id=1;
SET @salt = UNHEX(SHA2(UUID(), 256));
UPDATE guacamole_user SET password_salt=@salt,password_hash=UNHEX(SHA2(CONCAT('${MYSQL_GUACADMIN_PASSWORD}', HEX(@salt)), 256)) WHERE entity_id=1;
EOF
