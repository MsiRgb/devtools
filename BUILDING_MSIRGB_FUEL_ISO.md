These steps will build the MsiRgb custom Fuel ISO that will prevent users from
creating a new environment on the Fuel web interface.

1. Note: This should be done on an Ubuntu 13.10 development machine

2. Clone official Fuel ISO

        cd
        git clone https://github.com/stackforge/fuel-main.git
        cd ~/fuel-main

3. Switch to 4.1 stable branch

        git checkout stable/4.1

4. Edit configuration to reference MsiRgb repo for custom fuel-web

        vi ./config.mk
           Change  NAILGUN_REPO?=https://github.com/stackforge/fuel-web.git
           To      NAILGUN_REPO?=https://github.com/MsiRgb/fuel-web.git
           Change  NAILGUN_COMMIT?=stable/4.1
           To      NAILGUN_COMMIT?=no_create_environment

5. Install necessary packages (If using Ubuntu 13.10 server minimal)

        sudo apt-get install build-essential make git ruby ruby-dev rubygems debootstrap
        sudo apt-get install python-setuptools yum yum-utils libmysqlclient-dev isomd5sum
        sudo apt-get install python-nose libvirt-bin python-ipaddr python-paramiko python-yaml
        sudo apt-get install python-pip kpartx extlinux unzip genisoimage nodejs

5.1. Install necessary packages

        sudo apt-get install gem
        sudo gem install bundler
        mkdir ~/tmp
        chmod 777 ~/tmp

6. Start the build process

        make iso

