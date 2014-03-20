#!/bin/sh
set -x -v
exec 1>/var/log/preseed-late.log 2>&1

echo "Find the br0 IP address, gateway and new hostname"
for I in `cat /var/tmp/postinstall/cmdline`; do case "$I" in *=*) eval $I;; esac ; done
kvm_br0_ip=$kvm_mgmt_ip
kvm_br0_gw=$kvm_mgmt_gw
kvm_fqdn=$kvm_fqdn
kvm_hostname=`echo $kvm_fqdn | cut -f1 -d.`
admin_subnet=$admin_subnet
admin_base_subnet=`echo $admin_subnet | cut -d"." -f1-3`
crowbar_admin_ip=$admin_base_subnet".10"

echo "Build network bridge"
rm -f /etc/network/interfaces
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto br0
iface br0 inet static
address REPLACE-ADDR
netmask	255.255.255.0
gateway REPLACE-GW
dnsservers	REPLACE-DNS
bridge_ports	eth0
bridge_fd	0
bridge_stp	off
EOF

sed -i "s/REPLACE-ADDR/$kvm_br0_ip/g" /etc/network/interfaces
sed -i "s/REPLACE-GW/$kvm_br0_gw/g" /etc/network/interfaces
sed -i "s/REPLACE-DNS/$crowbar_admin_ip/g" /etc/network/interfaces

echo "Update hostname to $kvm_hostname"
echo "$kvm_hostname" >> /etc/hostname

echo "Update hosts file"
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1	$kvm_hostname $kvm_fqdn" >> /etc/hosts

echo "Install the postinstall service"
cp /var/tmp/postinstall/postinstall /etc/init.d/postinstall
chmod +x /etc/init.d/postinstall
update-rc.d postinstall defaults

echo "Finished installing the postinstall service"

echo "preseed-late actions completed!"
