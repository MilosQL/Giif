### CIFS share

Here are some important points to keep in mind when using the shares hosted on the SAMBA container:

- The shared directories are preserved as Docker volumes.

- The `SAMBA_PASSWORD` environment variable contains the common password used for all available CIFS shares provided by this container. The corresponding username, however, varies depending on the context. 

- The operator should place their set of selected ISO images under the `/home/iso/` directory within the running instance of this container. The naming and exposure rules are listed in the `README` file along the same path. The corresponding user for this type of share is `iso`.

  `Note:` Proxmox VE requires the user named `proxmox` to attach an ISO share to a node, rather than the default `iso` user. This is because Proxmox VE insists on its own directory structure. Check the `Dockerfile` for additional explanations.

- When adding a new iDRAC based BMS node to the setup, make sure to export its Lifecycle XMLs under `/home/idrac/xml/`. The easiest way to accomplish this is through the appropriate `racadm` export command, which requires the `idrac` user. Check the corresponding `core` drivers for more details.
 
