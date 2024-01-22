### Driver-scripts

Guacamole entries representing these scripts should target the `Core` container as the destination host using the SSH credentials specified in the top-level `.env` file. The `Execute commmand` field should state the desired script with an appropriate set of arguments. Guacamole's user permissions for these SSH connections must also be set appropriately.

It's important to mention that not all driver-scripts are meant for end-users. Some of them function as "DRY" (Don't Repeat Yourself) subroutines, while others should only be accessible to system operators (i.e., `guacadmin` account).

If you're uncertain about which scripts to make accessible to end-users through Guacamole, a helpful starting point is to examine those with the shortest names. These short-named scripts often act as top-level menus, serving as gateways to the rest. For instance, `idrac-ssh.sh` functions as a starting menu, providing access to all other `idrac-ssh-*.sh` scripts.
