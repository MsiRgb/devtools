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

5. Install necessary packages

        sudo apt-get install gem
        sudo gem install bundler
        
        mkdir ~/tmp
        chmod 777 ~/tmp

6. Start the build process

        make iso

