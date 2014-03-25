# Deploy scripts.
This repository houses a set of files required for building the AIO ISO.

## To use:
- git clone https://github.com/MsiRgb/devtools
- cd devtools/deploy_scripts

## To build the underlying Crowbar ISO:
First, follow the steps laid out at https://github.com/crowbar/crowbar/wiki/Build-Crowbar.ISO to build the crowbar ISO. The only exceptions to that process are to clone the crowbar project from githug.com/MsiRgb/crowbar repo and you don't need, necessarily, to build sledgehammer separately.

##For the custom RGB ISO:
The relevant pieces of syslinux.cfg needs to be updated to point to the media type file used (e.g., in the case of ISO – isolinux.cfg).

The kvm-server.seed file should go in the preseed directory and the kernel line in:
- The isolinux.cfg (for an ISO)
- syslinux.cfg (for <4GB USB)
- extlinux.cfg (for >4GB USB)

Further, the config file should point to the kvm-server.seed file.

Create a directory in the root of the media called postinstall and place the following items from the devtools/deploy_scripts repo:
- crowbar ISO – make sure that the CROWBAR_ISO variable in the postinstall-noha-stage2.sh file points to the correct name of the ISO
- preseed-late.sh
- postinstall
- postinstall-noha-stage1.sh
- postinstall-noha-stage2.sh
- postinstall-noha-stage3.sh

