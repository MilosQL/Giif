FROM ubuntu:22.04

ARG CORE_USER 
ENV CORE_USER=${CORE_USER:-core} 

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get -y install vim openssh-server sshpass traceroute nmap iputils-ping \
                       telnet netcat mariadb-client smbclient xmlstarlet gridsite-clients && \
    useradd -m -s /bin/bash ${CORE_USER} && \
    mkdir -p /var/run/sshd && \
    sed -i 's/#PermitUserEnvironment no/PermitUserEnvironment yes/' /etc/ssh/sshd_config && \
    echo '' >> /etc/ssh/sshd_config && \
    echo '# Allowing weaker algorithm because guacd' >> /etc/ssh/sshd_config && \
    echo '# in the official Dokcer image needs it' >> /etc/ssh/sshd_config && \
    echo 'HostKeyAlgorithms +ssh-rsa' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAcceptedKeyTypes +ssh-rsa' >> /etc/ssh/sshd_config && \
    mkdir /home/${CORE_USER}/.ssh

COPY --chown=${CORE_USER}:${CORE_USER} drivers/ /usr/local/bin

ENV NEW_PATHS='/usr/local/bin/pagw:/usr/local/bin/dashboard:/usr/local/bin/infrastructure'

RUN chmod 700 /usr/local/bin/*/*.sh && \
    echo 'PATH=$PATH:'${NEW_PATHS} > /etc/profile.d/99-extended-path.sh && \
    echo '. /etc/profile' >> /root/.bashrc && \
    sed -e 's|PATH="\(.*\)"|PATH="'${NEW_PATHS}':\1"|g' -i /etc/environment

COPY entrypoint.sh .

EXPOSE 22/tcp

ENTRYPOINT ["./entrypoint.sh"]
