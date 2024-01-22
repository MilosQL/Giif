### Building PAGW images

The explanations given here have no operational value. Instead, they aim at clarifying the inner workings of the PAGW build routine. 

For instance, when called from this directory, the example sequence below results in a creation of a fully parametrized PAGW image: 

```
docker run -it --name pagw-builder  \
           -e PUBIP=192.168.122.200 \
           -e PUBMASK=255.255.255.0 \
           -e PUBGW=192.168.122.1   \
           -e PAGW_HOSTNAME=MyProject-PAGW \
           -e SUDO_PASSWORD=''      \
           -e SSH_PUBKEY='ssh-rsa AAAA.... user@localhost' \
    $(docker build -q .)

docker cp pagw-builder:/root/pagw.img /tmp/

docker container rm pagw-builder
```

A similar sequence can be observed in the `../build-and-deploy.sh` script. If `SUDO_PASSWORD` is left empty or unset, the system will resort to a random-password generation.

The resulting image is already fully parametrized and does not depend on the cloud-init or similar for further customizations. The base for it is pulled from the official [Ubuntu Cloud](https://cloud-images.ubuntu.com/) repository and is adjusted through the means of `libguestfs` and, in particualr, a tool called `virt-customze`.  

Docker also plays a significant part in this build process:

- It provides a build environment. This practically means you don't need to go through any pain of installing `libguestfs` and `virt-customize` yourself.
- Build-cache makes sure that any subsequent builds are blazingly fast. The base image and additional `.deb` packages are kept in this way, so do not clear the cache unless you really have to.
- Dockerfile is the ultimate document describing the whole build process, step by step.   

The `pagw-customize.sh` script is used for project-specific and sensitive data that should not be kept in the build-cache. It can also be used for paramters that can vary in time and between different PAGW instances.
