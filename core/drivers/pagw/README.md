# PAGW provisioning cycle

There are two high-level scripts intended for the provisioning of PAGW instances and the maintenance of their corresponding database records:

- `build_and_deploy.sh` 
- `undeploy_and_clear.sh`

The purpose of these scripts is somewhat self-explanatory based on their names. A brief overview of their inner workings is provided in the following two subsections.

## Build and Deploy

One of the initial actions performed by the `build_and_deploy.sh` script is to locate an available PAGW slot in the database. The PAGW slot contains the majority of the configuration parameters required for successful PAGW instantiation. However, there are a couple of runtime parameters that cannot be pre-stored in the database. Instead, these must be provided in the form of environment variables:

- `PROJECT_NAME` 
- `PAGW_PASSWORD`

Additional information about these two variables can be located within the script's documentation comments.

Next, the script uses SSH/SCP to transfer the entire content of this directory to the targeted PAGW-host and then executes the build and deployment commands from there. 

The build process requires Docker installation to be present on the PAGW-host. The end result of the build process is a fully customized `.img` file stored directly under the `PAGW_HOST_HOME` directory of the targeted PAGW-host. 

`Note:` The Docker is only used for a brief amount of time to produce the desired QCOW2+ image, without actually running any long-lasting containers. For more insight into this part of the process, feel free to explore the contents of the `build/` directory.

The deployment part of the script takes the `.img` file and uses it to spawn the desired PAGW VM. The details vary depending on the type of PAGW-host and its deployment driver. In most cases, the original `.img` file will be removed from the `PAGW_HOST_HOME` directory once the VM is up and running.

The `build_and_deploy.sh` script gets the following variables from the database:

- `PAGW_HOST`    - target host for the PAGW instance
- `PAGW_HOST_USER` - SSH/SCP user on the PAGW-host 
- `PAGW_HOST_HOME` - target directory for the user mentioned above, typically their home directory
- `PAGW_HOST_DOCKER_TMP` - set to `/tmp` for non-Snpacraft installation of Docker, `/tmp/snap.docker/tmp` otherwise
- `PAGW_SSH_PRIVKEY`  - the same private key is used for both PAGW-host and its PAGW instances
- `PAGW_SSH_PUBKEY`   - corresponding public SSH key
- `PAGW_ADDRESS` - unique PAGW address from the `public plane` subnet
- `PAGW_MASK`    - corresponding subnet mask in dot-decimal notation
- `PAGW_GATEWAY` - corresponding gateway address
- `PAGW_DEPLOY_DRIVER` - type of deployment driver (e.g., `proxmox-ve-ssh`)

`Note:` The `PAGW_DEPLOY_DRIVER` value corresponds to the name of the script stored in the `deploy/` directory. Some variables are specific to the particular deployment drivers; these are described separately.

The `PROJECT_NAME` is determined in runtime and must be passed to the script as an environment variable.  

If successfull, the execution results in a fully customized, connected and running PAGW instance for the newly created project. The operator should verify the instance is working correctly before delegating the project to its owner. Additionaly, the operator should include the instance into one or more periodic backups scheduled on that PAGW-host.

`Developer's note:` Each new `PAGW_DEPLOY_DRIVER` typically requires additional comments in `database/pagw-slots.example` file.

## Undeploy and Clear

The script takes the `PROJECT_NAME` in the form of a environment variable and removes the PAGW instance and its database records. Its implementation follows a similar structure as the `build_and_deploy.sh` script. 

`Notes:` This script does not move its current resources to the default or any other project; it's up to the operator to perform this task manually **before** running it. If the target is the default project itself, this script will also clear the `pagw_default_slot` table.
