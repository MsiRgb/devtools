#!/bin/sh

# Use this file to perform post-install configuration
# Examples: network config / bridge configuration, data copy, etc...

set -x -v
exec 1>/var/log/preseed-late.log 2>&1

echo "Configuring grub for rootdelay=90 and nomodeset"
cp /etc/default/grub /etc/default/grub.bak
sed -i -e 'GRUB_CMDLINE_LINUX_DEFAULT/d' /etc/default/grub
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet rootdelay=90 nomodeset\"" >> /etc/default/grub
update-grub
echo "...done"

echo "Install the postinstall service"
cp /var/tmp/postinstall/postinstall /etc/init.d/postinstall
chmod +x /etc/init.d/postinstall
update-rc.d postinstall defaults
echo "Finished installing the postinstall service"

echo "preseed-late actions completed!"
