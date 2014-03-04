# Scripts for Docker container images
This repository houses a set of utilities for creating containers used for developing Crowbar and OpenStack.

The scripts create containers and take the general form (by way of example):

    ./crowbar.sh build

That would create a docker container. At the present time (and this will be the first issue noted), the containers all build to the tdhite account at index.docker.io as that is what is hard coded into the CONTAINER_USER variable in the scripts. Therefore, to actually create a container at present you must have login rights to the tdhite account. This will be fixed in the near future.

## To use:
- git clone https://github.com/MsiRgb/devtools
- cd devtools/docker
- Run the script if interest.

### crowbar.sh
The crowbar.sh script builds a crowbar development container image. It does not pull code, nor expect to do so. Instead, it expects the user to mount a volume to /mnt/crowbar that houses the crowbar git repositories.

For an example command to run the resulting container:

    docker run -p=2222:22 -v /mnt/crowbar:/mnt/crowbar -d tdhite/crowbar

That would start a container with SSH access with user crowbar, password changeme (as coded in the crowbar-functions.sh script). The crowbar repository would exist at /mnt/crowbar in the container. Further, the container links the crowbar user's ~/.crowbar-build-cache to /mnt/crowbar/.crowbar-build-cache so no build information is lost over time. Obviously that means the crowbar repository directory should look like:

    /mnt/crowbar
    --|
    --|.crowbar-build-cache
    --|--|
    --|--|--iso
    --|crowbar

Where the last 'crowbar' listed directory is the git clone of https://github.com:MsiRgb/crowbar and all directories thereafter setup by the dev setup tool.
