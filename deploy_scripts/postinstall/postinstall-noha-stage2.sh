#!/bin/sh
#
# postinstall-noha-stage2.sh
# Description: Provisions Crowbar OS and deploys application
# Usage: postinstall-noha-stage2.sh
# Example: postinstall-noha-stage2.sh
#
# Copyright 2014, Momentum Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		 http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# ++++++++++++++++++ VARIABLE DEFINITIONS START ++++++++++++++++++
CROWBAR_IP="192.168.124.10"
CROWBAR_USER="crowbar"
CROWBAR_HOSTNAME="crowbar"
CROWBAR_DNSDOMAINNAME="rgbnetworks.com"
CROWBAR_FQDN="$CROWBAR_HOSTNAME.$CROWBAR_DNSDOMAINNAME"
CROWBAR_KVMDOMAINNAME="crowbar"
SSHPASS="crowbar"
TARGET_FQDN=""
MACHINE=""
CROWBAR_GUI_PORT="3000"
SSH_PORT="22"
CROWBAR_ISO="inner.iso"

POSTINSTALL_PATH="/var/tmp/postinstall"

SSH_CMD="/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l "
SFTP_CMD="/usr/bin/sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -b - $CROWBAR_USER@$CROWBAR_IP"

# ++++++++++++++++++ VARIABLE DEFINITIONS END ++++++++++++++++++
# ++++++++++++++++++ FUNCTIONS START ++++++++++++++++++

####
# provision_crowbar is used to create the KVM domain and install the OS using the ISO designated in the $CROWBAR_ISO variable.
#	This action requires a specific config so it is separate from the other deploy_vm function
#	todo - integrate this function with the deploy_vm function
####
provision_crowbar() {

	local VMNAME=$1
	local VMINSTALL_STATE="Domain installation still in progress. You can reconnect to the console to complete the installation process."
	local VMINSTALL_ERROR="ERROR"

	echo "Define new VM and install $VMNAME"
	
        cp /var/tmp/postinstall/$CROWBAR_ISO /var/lib/libvirt/images/$CROWBAR_ISO

        # NOTE - The Crowbar VM must used, at a minimum, 15G IDE storage disk
#        local DEPLOYCMD="virt-install --connect qemu:///system --name $VMNAME --ram=6144 --vcpus=1 --os-type=linux \
#--disk path=/var/lib/libvirt/images/$VMNAME.qcow2,size=15,format=qcow2,bus=ide,cache=none --network=bridge:br0,model=virtio \
#--accelerate --vnc --noautoconsole --keymap=en-us --cdrom=/var/lib/libvirt/images/$CROWBAR_ISO"
        local DEPLOYCMD="virt-install --connect qemu:///system --name $VMNAME --ram=6144 --vcpus=1 --os-type=linux \
--disk path=/var/lib/libvirt/images/$VMNAME.qcow2,size=24,format=qcow2,bus=ide,cache=none --network=bridge:br0, \
--accelerate --vnc --noautoconsole --keymap=en-us --cdrom=/var/lib/libvirt/images/$CROWBAR_ISO"

	echo "Creating the vm called $VMNAME"
	DEPLOYSTATE=`$DEPLOYCMD`
	[[ $DEPLOYSTATE =~ ^$VMINSTALL_ERROR ]] && echo "$VM2DEPLOY failed to provision, trying again" && \
		DEPLOYSTATE=`$DEPLOYCMD`
		[[ $DEPLOYSTATE =~ $VMINSTALL_ERROR ]] && echo "$VM2DEPLOY failed to provision a second time. Exiting for safety." && \
			exit

	echo "Crowbar KVM domain has been created and the OS is installing"
}

####
# This function simply loops while looking for an answer on a specific TCP port using netcat
####
monitor_tcp_port() {

	local TARGET_IP=$1
	local TARGET_PORT=$2

	result=1
	until nc -z $TARGET_IP $TARGET_PORT ; do
    		echo "TCP port $TARGET_PORT is not answering, sleeping 30 seconds..."
    		sleep 10
  	done
  	echo "TCP port $TARGET_PORT is answering"
}

####
# This function calls the install script on the Crowbar machine to install the Crowbar application, once the thread is
#	released the function then checks that the .crowbar-installed-ok file has been created, then finally reboots the VM.
####
install_crowbar_app() {

        echo "WORKAROUND to fix gem version problems with Crowbar roxy build..."

        $SSH_CMD $CROWBAR_USER $CROWBAR_IP "rm /opt/dell/barclamps/crowbar/cache/gems/activesupport-4.0.4.gem /opt/dell/barclamps/crowbar/cache/gems/rake-10.2.1.gem<<EOF
crowbar
EOF
"
	echo "Installing Crowbar application"

	$SSH_CMD $CROWBAR_USER $CROWBAR_IP "cd /tftpboot/ubuntu_dvd/extra && sudo -S ./install $CROWBAR_FQDN --no-screen<<EOF
crowbar
EOF
"

	# A file is generated on the Crowbar machine once the application has been installed successfully. We can loop a sleep
	#	to monitor for its creation
        local FILE_EXISTS=`$SSH_CMD $CROWBAR_USER $CROWBAR_IP ls /opt/dell/crowbar_framework/.crowbar-installed-ok`
        if [[ "$FILE_EXISTS" =~ "No such file or directory" ]] ; then
                echo "Install of Crowbar failed. Exit for safety." && exit
        fi


	# once the install has completed we need to reboot
	echo "Crowbar has been successfully installed. Rebooting."
	$SSH_CMD $CROWBAR_USER $CROWBAR_IP "sudo -S reboot<<EOF
crowbar
EOF
"
}

####
# WFS (watch for shutdown) is used to periodically query the libvirt daemon for the state of the KVM domain in question. If
#	the state is not running then the VM will be restarted, else the script sleeps for 30 seconds.
####
wfs() {

	local RUNNING="running"

  	DOMAIN=$1

  	STATE=$(virsh domstate $DOMAIN)

  	if [[ $STATE =~ $RUNNING ]] ; then

    		echo "Sleeping until shutdown"
    		sleep 30

		# Call wfs again - we can do this instead of looping, it's cleaner
   		wfs $DOMAIN
	else
    		sleep 1

    		echo "$DOMAIN is now shut down, starting it back up"
    		STATE=`virsh start $DOMAIN`
	fi
}
# ++++++++++++++++++ FUNCTIONS END ++++++++++++++++++
# ++++++++++++++++++ ACTIONS START ++++++++++++++++++
			set -x -v
exec 1>/var/log/postinstall-noha-stage2.log 2>&1

echo ">>>>>>>>>>>>> `date +%m%d%Y-%H%M%Z`- CROWBAR STARTS <<<<<<<<<<<<<<<"

# The sshpass command looks for the SSHPASS variable - we need to export it
export SSHPASS=$SSHPASS

####
# We need to copy the Crowbar ISO from the existing directory to final directory. This way we don't have to worry about
# 	permissions across different types of hypervisors
####
#copy_crowbar_iso

####
# Crowbar is provisioned via virt-install and the ISO above
####
provision_crowbar $CROWBAR_KVMDOMAINNAME

####
# The KVM domain BIOS (seabios) can be, well, challenging...for example it doesn't reboot the Crowbar VM as it should,
#	hence we need to monitor the domain's state and restart it accordingly
####
wfs $CROWBAR_KVMDOMAINNAME

####
# Once the KVM domain is up and running we can using netcat to check that SSH is up and running - we use this function
#	as the litmus test for whether the VM has started and we can start installing Crowbar
####
monitor_tcp_port $CROWBAR_IP $SSH_PORT

####
# The Crowbar application doesn't automatically install on boot and must be manually initiated
####
install_crowbar_app $CROWBAR_IP $CROWBAR_FQDN

####
# This time we care that Crowbar is up and ruuning so we monitor the Crowbar web GUI TCP port 3000.
####
monitor_tcp_port $CROWBAR_IP $CROWBAR_GUI_PORT

echo ">>>>>>>>>>>>> `date +%m%d%Y-%H%M%Z`- CROWBAR ENDS <<<<<<<<<<<<<<<"
# ++++++++++++++++++ ACTIONS START ++++++++++++++++++
