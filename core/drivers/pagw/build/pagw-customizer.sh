#!/bin/bash

if [ -z ${SUDO_PASSWORD} ] 
then 
    SUDO_PASSWORD="${SUDO_USER}:random"
else
    SUDO_PASSWORD="${SUDO_USER}:password:${SUDO_PASSWORD}"
fi

##################################################

PAGW_ON_GRUB2='99-pagw-settings.cfg'

cat << 'EOF' > ${PAGW_ON_GRUB2}

GRUB_TIMEOUT_STYLE=menu

GRUB_TIMEOUT=5
GRUB_RECORDFAIL_TIMEOUT=$GRUB_TIMEOUT

GRUB_CMDLINE_LINUX=$GRUB_CMDLINE_LINUX" net.ifnames=0 biosdevname=0 network-config=disabled"

EOF

##################################################

cat << EOF > interfaces
auto lo
iface lo inet loopback

auto gwovs
iface gwovs inet static
    address 192.168.212.1
    netmask 255.255.255.0

auto eth0
iface eth0 inet manual
    up ip link set dev eth0 up
    up ip link set eth0 promisc on

auto eth1
iface eth1 inet static
    address ${PUBIP}
    netmask ${PUBMASK}
    gateway ${PUBGW}
    up iptables -t nat -A POSTROUTING -o eth1 -j SNAT --to-source ${PUBIP}
    
EOF

echo -e '#!/bin/bash\n' > ovs-attacher.sh
echo -e '/usr/share/openvswitch/scripts/ovs-ctl start' >> ovs-attacher.sh
echo -e 'ovs-vsctl --no-wait add-br gwovs' >> ovs-attacher.sh
echo -e 'ovs-vsctl --no-wait add-port gwovs eth0' >> ovs-attacher.sh
for i in {2..30}
do  
    echo -e "auto eth$i" >> interfaces
    echo -e "iface eth$i inet manual" >> interfaces
    echo -e "    up ip link set dev eth$i up" >> interfaces
    echo -e "    up ip link set dev eth$i promisc on" >> interfaces
    echo -e "    up /bin/systemctl restart openvswitch-switch" >> interfaces
    echo -e "    down /bin/systemctl restart openvswitch-switch" >> interfaces
    echo -e " " >> interfaces
    echo -e "ovs-vsctl --no-wait add-port gwovs eth${i}" >> ovs-attacher.sh 
done

##################################################

cat << EOF > jail.local
[sshd]
   
enabled   = true
maxretry  = 6
findtime  = 1h
bantime   = 4h
ignoreip  = 127.0.0.1/8
EOF

##################################################

cat << EOF > dhcpd.conf
ddns-update-style none;
    option domain-name-servers 8.8.8.8;
    default-lease-time 600;
    max-lease-time 7200;
    log-facility local7;
    subnet 192.168.212.0 netmask 255.255.255.0 {
        range 192.168.212.20 192.168.212.120;
        option routers 192.168.212.1;
    }
EOF

##################################################

ARPSCAN_COMMAND_1='/usr/sbin/arp-scan -I gwovs --localnet'

cat << EOF > arpscan.sh
#!/bin/bash

clear
sudo ${ARPSCAN_COMMAND_1} | more
sleep 60
EOF

##################################################

cat << EOF > pptpd.conf
option /etc/ppp/pptpd-options
debug
logwtmp
connections 100
localip 192.168.212.2
remoteip 192.168.212.3-9
EOF

PPTP_COMMAND_1='/usr/bin/docker run -it --rm --network none -v /etc/ppp/chap-secrets\:/root/chap-secrets sensible-editor /root/chap-secrets'
PPTP_COMMAND_2='/bin/systemctl restart pptpd'
PPTP_COMMAND_3='/usr/bin/git --git-dir=/etc/ppp/.git --work-tree=/etc/ppp/ add chap-secrets'
PPTP_COMMAND_4='/usr/bin/git --git-dir=/etc/ppp/.git --work-tree=/etc/ppp/ commit --allow-empty -m Update'

cat << EOF > pptp.sh
#!/bin/bash

sudo ${PPTP_COMMAND_1}
sudo ${PPTP_COMMAND_2}
sudo ${PPTP_COMMAND_3}
sudo ${PPTP_COMMAND_4}
EOF

cat << 'EOF' > git-pptp.sh
#!/bin/bash

cd /etc/ppp/

git init

git config --local user.name "PPTP VPN" 
git config --local user.email system@pptp.vpn

git add chap-secrets
git commit -m "Initial commit on `date`"

echo '#!/bin/bash' > .git/hooks/commit-msg.sample
echo '' >> .git/hooks/commit-msg.sample
echo 'echo "Updated on `date`" > $1' >> .git/hooks/commit-msg.sample
mv .git/hooks/commit-msg.sample .git/hooks/commit-msg
EOF

cat << EOF > chap-secrets
# Secrets for authentication using CHAP
# client        server  secret                  IP addresses
# 
# john.wick     *       password5748            *    
# 
# Please check pppd(8) for quoting and escaping rules. 
# 
# The server's IP address is ${PUBIP}.
# On Linux clients, make sure to use point-to-point encryption (MPPE).
EOF

##################################################

cat << EOF > wg0.conf
#### Server-side configuration for wg-quick(8) ####

# Feel free to replace the server's private key with your own.
# Othrewise, the server's matching public key is:
# WG_PUBKEY

[Interface]
PrivateKey = WG_PRIVKEY
ListenPort = 51820
Address = 192.168.213.1/24

# VPN clients can be configured as shown in the examples below.
# Public keys should be replaced with the ones obtained from
# the users. IP addresses should be assigned from the 192.168.213.1/24
# subnet starting from 192.168.213.2 as 192.168.213.1 is reserved
# for the server itself. It's up to the people who edit this
# file to make sure that no address overlapping occurs.

#[Peer]
#PublicKey = /yrT564...lm1Ki9miRwdnUqx4=
#AllowedIPs = 192.168.213.2

#[Peer]
#PublicKey = /yKQl4w...y+m1Ki9miRwdnUqx4=
#AllowedIPs = 192.168.213.3

#[Peer]
#PublicKey = /yWert...y+m1Ki9m7iRwdnUqx4=
#AllowedIPs = 192.168.213.4

#[Peer]
# ...

#### Client-side configuration example for wg-quick(8) ####

# This part of the file serves as a reference
# guide and should remain under comment.

# To avoid static routing, the clients' subnet 
# prefix is /23 instead of /24.

# Each peer should get a different IP address.

#[Interface]
#PrivateKey = 0PVy/5RQKi...AIfh0Qs6eexH8=
#ListenPort = 21841
#Address = 192.168.213.2/23
#Table = off

#[Peer]
#PublicKey = WG_PUBKEY
#Endpoint = ${PUBIP}:51820
#AllowedIPs = 0.0.0.0/0

EOF

cat << EOF > wg-generator.sh
#!/bin/bash

wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey

chown -R root:root /etc/wireguard/
chmod -R 600 /etc/wireguard/

sed -i 's#WG_PRIVKEY#'\`cat /etc/wireguard/privatekey\`'#' /etc/wireguard/wg0.conf
sed -i 's#WG_PUBKEY#'\`cat /etc/wireguard/publickey\`'#' /etc/wireguard/wg0.conf

systemctl enable wg-quick@wg0
EOF

WG_COMMAND_1='/usr/bin/docker run -it --rm --network none -v /etc/wireguard/wg0.conf\:/root/wg0.conf sensible-editor /root/wg0.conf'
WG_COMMAND_2='/usr/bin/wg-quick down wg0'
WG_COMMAND_3='/usr/bin/wg-quick up wg0'
WG_COMMAND_4='/usr/bin/git --git-dir=/etc/wireguard/.git --work-tree=/etc/wireguard/ add wg0.conf'
WG_COMMAND_5='/usr/bin/git --git-dir=/etc/wireguard/.git --work-tree=/etc/wireguard/ commit --allow-empty -m Update'

cat << EOF > wg.sh
#!/bin/bash

sudo ${WG_COMMAND_1}
sudo ${WG_COMMAND_2}
sudo ${WG_COMMAND_3}
sudo ${WG_COMMAND_4}
sudo ${WG_COMMAND_5}
EOF

cat << 'EOF' > git-wireguard.sh
#!/bin/bash

cd /etc/wireguard/

git init

git config --local user.name "Wireguard VPN" 
git config --local user.email system@wireguard.vpn

git add wg0.conf
git commit -m "Initial commit on `date`"

echo '#!/bin/bash' > .git/hooks/commit-msg.sample
echo '' >> .git/hooks/commit-msg.sample
echo 'echo "Updated on `date`" > $1' >> .git/hooks/commit-msg.sample
mv .git/hooks/commit-msg.sample .git/hooks/commit-msg
EOF
  
##################################################

cat << EOF > rc.local
#!/bin/sh -e
        
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exit 0
EOF

##################################################

virt-customize --add pagw.img \
               --run-command "dpkg-reconfigure openssh-server" \
               --run-command "adduser --disabled-password --gecos '' ${SUDO_USER}" \
               --run-command "usermod -aG sudo ${SUDO_USER}" \
               --password "${SUDO_PASSWORD}" \
               --ssh-inject "${SUDO_USER}:string:${SSH_PUBKEY}" \
`##################################################` \
               --copy-in ${PAGW_ON_GRUB2}:/etc/default/grub.d/ \
               --run-command update-grub2 \
`##################################################` \
               --hostname ${PAGW_HOSTNAME} \
               --copy-in interfaces:/etc/network/ \
               --run-command "sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf" \
               --run-command "sed -i 's|#DNS=|DNS='${DNS1}'|' /etc/systemd/resolved.conf" \
               --run-command "sed -i 's|#FallbackDNS=|FallbackDNS='${DNS2}'|' /etc/systemd/resolved.conf" \
               --copy-in ovs-attacher.sh:/root/ \
               --run '/root/ovs-attacher.sh' \
               --delete '/root/ovs-attacher.sh' \
`##################################################` \
               --run-command 'systemctl enable fail2ban' \
               --copy-in jail.local:/etc/fail2ban/ \
`##################################################` \
               --copy-in dhcpd.conf:/etc/dhcp/ \
               --run-command 'sed -i "s/INTERFACESv4=\"\"/INTERFACESv4=\"gwovs\"/" /etc/default/isc-dhcp-server' \
`##################################################` \
               --run-command "adduser --shell /home/${ARPSCAN_USER}/arpscan.sh --disabled-password --gecos '' ${ARPSCAN_USER}" \
               --ssh-inject "${ARPSCAN_USER}:string:${SSH_PUBKEY}" \
               --copy-in arpscan.sh:/home/${ARPSCAN_USER} \
               --run-command "chown ${ARPSCAN_USER}:${ARPSCAN_USER} /home/${ARPSCAN_USER}/arpscan.sh" \
               --chmod 0544:/home/${ARPSCAN_USER}/arpscan.sh \
               --append-line '/etc/sudoers:' \
               --append-line "/etc/sudoers:${ARPSCAN_USER} ALL=(ALL) NOPASSWD:${ARPSCAN_COMMAND_1}" \
`##################################################` \
               --copy-in pptpd.conf:/etc/ \
               --chmod 0600:/etc/ppp/chap-secrets \
               --run-command "adduser --shell /home/${PPTP_USER}/pptp.sh --disabled-password --gecos '' ${PPTP_USER}" \
               --ssh-inject "${PPTP_USER}:string:${SSH_PUBKEY}" \
               --copy-in pptp.sh:/home/${PPTP_USER} \
               --run-command "chown ${PPTP_USER}:${PPTP_USER} /home/${PPTP_USER}/pptp.sh" \
               --chmod 0544:/home/${PPTP_USER}/pptp.sh \
               --append-line '/etc/sudoers:' \
               --append-line "/etc/sudoers:${PPTP_USER} ALL=(ALL) NOPASSWD:${PPTP_COMMAND_1}" \
               --append-line "/etc/sudoers:${PPTP_USER} ALL=(ALL) NOPASSWD:${PPTP_COMMAND_2}" \
               --append-line "/etc/sudoers:${PPTP_USER} ALL=(ALL) NOPASSWD:${PPTP_COMMAND_3}" \
               --append-line "/etc/sudoers:${PPTP_USER} ALL=(ALL) NOPASSWD:${PPTP_COMMAND_4}" \
               --copy-in chap-secrets:/etc/ppp/ \
               --copy-in git-pptp.sh:/root/ \
               --run '/root/git-pptp.sh' \
               --delete '/root/git-pptp.sh' \
`##################################################` \
               --copy-in wg0.conf:/etc/wireguard/ \
               --copy-in wg-generator.sh:/root \
               --run /root/wg-generator.sh \
               --delete /root/wg-generator.sh \
               --append-line '/etc/sysctl.conf:' \
               --append-line '/etc/sysctl.conf:#net.ipv4.conf.all.proxy_arp=1' \
               --run-command "adduser --shell /home/${WG_USER}/wg.sh --disabled-password --gecos '' ${WG_USER}" \
               --run-command "usermod -aG sudo ${SUDO_USER}" \
               --ssh-inject "${WG_USER}:string:${SSH_PUBKEY}" \
               --copy-in wg.sh:/home/${WG_USER} \
               --run-command "chown ${WG_USER}:${WG_USER} /home/${WG_USER}/wg.sh" \
               --chmod 0544:/home/${WG_USER}/wg.sh \
               --append-line '/etc/sudoers:' \
               --append-line "/etc/sudoers:${WG_USER} ALL=(ALL) NOPASSWD:${WG_COMMAND_1}" \
               --append-line "/etc/sudoers:${WG_USER} ALL=(ALL) NOPASSWD:${WG_COMMAND_2}" \
               --append-line "/etc/sudoers:${WG_USER} ALL=(ALL) NOPASSWD:${WG_COMMAND_3}" \
               --append-line "/etc/sudoers:${WG_USER} ALL=(ALL) NOPASSWD:${WG_COMMAND_4}" \
               --append-line "/etc/sudoers:${WG_USER} ALL=(ALL) NOPASSWD:${WG_COMMAND_5}" \
               --copy-in git-wireguard.sh:/root/ \
               --run '/root/git-wireguard.sh' \
               --delete '/root/git-wireguard.sh' \
`##################################################` \
               --copy-in rc.local:/etc/ \
               --chmod 0755:/etc/rc.local \
`##################################################` \
               --run-command 'systemctl disable cloud-init.service' \
               --run-command 'systemctl disable cloud-config.service' \
               --run-command 'systemctl disable cloud-final.service' \
               --run-command 'systemctl disable cloud-init-local.service' \
`##################################################` \
               --append-line '/etc/ssh/sshd_config:' \
               --append-line "/etc/ssh/sshd_config: # Allowing weaker algorithm because guacd" \
               --append-line "/etc/ssh/sshd_config: # in the official Dokcer image needs it" \
               --append-line '/etc/ssh/sshd_config:HostKeyAlgorithms +ssh-rsa' \
               --append-line '/etc/ssh/sshd_config:PubkeyAcceptedKeyTypes +ssh-rsa' 

# Note: The weak SSH algorithms should be removed once the libssh2 issue is resolved;
# this will most likely happen with the next release of the Docker image for Guacd. 
