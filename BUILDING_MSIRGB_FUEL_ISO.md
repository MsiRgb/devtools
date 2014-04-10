These steps will build the MsiRgb custom Fuel ISO that will prevent users from
creating a new environment on the Fuel web interface.

1) Note: This should be done on an Ubuntu 13.10 development machine
2) Clone official Fuel ISO
	a. cd
	b. git clone https://github.com/stackforge/fuel-main.git
	c. cd ~/fuel-main
3) Switch to 4.1 stable branch
	a. git checkout stable/4.1
4) Edit configuration to reference MsiRgb repo for custom fuel-web
	a. vi ./config.mk
	Change	NAILGUN_REPO?=https://github.com/stackforge/fuel-web.git
	To	NAILGUN_REPO?=https://github.com/MsiRgb/fuel-web.git
	Change	NAILGUN_COMMIT?=master
	To	NAILGUN_COMMIT?=no_create_environment
5) Install necessary packages
	a. sudo apt-get install gem
	b. sudo gem install bundler
	c. mkdir ~/tmp
	d. chmod 777 ~/tmp
6) Start the build process
	a. make iso

