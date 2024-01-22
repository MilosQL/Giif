FROM guacamole/guacamole as schema

RUN /opt/guacamole/bin/initdb.sh --mysql > /home/guacamole/initdb.sql

FROM mariadb:lts

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y prips vim

# When a container is started for the first time, 
# it will execute files with extensions .sh, .sql, .sql.gz, 
# and .sql.xz that are found in /docker-entrypoint-initdb.d.
# Files will be executed in alphabetical order.
# SQL files will be imported by default to the database specified by the MYSQL_DATABASE variable.
# NOTE: .sh files without file execute permission are sourced rather than executed.

COPY --from=schema /home/guacamole/initdb.sql /docker-entrypoint-initdb.d/10-initdb.sql

COPY *.sh /docker-entrypoint-initdb.d/

COPY pagw-slots* /docker-entrypoint-initdb.d/ 

RUN chmod +x /docker-entrypoint-initdb.d/*.sh
