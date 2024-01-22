### Proxmox VE installation and configuration steps

Here are some important points to keep in mind when using Proxmox VE as the resource-host for your setup:

- It is highly recommended to familiarize yourself with the [platform](https://www.proxmox.com/en/proxmox-ve) before proceeding with any of the installation and configuration steps provided here.

- The focus of this guide is on the single-node installations. Cluster and HA setups are left for future exploration.

- Each server should get a unique hostname. 

  `Note:` These names are of local significance only and there's no need to publish them through DNS.

- Make sure to set `maxroot` parameter to at least 200 GB. This may come in handy for hosting a local ISO image repository. If you notice that the size of your root partition does not actually meet your installation input, try applying the following corrections:

    ```
    lvextend -l+100%FREE /dev/pve/root
    resize2fs /dev/pve/root
    ```

- The `swapsize` parameter can be left empty and the installation-wizard will choose the best value for you.

- Proxmox VE utilizes LVM-thin as the default storage for its hosted VMs. Therefore, it's advisable to allocate some space for snapshots using the `minfree` installation parameter.

- You can configure non-standard storage setups for individual PAGW-slots, like using the root partition for VMs or creating additional LVM pools. 

  `Note:` If ever introduced, the prospective VM reservation drivers should be made aware of different storage pools available to them.

- The installation wizard will also prompt you to select the default network interface, which corresponds to your control-plane port. It's important to note that the wizard does not support VLAN tagging on the default interface.

- In addition to the control plane connectivity, the server is expected to have the project-management and optional data-plane VLANs enabled aginst one or more of its network interfaces. These, however, must be configured from the web UI. 

  `Note:` Prospective VM reservation drivers should be informed about the mapping between VLANs and their corresponding software bridges.

- It's highly recommended to disable swappiness by setting:

    ```
    vm.swappiness = 0
    ```
  in `/etc/sysctl.d/local.conf`.

- If the installation wizard does not let you choose UTC as the desired timezone, you can change this later through CLI:

    ```sh
    dpkg-reconfigure tzdata 
    ```

- Install the `at` utility which is required by some Core drivers:

  ```
  apt-get update
  apt-get -y install at 
  ``` 
- Reboot the system for the changes to take effect. Make sure desired changes have persisted.

Additional notes and recommendations:

- To support your backup schemes, it's recommended to introduce at least two external storage systems (e.g., NFS shares). One of these could be used for automatically scheduled backups, where end-users have no control over the process. The other system can be utilized to offer end-users an on-demand backup capability, although it would not include the ability to restore them. In each case, the responsibility for the backup restoration remains with the operator. The current dashboard driver for the latter expects a default `vzdump` configuration to be set in the `/etc/vzdump.conf` file. Each external storage should be configured with its own retention options, which Proxmox VE normally stores in `/etc/pve/storage.cfg`. For instance, the `/etc/vzdump.conf` may look something like this:

  ```
  storage: nfs-on-my-storage
  mode: snapshot
  remove: 0
  compress: zstd
  zstd: 1
  bwlimit: 100000
  ```

  while the corresponding storage entry in `/etc/pve/storage.cfg` could be similar to this:

  ``` 
  nfs: nfs-on-my-storage
        export /srv/nfs/my-vm-hostname
        path /mnt/pve/nfs-on-my-storage
        server 10.20.30.20
        content backup
        prune-backups keep-last=2
  ```
  
  Check the relevant Proxmox VE `man` pages and the framework driver notes for more details.

  `Note:` Backup and snapshot drivers should only be accessible to users we trust not to misuse them or to projects that exclusively own a VM host. It's worth noting that the concept of external quota systems may not be enough to resolve this issue.

- While PAGW hosts can also function as VM hosts, it's advisable to avoid dual-purpose nodes unless server resources are limited.

- Prospective VM reservation drivers may need a method of authentication when accessing the Proxmox VE node, such as using SSH keys or API credentials.
