### Deployment of PAGW images

These scripts are almost never invoked directly by the operator. They are an essential part of the `../build_and_deploy.sh` routine.

Their goal is to create a running VM from the previously built PAGW image.

The environment variables expected by them are described within each script. These documentational comments can help the operator prepare the desired set of PAGW slots. 

The `PAGW_DEPLOY_DRIVER` variable expected by each PAGW slot corresponds to the name of the script, just without the `.sh` extension. For instance, the slot with the `PAGW_DEPLOY_DRIVER`=`promox-ve-ssh` parameter will taget the `promox-ve-ssh.sh` script.
