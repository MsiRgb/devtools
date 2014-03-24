#!/bin/sh
#
# postinstall-noha-stage3.sh
# Description: Deploys slave VMs, uses Crowbar to install the OS and configure OpenStack 
#		services
# Usage: postinstall-noha-stage3.sh
# Example: postinstall-noha-stage3.sh
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
NUMMACHINES=""
CROWBAR_GUI_PORT="3000"
SSH_PORT="22"
NEEDSBOOT=false

POSTINSTALL_PATH="/var/tmp/postinstall"
KERNELARGS="$POSTINSTALL_PATH/kernel_args"
MACHFILE="$POSTINSTALL_PATH/machines_list"
ALLOCFILE="$POSTINSTALL_PATH/machines_alloc"
READYINGFILE="$POSTINSTALL_PATH/machines_readying"
READYFILE="$POSTINSTALL_PATH/machines_ready"
ASSIGNFILE="$POSTINSTALL_PATH/machines_assign"
COMMITFILE="$POSTINSTALL_PATH/machines_committed"
KVM_DOMAINS="$POSTINSTALL_PATH/kvm_domains"

SSH_CMD="/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l"
SFTP_CMD="/usr/bin/sshpass -e sftp -o BatchMode=no -o StrictHostKeyChecking=no -b - $CROWBAR_USER@$CROWBAR_IP"
CROWBAR_CMD="/opt/dell/bin/crowbar"

# This list of barclamps must be in the correct installation order or the barclamp application will fail!
# Also the number of barclamps must be equal to the NUMMACHINES variable
SVCS="database keystone rabbitmq glance cinder neutron nova nova_dashboard ceilometer heat"
# ++++++++++++++++++ VARIABLE DEFINITIONS END ++++++++++++++++++
# ++++++++++++++++++ FUNCTIONS START ++++++++++++++++++
####
# This function deploys a requested number of VMs (controlled by the passed argument) and names them based on a preset naming
# standard. NOTE - if a VM already exists with the desired name a new VM will not be created
####
deploy_vms() {

	local COUNTER=0
	local VMNAME=vm$COUNTER
	local VMINSTALL_STATE="Domain installation still in progress. You can reconnect to the console to complete the installation process."
	local VMINSTALL_ERROR="ERROR"

	echo "`date +%m%d%Y-%H%M%Z`- $NUMMACHINES are being deployed during this run."

	# Delete the kvm_domains file if it exists
	if [[ -e $KVM_DOMAINS ]] ; then rm $KVM_DOMAINS ; fi

	until [[ $COUNTER -eq $NUMMACHINES ]] ; do

		local DEPLOYCMD="virt-install --connect qemu:///system --name $VMNAME --ram=1024 --vcpus=1 --os-type=linux \
--disk path=/var/lib/libvirt/images/$VMNAME.qcow2,size=10,format=qcow2,bus=ide,cache=none --network=bridge:br0,model=virtio \
--network=bridge:br0,model=virtio --network=bridge:br0,model=virtio --accelerate --vnc --noautoconsole --keymap=en-us --pxe \
--boot=network,hd"

		echo "Creating the vm called $VMNAME"
		DEPLOYSTATE=`$DEPLOYCMD`
		[[ $DEPLOYSTATE =~ ^$VMINSTALL_ERROR ]] && echo "$VMNAME failed to provision, trying again" && \
			DEPLOYSTATE=`$DEPLOYCMD`
			[[ $DEPLOYSTATE =~ $VMINSTALL_ERROR ]] && echo "$VMNAME failed to provision a second time. Exiting for safety." && \
				exit

		# We store the KVM domain name to a file for later use - for some reason seabios doesn't always like to reboot correctly
		echo $VMNAME >> $KVM_DOMAINS

		# Increase the counter by one
		COUNTER=`expr $COUNTER + 1`

		# VM name index is set to the prefix vm and the counter value
		VMNAME="vm$COUNTER"

		# Delay the next VM by 60 seconds to reduce the boot storm impact
		sleep 60

  	done

  	echo "`date +%m%d%Y-%H%M%Z`- $NUMMACHINES VM(s) have been created successfully"

 }

####
# This function uses the Crowbar CLI command to retrieve a list of machines that Crowbar is managing
####
get_machine_list() {

	echo "`date +%m%d%Y-%H%M%Z`- Retrieving the current machine list from Crowbar"

	# If the file exists delete any existing $MACHFILE
	if [[ -f $MACHFILE ]] ; then rm -f $MACHFILE ; fi

	# SSH to Crowbar, retrieve the machine list and write it to $MACHFILE
	$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines list -U crowbar -P crowbar > $MACHFILE

	# If $MACHFILE doesn't exist then something really strange happened so wait 30 seconds and retry
	if [[ ! -f $MACHFILE ]] ; then
		echo "For some reason the machines list failed, wait 30 seconds and retry"
		sleep 30
		$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines list -U crowbar -P crowbar > $MACHFILE

		if [[ ! -f $MACHFILE ]] ; then
			echo "Something is wrong, I can't retrieve the Crowbar machine list. Stopping."
			exit
		else
			echo "`date +%m%d%Y-%H%M%Z`- Returning from get_machine_list"
			return
		fi
	else
		echo "`date +%m%d%Y-%H%M%Z`- Returning from get_machine_list"
		return
	fi

}

####
# This function acts as the conductor, it watches the individual VM Crowbar state via the Crowbar check_ready script and takes action using the Crowbar CLI command
#	based on the state.
#
# Things to note
# - The initial state of any machine that boots via the sledgehammer PXE image is DISCOVERED. The VM waits for action from Crowbar at this stage.
# - Next each discovered VM will start the allocation process and wait for the PXE image to be sent - the OS should be laid down on the image via PXE
#	during this stage HOWEVER the timing of the chef-client running on the Crowbar server doesn't always jive well so once all of the machines in the
#	machines list are looped we run chef-client. It's dirty but required.
# - Finally all of the machines should make it to ready state - this means that the OS has been installed and barclamp(s) can be installed. A separate list
#	is created for the ready machines and is looped later on in the assign_machines_to_proposals function
####
monitor_machine_state() {

	echo "`date +%m%d%Y-%H%M%Z`- Starting to verify that the machines are installing"

	local LINE=""
	local NODE=""
	local READYMACHINES=0
	local RUNCHEFCLIENT=false
	local NEEDSBOOT=false
	local DISC=false
	local STATE=""
	local READYINGENTRY=""

	# The deadline to transition from readying to ready is 20 minutes, after 20 minutes we need to destroy the VM and start again.
	local READYINGDEADLINE=$(($(date '+%s') + 1200))

	# We really care about the ready state, at that point we will leave this function to do other things
	# Given that we loop the $READYFILE until the number of machines reported in the $READYFILE equals the number of machines we provisioned minus one, the one is the
	# 	Crowbar VM

	until [[ $READYMACHINES -eq $NUMMACHINES ]] ; do

		# Call get_machine_list again to refresh the list of machines - this way any new machines that appear are captured
		get_machine_list

		# Grab the machine list from the $MACHFILE and assign it to a variable
		MACHLIST=`cat $MACHFILE`

		# Loop through all of the reported machines, retrieve their status from Crowbar, and act accordingly
		for LINE in $MACHLIST ; do

			# The individual lines have some trash at the end, remove it
			NODE=`echo $LINE | sed '$s/.$//'`

				# Very rarely the dtest-1.dell.com and dtest-2.dell.com machines are left - ignore them and the Crowbar server itself
				[[ $NODE =~ ^dtest* ]] && echo "Found a straggler - $NODE - ignoring" && continue
		    		[[ $NODE =~ ^crowbar.* ]] && echo "Ignoring the Crowbar server" && continue

		    		# Hopefully all of the remaining entries are valid nodes - SSH to Crowbar and run a check_ready for the node to retrieve its state
				[[ $NODE =~ ^d[0-9a-f]-* ]] && echo "Not a straggler - $NODE - verifying status" && \
				        STATE=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -l $CROWBAR_USER $CROWBAR_IP /opt/dell/bin/check_ready $NODE`

					# The initial state of the VM is reported as discovered, therefore we should allocate any node that is in the discovered state. If
					# Crowbar's chef-client failed to act on a previous attempt to allocate we need to remove any existing entries in the $ALLOCFILE.
					# To ensure that the PXE image is received we also set a flag (RUNCHEFCLIENT) to true so that after the current loop is complete
					# the Crowbar chef-client is manually initiated.
					#
					# TO DO - per the Crowbar 1.x users guide we should be able to skip the allocate step if we assign a discovered machine to proposal
					#		and commit the proposal HOWEVER I haven't yet seen that work so until then we are going to do it the long way
					if [[ $STATE =~ [Dd]iscovered ]] ; then
						$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines allocate "$NODE -U crowbar -P crowbar"
						echo "Allocating $NODE"
						if [[ -n "`grep $NODE $ALLOCFILE`" ]] ; then sed -i "/$NODE/d" $ALLOCFILE ; fi
						RUNCHEFCLIENT=true
						DISC=true
						# Sleep 60 seconds to ensure that the Crowbar server isn't swamped
						# sleep 60
					# Once the VM state is installing we just need to wait until it finishes and we add it to the $ALLOCFILE if it doesn't already exist
					elif [[ $STATE =~ installing ]] ; then
						echo "$NODE is installing"
						if [[ -z "`grep $NODE $ALLOCFILE`" ]] ; then echo $NODE >> $ALLOCFILE ; fi
#					elif [[ $STATE =~ readying ]] ; then
#						echo "$NODE is readying"
#						if [[ -z "`grep $NODE $READYINGFILE`" ]] ; then 
#							echo "$NODE, `$READYINGDEADLINE`" >> $READYINGFILE
#						else
#							READYINGENTRY=`grep $NODE $READYINGFILE`
#							DEADLINE=`echo "$READYINGENTRY" | cut -d\, -f2`
#							if [[ (($(date '+%s') > $DEADLINE)) ; then
#								echo "$NODE has been in the readying state for more than 20 minutes, we need to kill it and build anew"
#								delete_machine $NODE
								
					elif [[ $STATE =~ ready\. ]] ; then
						echo "$NODE is ready"
						# Since the machine has now transitioned to the ready stae we can remove it from the allocation tracking file
						if [[ -n "`grep $NODE $ALLOCFILE`" ]] ; then sed -i "/$NODE/d" $ALLOCFILE ; fi && \
						# If the machine doesn't exist in the ready tracking file we need to add it
						if [[ -z "`grep $NODE $READYFILE`" ]] ; then echo $NODE >> $READYFILE ; fi
					fi

		done

		# The chef-client running on Crowbar is scheduled to run every 15 minutes which has shown to be slower than we would like during the initial installation phases
		# 	so we need to run Crowbar's chef-client manually to ensure that the PXE image is passed correctly
    		[[ $RUNCHEFCLIENT = true ]] && run_chef_client $CROWBAR_IP && RUNCHEFCLIENT=false

		READYMACHINES=`wc -l < $READYFILE`
		echo "`date +%m%d%Y-%H%M%Z`- There are $READYMACHINES machines in the ready state"
		if [[ ! $READYMACHINES -eq $NUMMACHINES ]] ;  then

			# seabios is, well, a pain sometimes, the machines SHOULD reboot once they enter the allocate stage but alas this doesn't always happen. Hence we will
			# 	watch for VMs that are shutdown. This is a blunt-force trauma thing also, the sub-function needs to be refined to reference the Crowbar name to 
			#	the kvm domain. We also scan twice as many times the VMs take longer than expected to shutdown and the loop has past before their shutdown. 
			DOMAINLIST=`cat $KVM_DOMAINS`
			for (( i=2; i > 0; i-- )) ; do			
				for DOMAIN in $DOMAINLIST ; do
					echo "Checking if $DOMAIN is shut down"
					wfs_machines $DOMAIN
					if [[ $NEEDSBOOT = true ]] ; then 
						virsh start $DOMAIN
						# Sleep 30 seconds so we don't swamp the KVM server from the boot storm
						sleep 30
						NEEDSBOOT=false
					fi
				done
			done

		fi
		# If machines were discovered we need to allow these machines time to start installing their images so we wait if DISC=true - this is really a timing issue,
		# if there are machines that remain in discovered chef-client on Crowbar needs additional time to provide the image for install
		if [[ $DISC = true ]] ; then
			sleep 120
			DISC=false
		fi
	done
	echo "`date +%m%d%Y-%H%M%Z`- All machines are in the ready state"
}

####
# This function loops a preset array of barclamps (really OpenStack services), updates preconfigured Crowbar proposals with a single VM name, then compresses and SFTPs
# 	them to the Crowbar server, decompresses them and imports the proposals
####
assign_machines_to_proposals() {

	#                                                                  !!!!!! 		READ ME		!!!!!!
	# The big takeaway here is that Crowbar expects/demands that most barclamp proposals are created/assign in a specific order, e.g the database server must come before
	#	Keystone because Keystone depends on a database. The strings that make up the $SVCS variable value are listed in this order, hence, if one fails the edit,
	#	import, or commit phases all of the remaining proposals will also fail. This is why if the upcoming commands fail we exit immediately.

	local SVC=""
	local TARGET=""
	local TARGETS=""
	local TGT=""
	local XFER_STATE=""
	local XFER_ERROR="No such file or directory"
	local COPY_STATE=""
	local PROPOSAL_TMP_PATH="/var/tmp/proposal_tmp"

	echo "`date +%m%d%Y-%H%M%Z`- Starting to assign the proposals to machines in the ready list"


	# Insert a discovered machine into a single proposal using the list of machines from Crowbar
	for SVC in $SVCS; do

		if [[ $SVC == "nova" ]] ; then

                	echo "Nova is special - it needs an entry for the controller and a separate entry for nova-compute"

                	# We grab the next two entries in the $READYFILE
	               TARGETS=`head -n 2 $READYFILE`

			local CNTR=0
	               # We loop the retrieved entries
			for TARGET in $TARGETS ; do

				# We have to remove the EOL junk character(s) individually so we do it here
				TGT=`echo $TARGET`

				# Same as above, we search the preformatted proposal file for the phrase REPLACE_ME and replace it with the value of the $NODE variable.
				#	If the file replacement fails we need to exit as the proposal import into Crowbar will fail and therefore, if left unchecked,
				#	the proposals will not commit in the correct order.
				echo "Inserting $TGT into proposal_$SVC"
				sed -i "0,/REPLACE_ME/s//$TGT/" $POSTINSTALL_PATH/proposals/$SVC.proposal || exit

				# We use the variable CNTR to hold a number, the first target is named nova, the second target is named nova-compute
				if [[ $CNTR -eq 0 ]] ; then
					# Rename the machine's alias in Crowbar to the nova
					$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines rename $TGT nova.$CROWBAR_DNSDOMAINNAME -U crowbar -P crowbar
				else
					# Rename the machine's alias in Crowbar to the nova-compute
					$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines rename $TGT nova-compute.$CROWBAR_DNSDOMAINNAME -U crowbar -P crowbar
				fi


				# We need to keep a record of what the real hostname and Crowbar alias assigned to each service - the $ASSIGNFILE list is used in the
				#	verify_multi_cc and commit_all_proposals functions
				if [[ -n "`grep '^$SVC,' $ASSIGNFILE`" ]] ; then
					sed -i "/$SVC/d" $ASSIGNFILE
				else
					echo "Adding $SVC,$TGT,$SVC.$CROWBAR_DNSDOMAINNAME to $ASSIGNFILE"
					echo "$SVC,$TGT,$SVC.$CROWBAR_DNSDOMAINNAME" >> $ASSIGNFILE
				fi
				# Now that this node has been assigned to a proposal we need to remove from the $READYFILE so that we don't reuse it for another proposal,
				# 	if the removal fails we need to exit for the same reason as above
				echo "Removing $TGT from $READYFILE"
				sed -i "/$TARGET/d" $READYFILE || exit

				CNTR=`expr $CNTR + 1`
			done

		elif [[ $SVC == "nova_dashboard" ]] ; then

			echo "Horizon (nova_dashboard) is special as the underscore cannot be used in a DNS name"

			# We grab the first entry in the $READYFILE and remove the junk character(s) from the EOL
                	TARGET=`head -n 1 $READYFILE`

			# Next we search the preformatted proposal file for the phrase REPLACE_ME and replace it with the machine name. If the file replacement fails we need to
			# 	exit as the proposal import into Crowbar will fail and therefore, if left unchecked, the proposals will not commit in the correct order.
			echo "Inserting $TARGET into proposal_$SVC"
			sed -i "s/REPLACE_ME/$TARGET/g" $POSTINSTALL_PATH/proposals/$SVC.proposal || exit

			# Crowbar expects for the renamed machine to adhere to DNS naming rules - therefore the underscore cannot be used so instead the machine alias
			#	is changed to better match the OpenStack service (horizon)
			$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines rename $TARGET horizon.$CROWBAR_DNSDOMAINNAME -U crowbar -P crowbar

			# We need to keep a record of what the real hostname and Crowbar alias assigned to each service - the $ASSIGNFILE list is used in the
			#	verify_multi_cc and commit_all_proposals functions
			if [[ -n "`grep '^$SVC,' $ASSIGNFILE`" ]] ; then
				sed -i "/$SVC/d" $ASSIGNFILE
			else
				echo "Adding $SVC,$TARGET,$SVC.$CROWBAR_DNSDOMAINNAME to $ASSIGNFILE"
				echo "$SVC,$TARGET,$SVC.$CROWBAR_DNSDOMAINNAME" >> $ASSIGNFILE
			fi

			# Now that this node has been assigned to a proposal we need to remove from the $READYFILE, if the removal fails we need to exit for the same
			# 	reason as above
			echo "Removing $TARGET from $READYFILE"
			sed -i "/$TARGET/d" $READYFILE || exit

        	elif [[ $SVC != "nova" ]] ; then

			# We grab the first entry in the $READYFILE and remove the junk character(s) from the EOL
                	TARGET=`head -n 1 $READYFILE`

			# Next we search the preformatted proposal file for the phrase REPLACE_ME and replace it with the machine name. If the file replacement fails we need to
			# 	exit as the proposal import into Crowbar will fail and therefore, if left unchecked, the proposals will not commit in the correct order.
			echo "Inserting $TARGET into proposal_$SVC"
			sed -i "s/REPLACE_ME/$TARGET/g" $POSTINSTALL_PATH/proposals/$SVC.proposal || exit

			# Rename the machine's alias in Crowbar to the service name
			$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines rename $TARGET $SVC.$CROWBAR_DNSDOMAINNAME -U crowbar -P crowbar

			# We need to keep a record of what the real hostname and Crowbar alias assigned to each service
			if [[ -n "`grep '^$SVC,' $ASSIGNFILE`" ]] ; then
				sed -i "/$SVC/d" $ASSIGNFILE
			else
				echo "Adding $SVC,$TARGET,$SVC.$CROWBAR_DNSDOMAINNAME to $ASSIGNFILE"
				echo "$SVC,$TARGET,$SVC.$CROWBAR_DNSDOMAINNAME" >> $ASSIGNFILE
			fi

			# Now that this node has been assigned to a proposal we need to remove from the $READYFILE, if the removal fails we need to exit for the same
			# 	reason as above
			echo "Removing $TARGET from $READYFILE"
			sed -i "/$TARGET/d" $READYFILE || exit
		fi
	done

	# Compress the updated proposals for ease of transfer
	echo "`date +%m%d%Y-%H%M%Z`- Compressing proposals"
	if [[ -e $POSTINSTALL_PATH/proposals/proposals.tar ]] ; then rm -f $POSTINSTALL_PATH/proposals/proposals.tar ; fi
	cd $POSTINSTALL_PATH/proposals && tar -cvf proposals.tar *
	echo "`date +%m%d%Y-%H%M%Z`- Proposals compressed"

	# Make sure we are in the correct directory and transfer the proposals.tar file to Crowbar
	cd $POSTINSTALL_PATH/proposals
	echo "`date +%m%d%Y-%H%M%Z`- Transferring proposals from `pwd`"
$SFTP_CMD <<EOF
put proposals.tar
bye
EOF
	echo "`date +%m%d%Y-%H%M%Z`- Proposals have been transferred to Crowbar"

	# Verify that proposals were transferred
	echo "Verifying proposal transfer to Crowbar"
	XFER_STATE=`$SSH_CMD $CROWBAR_USER $CROWBAR_IP ls /home/crowbar/proposals.tar`
	if [[ $XFER_STATE =~ $XFER_ERROR ]] ; then echo "Proposals tar file wasn't found on Crowbar. Exiting for safety." && exit ; fi
	echo "proposals.tar was found"

	# Transfer the proposals to Crowbar
	echo "`date +%m%d%Y-%H%M%Z`- Creating /var/tmp/proposal_temp directory on Crowbar"
	$SSH_CMD $CROWBAR_USER $CROWBAR_IP mkdir $PROPOSAL_TMP_PATH || exit
	echo "`date +%m%d%Y-%H%M%Z`- Decompressing proposals"
	$SSH_CMD $CROWBAR_USER $CROWBAR_IP tar -xvf /home/crowbar/proposals.tar -C $PROPOSAL_TMP_PATH || exit
	echo "`date +%m%d%Y-%H%M%Z`- Proposals decompressed"

	# Import the updated proposals into Crowbar
	echo "`date +%m%d%Y-%H%M%Z`- Importing proposals into Crowbar"
	for SVC in $SVCS ; do
		echo "Importing proposal_$SVC for $SVC"

		# The proposal must have the default filename
		COPY_STATE=`$SSH_CMD $CROWBAR_USER $CROWBAR_IP cp $PROPOSAL_TMP_PATH/$SVC.proposal $PROPOSAL_TMP_PATH/default.json`
		if [[ $COPY_STATE =~ $XFER_ERROR ]] ; then
			echo "$SVC proposal file not found. Exiting for safety." && exit
		else
			echo "$SVC proposal was copied to default.json successfully"
		fi

		# SSH to Crowbar and import the new proposal with the node - note that we are updating the default proposal - if the edit fails we need to stop for the
		#	same reason as above
		IMPORT_STATE=`$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD $SVC proposal edit default --file=$PROPOSAL_TMP_PATH/default.json -U crowbar -P crowbar`
		if [[ ! $IMPORT_STATE =~ "Edited default" ]] ; then
			echo "Error importing the $SVC proposal. Exiting for safety." && exit
		else
			$SSH_CMD $CROWBAR_USER $CROWBAR_IP rm -f $PROPOSAL_TMP_PATH/default.json
		fi
	done

	echo "`date +%m%d%Y-%H%M%Z`- All proposals have been imported into Crowbar successfully"
}

####
# We use this to verify whether the chef-client is running successfully via bluepill
# 	If it isn't then bluepill is configured to run it, if bluepill isn't setup
#	chef-client is called to install it
#
# TO DO - this function really needs to be broken up into several pieces, right now I think that the if..then..else.. loops are excessive but required
####
verify_cc_cfg() {
	local TARGET=$1
	local PSCMD=""
	local ARG=""
	echo "Verifying that the chef-client is working correcting on $1"

	echo "`date +%m%d%Y-%H%M%Z`- Checking if chef-client is running"

	# First we SSH to Crowbar and check whether chef-client is running
	ARG="ps aux | grep '[c]hef-client'"
	PSCMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET $ARG`
	if [[ -z "$PSCMD $ARG"  ]] ; then

		echo "chef-client is not running, need to check if bluepilld is running"

		# Chef-client isn't running so we need to first determine whether bluepill is running
		ARG="ps aux | grep '[b]luepilld'"
		PSCMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET $ARG`
		if [[ -z "$PSCMD $ARG" ]] ; then

			echo "bluepilld is not running, we need to load the chef-client.pill"

			# So bluepilld isn't running, let's check to see if the chef-client pill even exists
			CMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET ls /etc/bluepill/chef-client.pill`
			if [[ ! "$CMD"  ]] ; then

				# Not good, the chef-client pill doesn't exist so let's run chef-client manually to install it
				echo "/etc/bluepill/chef-client.pill doesn't exist, need to run chef-client to install"
				echo "Running chef-client manually"
				run_chef_client $TARGET

				# If for some reason the chef-client pill ISN'T installed now we really just need to exit, there's an issue upstream
				#	with the bluepill cookbook
				CMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET ls /etc/bluepill/chef-client.pill`
				if [[ ! "$CMD" ]] ; then
					echo "chef-client didn't install bluepill correctly. Exiting for safety." && exit
				else
					# Ok we are back on the right track - chef-client pill exists so we can load it with bluepill now
					echo "chef-client installed bluepill, now lets load it with bluepill"
					/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET "sudo -S bluepill load /etc/bluepill/chef-client.pill<<EOF
crowbar
EOF
"
					# Let's check to see that the chef-client is running under bluepilld now - if not exit as there more than likely
					#	a larger issue with bluepilld
					ARG="ps aux | grep '[b]luepilld: chef-client'"
					PSCMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET $ARG`
		               		if [[ -z "$PSCMD $ARG"  ]] ; then
		                      			echo "bluepill did not load the chef-client.pill successfully. Exiting for safety." && exit
                				else
							# Chef-client is running under bluepilld now, let's make sure that the chef-client is spawned
							echo "chef-client is now running under bluepill. Let's make sure that bluepill spawned the chef-client process."

						ARG="ps aux | grep '[c]hef-client'"
						PSCMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET $ARG`
                        				if [[ -z "$PSCMD $ARG"  ]] ; then
							# Chef-client isn't running as a separate spawned process, let's exit as this is more than likely
							#	larger issue
	                                			echo "The chef-client process was not spawned correctly. Exiting for safety." && exit
         	               			else
							# Ok we are good-to-go - bluepilld: chef-client is running and a spawned instance of chef-client
							# 	has been daemonized.
                                				echo "The chef-client process was spawned successfully by bluepill."
                        				fi
                				fi
				fi
			else
				# No biggie, bluepilld looks to be installed and the chef-client pill is there, let's load the chef-client pill
				echo "chef-client pill is present, load it into bluepill"
				/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET "sudo -S bluepill load /etc/bluepill/chef-client.pill<<EOF
crowbar
EOF
"
				# Sleep five seconds just in case the bluepilld daemon is slow start
				sleep 5

				# Now we check to make sure the chef-client pill loaded successfully - if it didn't we should exit as there is more
				#	than likely a larger issue
				ARG="ps aux | grep '[b]luepilld: chef-client'"
				PSCMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET $ARG`
				if [[ -z "$PSCMD $ARG"  ]] ; then
                      			echo "bluepill did not load the chef-client.pill successfully. Exiting for safety." && exit
                      		else
                      			# Chef-client is running under bluepilld now, let's make sure that the chef-client is spawned
                        			echo "chef-client is now running under bluepill. Let's make sure that bluepill spawned the chef-client process."

                        			# Finally let's check to make sure that the daemonized chef-client process is running
                        			ARG="ps aux | grep '[c]hef-client'"
                        			PSCMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET $ARG`
                      			if [[ -z "$PSCMD $ARG"  ]] ; then
                              			# Chef-client isn't running as a separate spawned process, let's exit as this is more than likely
						#	larger issue
                              			echo "The chef-client process was not spawned correctly. Exiting for safety." && exit
					else
                        				# Ok we are good-to-go - bluepilld: chef-client is running and a spawned instance of chef-client
                        				# 	has been daemonized.
                              			echo "The chef-client process was spawned successfully by bluepill."
                              		fi
                       		fi
			fi
		else
			# No biggie, bluepilld looks to be installed and the chef-client pill is there, let's load the chef-client pill
			echo "The chef-client.pill does exist, let's load it with bluepill."
			/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET "bluepill load /etc/bluepill/chef-client.pill<<EOF
crowbar
EOF
"
			# Sleep five seconds just in case the bluepilld daemon is slow start
			sleep 5

			# Now we check to make sure the chef-client pill loaded successfully - if it didn't we should exit as there is more
			#	than likely a larger issue
			ARG="ps aux | grep '[b]luepilld: chef-client'"
			PSCMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET $ARG`
			if [[ -z "$PSCMD $ARG"  ]] ; then

				echo "bluepill did not load the chef-client.pill successfully. Exiting for safety." && exit
			else
				# Chef-client is running under bluepilld now, let's make sure that the chef-client is spawned
				echo "chef-client is now running under bluepill. Let's make sure that bluepill spawned the chef-client process."

				# Finally let's check to make sure that the daemonized chef-client process is running
				ARG="ps aux | grep '[c]hef-client'"
				PSCMD=`/usr/bin/sshpass -e ssh -o BatchMode=no -o StrictHostKeyChecking=no -t -t -l $CROWBAR_USER $TARGET $ARG`
				if [[ -z "$PSCMD $ARG"  ]] ; then

					# Chef-client isn't running as a separate spawned process, let's exit as this is more than likely
					#	larger issue
					echo "The chef-client process was not spawned correctly. Exiting for safety." && exit
				else
                        			# Ok we are good-to-go - bluepilld: chef-client is running and a spawned instance of chef-client
                        			# 	has been daemonized.
					echo "The chef-client process was spawned successfully by bluepill."
				fi
			fi
		fi
	else
		# Chef-client is already running - nothing to see here!
		echo "chef-client is running"
	fi
}

#####
# Commit the proposal - this installs/configures the OpenStack or Crowbar role
#####
commit_proposal() {

	local SVC=$1
	local TARGET=$2
	local COMMIT_STATE=""
	local COMMITTED="Committed default."
	local QUEUED="^Queued default because"

	# We verify chef-client configuration of the target machine - if it is broken we try to fix it
	# verify_cc_cfg $TARGET

	echo "`date +%m%d%Y-%H%M%Z`- Commiting proposals into Crowbar"

	# SSH to Crowbar, commit the specific service's default proposal and set the returned answer to a variable
	echo "Commiting $SVC proposal"
	COMMIT_STATE=`$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD $SVC proposal commit default -U crowbar -P crowbar`

	# As long as the state variable equals the $COMMITTED string value we are good, else if the proposal is queued more than likely
	#	there is an issue with the chef-client on the target machine
	[[ $COMMIT_STATE =~ $COMMITTED ]] && echo "$SVC proposal has been successfully committed" && echo $SVC >> $COMMITFILE
	[[ $COMMIT_STATE =~ $QUEUED ]] && \
		echo "$SVC proposal has been queued, there may be an issue with chef-client. Triggering chef-client Crowbar and then on the client" && \
			run_chef_client $CROWBAR_IP && run_chef_client $TARGET
}

####
# We can't anticipate all of the hardware performance characteristics we will see so occasionally it will be best to just manually run chef-client vs.
#	waiting on the daemon
####
run_chef_client() {
	local TARGET=$1
	echo "`date +%m%d%Y-%H%M%Z`- Running chef-client on $TARGET"

	$SSH_CMD $CROWBAR_USER $TARGET "sudo -S /usr/bin/chef-client<<EOF
crowbar
EOF
"
	echo "`date +%m%d%Y-%H%M%Z`- chef-client run is complete on $TARGET"
}

####
# This function watches for the shutdown of the given KVM domain and restarts the domain as needed
####
wfs_machines() {
	local DOMAIN=$1
	local STATE=$(virsh domstate $DOMAIN)

	[[ "$STATE" = "shut off" ]] && echo "$DOMAIN is now shut down, starting it back up" && NEEDSBOOT=true
}

####
# Given the flakiness of Crowbar and Chef it is best to ensure that chef-client is actually running on the OpenStack VMs as the overall process
# 	really needs to work serially, else the steps get out of sync
####
verify_multi_cc() {
	local ASSIGNLIST=`cat $ASSIGNFILE`

	for LINE in $ASSIGNLIST ; do

		MACHINENAME=`echo "$LINE" | cut -d\, -f2`
		verify_cc_cfg $MACHINENAME
	done
}

####
# We loop all of the services and commit the proposals to Crowbar and Crowbar applies the barclamp to the OpenStack VM
####
commit_all_proposals() {

	local ASSIGNLIST=`cat $ASSIGNFILE`

	for LINE in $ASSIGNLIST ; do

		SVC=`echo "$LINE" | cut -d\, -f1`
		MACHINEFQDN=`echo "$LINE" | cut -d\, -f2`
		
		# First we check to make that the service's proposal has not already been committed, the best example is Nova as the Nova proposal contains 
		# 		both the nova-controller and nova-compute elements - the machines_assign file contains both of the machine entries (one of nova-controller and
		#		one for nova-compute. Therefore if we didn't check the nova proposal would be committed twice.
		if [[ ! `grep $SVC $COMMITFILE` ]] ; then
			# In this case cinder won't be used therefore we create a cinder-volumes LVM volume prior to the cinder proposal commit
			if [[ $SVC == "cinder" ]] ; then add_cinder-volume $MACHINEFQDN ; fi
			
			# For some reason the normal Havana install for Neutron doesn't create the ML2 plugin directory so we create it here first
#			if [[ $SVC == "neutron" ]] ; then 
#				$SSH_CMD $CROWBAR_USER $MACHINEFQDN "sudo -S mkdir /etc/neutron/plugins/ml2<<EOF
#crowbar
#EOF
#"
#			fi

			# Now we commit the proposal
			commit_proposal $SVC $MACHINEFQDN
		fi
	done
}

add_cinder-volume() {
	local TARGET=$1

	echo "Building cinder-volumes"
	$SSH_CMD $CROWBAR_USER $TARGET dd if=/dev/zero of=/var/tmp/cinder-volumes bs=1 count=0 seek=10M
	echo "cinder-volume file built"

	echo "Setup loop device to mount cinder-volume file"
	$SSH_CMD $CROWBAR_USER $TARGET "sudo -S losetup /dev/loop3 /var/tmp/cinder-volumes<<EOF
crowbar
EOF
"
	echo "Loop device is configured"

	echo "fdisk the loop"
	$SSH_CMD $CROWBAR_USER $TARGET "sudo -S fdisk /dev/loop3<<EOF
crowbar
n
p
1


t
8e
w
EOF
"
	echo "loop is formatted"

	echo "Configuring cinder-volume LVM"
	$SSH_CMD $CROWBAR_USER $TARGET chmod 660 /var/tmp/cinder-volumes 
	$SSH_CMD $CROWBAR_USER $TARGET "sudo -S pvcreate /dev/loop3<<EOF
crowbar
EOF
"
	$SSH_CMD $CROWBAR_USER $TARGET "sudo -S vgcreate cinder-volumes /dev/loop3<<EOF
crowbar
EOF
"
	$SSH_CMD $CROWBAR_USER $TARGET echo "losetup /dev/loop3 /var/tmp/cinder-volumes" >> /etc/rc.local
	echo "cinder-volume creation is complete"
}

delete_crowbar_slave() {
	
	TARGET=$1
	local ALIVE=""

	echo "Deleting $TARGET from Crowbar"
	$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines delete $TARGET -U crowbar -P crowbar

	# To ensure that the slave is deleted in a timely fashion we need to run chef-client on Crowbar to remove the slave
	# 	from the Chef admin server
	run_chef_client $CROWBAR_IP
	
	# Verify that the slave node is now gone
	ALIVE=`$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines show $TARGET -U crowbar -P crowbar`
	
	if [[ ! $ALIVE =~ "Failed to find node $TARGET" ]] ; then

		echo "$TARGET is still alive, waiting 2 minutes"
		sleep 120
		
		ALIVE=`$SSH_CMD $CROWBAR_USER $CROWBAR_IP $CROWBAR_CMD machines show $TARGET -U crowbar -P crowbar`

		if [[ ! $ALIVE =~ "Failed to find node $TARGET" ]] ; then
		
			echo "We have tried to remove the $TARGET from Crowbar twice but it won't go. Exiting for safety."
			exit
		fi
	fi
}

# ++++++++++++++++++ FUNCTIONS END ++++++++++++++++++
# ++++++++++++++++++ ACTIONS START ++++++++++++++++++
set -x -v
exec 1>/var/log/postinstall-noha-stage3.log 2>&1

echo ">>>>>>>>>>>>> `date +%m%d%Y-%H%M%Z`- OPENSTACK STARTS <<<<<<<<<<<<<<<"
DTSTART=`date +%s`

# The sshpass command looks for the SSHPASS variable - we need to export it
export SSHPASS=$SSHPASS

# Setup the state files
for STATEFILE in $ALLOCFILE $ASSIGNFILE $READYFILE; do
	echo "Creating $STATEFILE"
	touch $STATEFILE
done

# Determine the number of machines plus one for nova-compute (which isn't called out)
NUMMACHINES=`expr $(echo $SVCS | wc -w) + 1`

####
# We need to deploy the VMs that will be configured with the OpenStack services
####
deploy_vms

####
# Next we monitor the state of the machines and take action based on their state
####
monitor_machine_state

####
# All of the machines should be in the ready state and we can assign each of them to a proposal
####
assign_machines_to_proposals

####
# Given the flakiness of chef-client it's best to quickly verify that chef-client running on the OpenStack machines
#	is running correctly
####
verify_multi_cc

####
# Commit all proposals - this step will initiate the application of the OpenStack services to the assigned machines
####
commit_all_proposals

echo ">>>>>>>>>>>>> `date +%m%d%Y-%H%M%Z`- OPENSTACK ENDS <<<<<<<<<<<<<<<"
DTEND=`date +%s`
DTDIFF=$(( $DTEND - $DTSTART ))
DTMIN=`expr $DTDIFF / 60`
echo "postinstall actions took $DTMIN minutes"


# ++++++++++++++++++ ACTIONS END ++++++++++++++++++

