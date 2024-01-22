### Proxmox VE installation and configuration steps

Here are some important points to keep in mind when using Proxmox VE as the PAGW-host for your setup:

- It is highly recommended to familiarize yourself with the [platform](https://www.proxmox.com/en/proxmox-ve) before proceeding with any of the installation and configuration steps provided here.

- The focus of this guide is on the single-node installations. Cluster and HA setups are left for future exploration.

- For this type of host, you should specify `PAGW_DEPLOY_DRIVER='proxmox-ve-ssh'` in your PAGW-slot definitions.  

- Make sure to set `maxroot` parameter to at least 200 GB. This is mainly needed for the Docker build cache and resulting .qcow2 images but can also prove useful for other purposes, such as maintaining a local ISO image repository. If you notice that the size of the root partition does not actually meet your installation-wizard input, try applying the following corrections:

    ```
    lvextend -l+100%FREE /dev/pve/root
    resize2fs /dev/pve/root
    ```

- The `swapsize` parameter can be left empty and the installation-wizard will choose the best value for you.

- Proxmox VE utilizes LVM-thin as the default storage for its hosted VMs. Therefore, it's advisable to allocate some space for snapshots using the `minfree` installation parameter. 

- You can configure non-standard storage setups for individual PAGW-slots, like using the root partition for VMs or creating additional LVM pools. For example, you can set something like `PAGW_STORAGE_POOL='my-storage'` to specify the storage pool for a given slot. 

- The installation wizard will also prompt you for the default network interface. This corresponds to your control-plane port. The wizard does not support VLAN tagging on the default interface.

- The remaining network planes (public, project-management segments, and BMS connectivity) require configuration through the web UI and cannot be set up via the installation wizard. You can use the same or different physical ports, with or without VLAN tagging, as long as PAGW-slots (in particular, variables `PAGW_HOST_MGMT_BRIDGE`, `PAGW_MGMT_VLAN`, `PAGW_HOST_PUB_BRIDGE`, and `PAGW_PUB_VLAN`) correctly reflect on your network setup.  

  `Note:` The `PAGW_HOST_MGMT_BRIDGE` is used for both project management and BMS connectivity VLANs.

- It's highly recommended to disable swappiness by setting:

    ```
    vm.swappiness = 0

    ```

    in `/etc/sysctl.d/local.conf`.

- If the installation wizard does not let you choose UTC as the desired timezone, you can change this later through CLI:

    ```sh
    dpkg-reconfigure tzdata 
    ```

- The recommended method for Docker installation is via Snapcraft. Prior to running the following command, please enable [Snapcraft on Debian](https://snapcraft.io/docs/installing-snap-on-debian):

    ```sh
    snap install docker
    ```

   The PAGW-slot variable `PAGW_HOST_DOCKER_TMP` should be set to `/tmp/snap.docker/tmp`. 

   `Note:` Standard `.deb` installations of Docker are also possible; in this case the `PAGW_HOST_DOCKER_TMP` variable should be set to `/tmp` directory. 

- Install your public SSH key from the PAGW slots to the `${PAGW_HOST_HOME}/.ssh/authorized_keys`. 

- Reboot the system for the changes to take effect. Make sure desired changes have persisted.

Additional notes and recommendations:

- For reliable backups, include external storage like NFS or CIFS.  

- The server can also host the `main application` and helper services, like the public-to-control plane VPN.
