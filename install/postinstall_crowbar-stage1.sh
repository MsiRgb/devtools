#!/bin/sh
set -x -v
exec 1>/root/postinstall_crowbar-stage1.log 2>&1

echo "Remove this script's entry in rc.local..."
sed -i 's/sh \/tftpboot\/redhat_dvd\/extra\/\/postinstall-crowbar-stage1.sh/ /g' /etc/rc.d/rc.local

echo "Enable root access for user crowbar..."
echo "crowbar ALL=(ALL) ALL" >> /etc/sudoers

echo "Mount config drive to /mnt/crowbar_media"
mkdir /mnt/crowbar_media
mount -t ext4 /dev/vda /mnt/crowbar_media

echo "Update bc-template-network.json"
cfg_file="/opt/dell/barclamps/network/chef/data_bags/crowbar/bc-template-network.json"
cp $cfg_file $cfg_file.orig

function update_admin {
	
	admin_base_subnet=`echo $admin_subnet | cut -d"." -f1-3`
	echo ""
	echo "admin_subnet - $admin_subnet"
	echo "admin subnet base - $admin_base_subnet"
	admin_broadcast=$admin_base_subnet".255"
	admin_router=$admin_base_subnet".1"
	admin_range_start=$admin_base_subnet".10"
	admin_range_end=$admin_base_subnet".11"
	admin_dhcp_range_start=$admin_base_subnet".21"
	admin_dhcp_range_end=$admin_base_subnet".80"
	admin_host_range_start=$admin_base_subnet".81"
	admin_host_range_end=$admin_base_subnet".160"
	admin_switch_range_start=$admin_base_subnet".241"
	admin_switch_range_end=$admin_base_subnet".250"
	
	echo "Updating admin_subnet - $admin_subnet"
	sed -i 's/"subnet": "192.168.124.0",/"subnet": "'$admin_subnet'",/g' $cfg_file
	
	echo "Updating admin_broadcast - $admin_broadcast"
	sed -i 's/"broadcast": "192.168.124.255",/"broadcast": "'$admin_broadcast'",/g' $cfg_file
	
	echo "Updating admin_router - $admin_router"
	sed -i 's/"router": "192.168.124.1",/"router": "'$admin_router'",/g' $cfg_file	
	
	echo "Updating admin_range_start - $admin_range_start and admin_range_end - $admin_range_end"
	sed -i 's/"start": "192.168.124.10", "end": "192.168.124.11"/"start": "'$admin_range_start'", "end": "'$admin_range_end'"/g' $cfg_file

	echo "Updating admin_dhcp_range_start - $admin_dhcp_range_start and admin_dhcp_range_end - $admin_dhcp_range_end"
	sed -i 's/"start": "192.168.124.21", "end": "192.168.124.80"/"start": "'$admin_dhcp_range_start'", "end": "'$admin_dhcp_range_end'"/g' $cfg_file
	
	echo "Updating admin_host_range_start - $admin_host_range_start and admin_host_range_end - $admin_host_range_end"
	sed -i 's/"start": "192.168.124.81", "end": "192.168.124.160"/"start": "'$admin_host_range_start'", "end": "'$admin_host_range_end'"/g' $cfg_file
	
	echo "Updating admin_switch_range_start - $admin_switch_range_start and admin_switch_range_end - $admin_switch_range_end"
	sed -i 's/"start": "192.168.124.241", "end": "192.168.124.250"/"start": "'$admin_switch_range_start'", "end": "'$admin_switch_range_end'"/g' $cfg_file	
	
	echo "Admin network configurations updated"
	echo ""
}

function update_bmc {
	bmc_base_subnet=`echo $bmc_subnet | cut -d"." -f1-3`
	echo "bmc_subnet - $bmc_subnet"
	echo "bmc_subnet_base - $bmc_subnet_base"
	bmc_broadcast=$bmc_base_subnet".255"
	bmc_host_range_start=$bmc_base_subnet".162"
	bmc_host_range_end=$bmc_base_subnet".240"

	echo "Updating bmc_subnet - $bmc_subnet"
	sed -n 199p  -i ""'subnet'": "$bmc_subnet"" $cfg_file

	echo "Updating bmc_broadcast - $bmc_broadcast"
	sed -n 201p  -i ""'broadcast'": "$bmc_subnet"" $cfg_file
	
	echo "Updating bmc_host_range_start - $bmc_host_range_start and bmc_host_range_end - $bmc_host_range_end"
	sed -n 203p  -i ""'start'": "$bmc_host_range_start", "'end'": "$bmc_host_range_end"" $cfg_file
	
	echo "Updating bmc_vlan - $bmc_vlan"
	sed -n 196p  -i  ""'vlan'": "$storage_vlan"" $cfg_file
	
	echo "bmc configurations updated"
	echo ""

}

function update_nova_fixed {
	nova_fixed_base_subnet=`echo $nova_fixed_subnet | cut -d"." -f1-3`
	echo "nova_fixed_subnet - $nova_fixed_subnet"
	echo "nova_fixed subnet base - $nova_fixed_base_subnet"
	nova_fixed_broadcast=$nova_fixed_base_subnet".255"
	nova_fixed_router=$nova_fixed_base_subnet".1"
	nova_fixed_router_range_start=$nova_fixed_base_subnet".1"
	nova_fixed_router_range_end=$nova_fixed_base_subnet".49"
	nova_fixed_dhcp_range_start=$nova_fixed_base_subnet".50"
	nova_fixed_dhcp_range_end=$nova_fixed_base_subnet".254"	

	echo "Updating nova_fixed_subnet - $nova_fixed_subnet"
	sed -i 's/"subnet": "192.168.123.0",/"subnet": "'$nova_fixed_subnet'",/g' $cfg_file	

	echo "Updating nova_fixed_broadcast - $nova_fixed_broadcast"
	sed -i 's/"broadcast": "192.168.123.255",/"broadcast": "'$nova_fixed_broadcast'",/g' $cfg_file
	
	echo "Updating nova_fixed_router - $nova_fixed_router"
	sed -i 's/"router": "192.168.123.1",/"router": "'$nova_fixed_router'",/g' $cfg_file
	
	echo "Updating nova_fixed_router_range_start - $nova_fixed_router_range_start and nova_fixed_router_range_end - $nova_fixed_router_range_end"
	sed -i 's/"start": "192.168.123.1", "end": "192.168.123.49"/"start": "'$nova_fixed_router_range_start'", "end": "'$nova_fixed_router_range_end'"/g' $cfg_file

	echo "Updating nova_fixed_dhcp_range_start - $nova_fixed_dhcp_range_start and nova_fixed_dhcp_range_end - $nova_fixed_dhcp_range_end"
	sed -i 's/"start": "192.168.123.50", "end": "192.168.123.254"/"start": "'$nova_fixed_dhcp_range_start'", "end": "'$nova_fixed_dhcp_range_end'"/g' $cfg_file
	
	echo "Nova fixed configurations updated"
	echo ""
}

function update_nova_floating {
	nova_floating_base_subnet=`echo $nova_floating_subnet | cut -d"." -f1-3`
	echo "nova_floating_subnet - $nova_floating_subnet"
	echo "nova_floating subnet base - $nova_floating_base_subnet"
	nova_floating_broadcast=$nova_floating_base_subnet".191"
	nova_floating_host_range_start=$nova_floating_base_subnet".129"
	nova_floating_host_range_end=$nova_floating_base_subnet".191"	

	echo "Updating nova_floating_subnet - $nova_floating_subnet"
	sed -i 's/"subnet": "192.168.126.128",/"subnet": "'$nova_floating_subnet'",/g' $cfg_file	

	echo "Updating nova_floating_broadcast - $nova_floating_broadcast"
	sed -i 's/"broadcast": "192.168.126.191",/"broadcast": "'$nova_floating_broadcast'",/g' $cfg_file
	
	echo "Updating nova_floating_host_range_start - $nova_floating_host_range_start and nova_floating_host_range_end - $nova_floating_host_range_end"
	sed -i 's/"start": "192.168.126.129", "end": "192.168.126.191"/"start": "'$nova_floating_host_range_start'", "end": "'$nova_floating_host_range_end'"/g' $cfg_file
	
	echo "Updating nova_floating_vlan - $nova_floating_vlan"
	sed -i 's/"vlan": 300/"vlan": '$nova_floating_vlan'"/g' $cfg_file
	
	echo "Nova floating configurations updated"
	echo ""
}

function update_os_sdn {
	os_sdn_base_subnet=`echo $os_sdn_subnet | cut -d"." -f1-3`
	echo "os_sdn_subnet - $os_sdn_subnet"
	echo "os_sdn subnet base - $os_sdn_base_subnet"
	os_sdn_broadcast=$os_sdn_base_subnet".255"
	os_sdn_host_range_start=$os_sdn_base_subnet".10"
	os_sdn_host_range_end=$os_sdn_base_subnet".254"	

	echo "Updating os_sdn_subnet - $os_sdn_subnet"
	sed -i 's/"subnet": "192.168.130.0",/"subnet": "'$os_sdn_subnet'",/g' $cfg_file	

	echo "Updating os_sdn_broadcast - $os_sdn_broadcast"
	sed -i 's/"broadcast": "192.168.130.255",/"broadcast": "'$os_sdn_broadcast'",/g' $cfg_file
	
	echo "Updating os_sdn_host_range_start - $os_sdn_host_range_start and os_sdn_host_range_end - $os_sdn_host_range_end"
	sed -i 's/"start": "192.168.130.10", "end": "192.168.130.254"/"start": "'$os_sdn_host_range_start'", "end": "'$os_sdn_host_range_end'"/g' $cfg_file
	
	echo "Updating os_sdn_vlan - $os_sdn_vlan"
	sed -i 's/"vlan": 400/"vlan": '$os_sdn_vlan'"/g' $cfg_file
	
	echo "OS SDN configurations updated"
	echo ""
}

function update_storage {
	storage_base_subnet=`echo $storage_subnet | cut -d"." -f1-3`
	echo "storage_subnet - $storage_subnet"
	echo "storage subnet base - $storage_base_subnet"
	storage_broadcast=$storage_base_subnet".255"
	storage_host_range_start=$storage_base_subnet".10"
	storage_host_range_end=$storage_base_subnet".254"	

	echo "Updating storage_subnet - $storage_subnet"
	sed -i 's/"subnet": "192.168.125.0",/"subnet": "'$storage_subnet'",/g' $cfg_file	

	echo "Updating storage_broadcast - $storage_broadcast"
	sed -i 's/"broadcast": "192.168.125.255",/"broadcast": "'$storage_broadcast'",/g' $cfg_file
	
	echo "Updating storage_host_range_start - $storage_host_range_start and storage_host_range_end - $storage_host_range_end"
	sed -i 's/"start": "192.168.125.10", "end": "192.168.125.239"/"start": "'$storage_host_range_start'", "end": "'$storage_host_range_end'"/g' $cfg_file
	
	echo "Updating storage_vlan - $storage_vlan"
	sed -i 's/"vlan": 200/"vlan": '$storage_vlan'"/g' $cfg_file
	
	echo "Storage configurations updated"
	echo ""
}

#crowbar_fqdn="crowbar.crowbar.org"
#admin_base_subnet="192.168.124"

if [ -e /mnt/crowbar_media/kernel_args ]
then
	for I in `cat /mnt/crowbar_media/kernel_args`; do case "$I" in *=*) eval $I;; esac ; done

		crowbar_fqdn=$crowbar_fqdn
		admin_subnet=$admin_subnet
		bmc_subnet=$bmc_subnet
		bmc_vlan_subnet=$bmc_vlan_subnet
		bmc_vlan_vlan=$bmc_vlan_vlan
		nova_fixed_subnet=$nova_fixed_subnet
		nova_floating_subnet=$nova_floating_subnet
		nova_floating_vlan=$nova_floating_vlan
		os_sdn_subnet=$os_sdn_subnet
		os_sdn_vlan=$os_sdn_vlan
		storage_subnet=$storage_subnet
		storage_vlan=$storage_vlan

        update_admin
        update_nova_fixed
        update_nova_floating
        update_os_sdn
        update_storage
fi


# Let's cat the bc-template-network.json for posterity/troubleshooting
cat $cfg_file

# Install Crowbar now
echo "Installing Crowbar as $crowbar_fqdn"
cd /tftpboot/redhat_dvd/extra
installer="/tftpboot/redhat_dvd/extra/install-chef.sh $crowbar_fqdn"
screen -d -m -S crowbar-install -t 'Crowbar install' script -f -c "$installer" /var/log/crowbar-install.log

# Loop tcping monitor watching for Crowbar installation completion
crowbar_admin_ip=$admin_base_subnet".10"
screen -d -m -S crowbar-install-monitor -t 'Monitor crowbar install' script -f -c "/tftpboot/redhat_dvd/extra/monitor_crowbar_install.sh $crowbar_admin_ip" 

echo "Post install steps complete"
