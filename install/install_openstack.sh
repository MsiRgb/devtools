#!/bin/sh

set -x -v
exec 1>/root/install_openstack-stage1.log 2>&1

CMD_DIR="/opt/dell/bin"

machine_list=$CMD_DIR"/crowbar machines list


