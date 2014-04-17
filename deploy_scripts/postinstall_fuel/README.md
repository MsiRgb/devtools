# Building a postinstall_fuel ISO

## Prerequisites

Clone this repo locally

    git clone https://github.com/MsiRgb/devtools.git

## Configure

###Edit the following files:

#####postinstall_fuel/deployment_name.yml (eg: ha_lab1.yml)

######Create a YAML file to pre-define your environment

    It is recommended to start by copying either aio.yml or sampleConfig.yml
    Note: Specify MAC addresses if and only if you do not want the script to 
          spawn VMs for each of the nodes. You will be responsible for booting
          the VMs once the Fuel server is up and running.

#####postinstall_fuel/postinstall

######Edit the bridges if necessary, note: Remember to tie them to your physical network if necessary

    create_bridge brpublic 192.168.124.5  255.255.255.0 eth0
    create_bridge br1      10.20.0.1      255.255.255.0 none
    create_bridge br2      172.16.0.1     255.255.255.0 none
    create_bridge br3      192.168.0.250  255.255.255.0 none

######Edit the execution line to add your yml file

    Update
        --config /var/tmp/postinstall/aio.yml
    To include your specific yaml file:
        --config /var/tmp/postinstall/deployment_name.yml
    (Note: You may also edit other command line args if necessary)

#####postinstall_fuel/kvm-server.seed

######Only update this file if you wish to change one of the following:

    Install disk:
        d-i     partman-auto/disk string /dev/sdd
    Root password:
        d-i     passwd/user-password-crypted    password $1$T5hO53XH$5FwiaGr.S1bik9U78vzqA.


## Build

###### Build the Fuel ISO first (following the directions in the parent directory's README.md)

See [README.md](https://github.com/MsiRgb/devtools/blob/master/BUILDING_MSIRGB_FUEL_ISO.md)

###### Extract a copy of Ubuntu 12.04 LTS to a temporary build directory

    mount -o loop ubuntu-12.04.4-server-amd64.iso /mnt
    rsync -av /mnt/ ~/aio_build_dir/
    umount /mnt

###### Run the AIO ISO build script to pull everything together

    Usage: ./build_aio_iso.sh <-o output_file> <-c crowbar/fuel iso> <-b build_directory> <-p postinstall_src_dir>
    *** Note: Please extract a copy of the Ubuntu12.04.4 disc to what will become the build_directory
        -o output_file - Location to write the output AIO ISO to
        -c crowbar/fuel iso - Location of the Crowbar ISO you built
        -b build_directory - Location of the extracted Ubuntu 12.04 LTS CD
        -p postinstall_src_dir - Location of your postinstall scripts (cloned with the devtools repo)

## Test

Insert the ISO generated from the build_aio_iso.sh script into a machine that will become the Fuel server.  After booting this machine, the following should happen:

1. Ubuntu 12.04 LTS will be installed with a custom preseed file
2. The postinstall scripts will be loaded to the target machine
3. The machine will boot up and execute the postinstall service, which will do the following:
    1. Create necessary bridge interfaces (tying your public networks to the Fuel server)
    2. Create the Fuel VM, insert your Fuel ISO and boot the machine
    3. Configure your Fuel environment
    4. Create VMs (or if configured with MAC addresses wait for hosts to check in)
    5. Apply roles to the unallocated Fuel nodes
    6. Optionally deploy the new OpenStack environment to the now-allocated Fuel nodes
