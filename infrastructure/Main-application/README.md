### Hosting the main application

The following are generic remarks on how to install the `main application`:

- The host running the `main application` is typically deployed as a virtual machine on a PAGW-host, which is often the most cost-effective approach.

- Similar to PAGW instances, this VM should be included in the periodic backup scheme. 

- In a production environment, it is advisable to opt for a modern, long-term supported (LTS) Linux distribution.

- The host should be equipped with two network interfaces: one for the public plane (Internet-accessible, with the default gateway configured) and the other for the control plane.

- Since the host is visible on Internet, utilities such as Fail2ban and Iptables are desirable.   

- Ensure that you have modern versions of Docker and Docker-Compose to run the main application, as described in the top-level `README.md`. It's preferable to install Docker using official Snapcraft or standard distro-package.

- The `main application` is typically maintained and delivered through Git.

- Allocate enough storage space on the host to accommodate the ISO library. This library is stored within the SAMBA container and accessed through the CIFS protocol.

Additional recommendations and notes:

- If your host is on a Proxmox VE or another QEMU-based hypervisor node, consider installing the `qemu-guest-agent` package for improved virtual machine management. 
