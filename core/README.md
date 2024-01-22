### Core container overview

The Dockerfile and its entrypoint script work together to set up this container. The key distinction between the two lies in the type of data they store; the entrypoint script typically manages sensitive and frequently changing variables, which are not suitable for Docker's build cache.

The `./drivers` directory houses a number of the so-called _driver scripts_. These scripts are typically accessible from the outside world via Guacamole's SSH connections, and operators can also directly invoke them from within the running instance of this container.
