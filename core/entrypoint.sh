#!/bin/bash

. /etc/profile

# Note: Many of the variables referenced here are sensitive
# and thus not available from the Dockerfile during the build
# of the image.  

echo -e "${CORE_PASSWORD}\n${CORE_PASSWORD}" | passwd ${CORE_USER}

# Wait for databse to come online (ugly but does the job)
sleep 15

# Trigger PAGW spawn for the so-called default project (only on first invocation)
build_and_deploy.sh --default 1>>/root/build_and_deploy--default.log 2>&1

# Runtime .env needed by sshd
printenv | fgrep SAMBA > /home/${CORE_USER}/.ssh/environment
printenv | fgrep PRIVATE_IP >> /home/${CORE_USER}/.ssh/environment
printenv | fgrep CORE_USER >> /home/${CORE_USER}/.ssh/environment

# sshd re-exec requires execution with an absolute path!
/usr/sbin/sshd -D
