# Deploy scripts.
This repository houses a set of files required for building the AIO ISO.

## To use:
1. git clone https://github.com/MsiRgb/devtools
2. cd devtools/deploy_scripts

## To build the underlying Crowbar ISO:
Fix a few things on your machine first:

1. apt-get remove python-pip;
2. wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py;
3. sudo python get-pip.py;
4. sudo apt-get install cabextract;
5. sudo apt-get install libxml-ruby.


Continue with the official ISO build instructions for the 1.x roxy/openstack-os-build release:
  http://crowbar.github.io/docs/build-crowbar.html

##For the custom RGB ISO:
1. Clone the msirgb devtools repo:

  git clone https://github.com/MsiRgb/devtools.git

2. Extract the ubuntu 12.04 LTS cd to a directory (this will be your build_dir)

  mount -o loop /dev/cdrom /mnt  
  rsync -av /mnt/ ~/build_dir/

3. Run the build script with the appropriate parameters:

  Usage: ./build_aio_iso.sh <-o output_file> <-c crowbar/fuel iso> <-b build_directory> <-p postinstall_src_dir>  
  *** Note: Please extract a copy of the Ubuntu12.04.4 disc to what will become the build_directory  
   -o output_file          - Location to write the output AIO ISO to  
   -c crowbar/fuel iso     - Location of the Crowbar ISO you built  
   -b build_directory      - Location of the extracted Ubuntu 12.04 LTS CD  
   -p postinstall_src_dir  - Location of your postinstall scripts (cloned with the devtools repo)


4. Boot your target AIO machine from the ISO and the following will happen:
  * Ubuntu 12.04 LTS will be installed with a custom preseed file;
  * The postinstall scripts will be loaded to the target machine;
  * The machine will boot up and execute the postinstall service, which will in trun execute stages 1-3;
  * Stage 1 will configure the KVM services and dependencies;
  * Stage 2 will build build a Crowbar admin node on a KVM-provisioned VM;
  * Stage 3 will build out 10 VMs and configure Crowbar to map proposals across them to build an Openstack system.


