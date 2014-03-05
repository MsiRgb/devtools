#!/bin/sh
# Script requires the Crowbar primary IP (defined as the "admin" IP in the bc-template-network.json file)

crowbar_admin_ip=$1
set -x -v
exec 1>/root/postinstall_crowbar-stage2.log 2>&1

result=1
until tcping -t 2 $crowbar_admin_ip 3000
do
        echo "Sleeping 30 seconds..."
        sleep 30;
done
echo "Crowbar is up!"

echo "Waiting an additional minute to allow Crowbar to normalize..."
sleep 60

echo "Restart networking to update the local networking stack with changes made by Chef using bc-template-network.json"
/etc/init.d/network restart

echo "Hand off to the install_openstack script"
openstack_installer="/tftpboot/redhat_dvd/extra/install_openstack.sh"
screen -d -m -S install-openstack -t 'Install OpenStack' script -f -c "$openstack_installer"
