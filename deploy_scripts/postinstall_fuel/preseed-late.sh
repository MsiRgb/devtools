#!/bin/sh

# Use this file to perform post-install configuration
# Examples: network config / bridge configuration, data copy, etc...

set -x -v
exec 1>/var/log/preseed-late.log 2>&1

echo "Install the postinstall service"
cp /var/tmp/postinstall/postinstall /etc/init.d/postinstall
chmod +x /etc/init.d/postinstall
update-rc.d postinstall defaults
echo "Finished installing the postinstall service"

echo "preseed-late actions completed!"
