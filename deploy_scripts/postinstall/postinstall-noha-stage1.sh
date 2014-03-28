#!/bin/sh
# vi: autoindent:tabstop=2 shiftwidth=2 softtabstop=2 noexpandtab: nowrap
#
# postinstall-noha-stage1.sh
# Description: Configures undercloud KVM host
# Usage: postinstall-noha-stage1.sh
# Example: postinstall-noha-stage1.sh
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


# ++++++++++++++++++ FUNCTIONS START ++++++++++++++++++
####
# This function firstly disables the service that controls this script, then installs sshpass and virtinstall
####
prereqs() {
  # Remove our postinstall service so that it won't run again
  if [ -e /etc/init.d/postinstall ]; then
  	update-rc.d -f postinstall remove
  fi

  echo "Installing sshpass"
  dpkg -i /var/tmp/postinstall/repo/sshpass_1.05-1_amd64.deb

  echo "Installing virt-install"
  dpkg -i /var/tmp/postinstall/repo/virtinst_0.600.1-1ubuntu3_all.deb
}

####
# config_kvm verifies that libvirt is running as a daemon, then removes the default libvirt-created networking, removes
#	authentication, and restarts the libvirt-bin service
####
config_kvm() {
  echo "Checking libvirt-bin status"
  until ps aux | grep "[l]ibvirtd" ; do
          echo "libvirt is not running, sleeping"
          sleep 5
  done

  echo "Destroy and undefine the default KVM network..."

  virsh net-destroy default
  virsh net-undefine default

  echo "Configure libvirt auth..."
  sed -i 's/#auth_unix_ro = "none"/auth_unix_ro = "none"/g' /etc/libvirt/libvirtd.conf
  sed -i 's/#auth_unix_rw = "none"/auth_unix_rw = "none"/g' /etc/libvirt/libvirtd.conf

  echo "Restart libvirtd"
  service libvirt-bin restart
  until ps aux | grep "[l]ibvirtd" ; do
          echo "libvirt is not running, sleeping"
          sleep 5
  done
}

# ++++++++++++++++++ FUNCTIONS END ++++++++++++++++++

set -x -v
exec 1>/var/log/postinstall-noha-stage1.log 2>&1

echo ">>>>>>>>>>>>> `date +%m%d%Y-%H%M%Z`- PRECROWBAR STARTS <<<<<<<<<<<<<<<"

# Since this script is called from a service we should wait 30 seconds to ensure that the OS has settled
sleep 30

####
# This function disables the service that called this script and installs any additional Ubuntu packages
####
prereqs

####
# config_kvm checks that the libvirtd service is running, then removes the default networking and authentication,
#	and restart the libvirtd service
####
config_kvm

echo ">>>>>>>>>>>>> `date +%m%d%Y-%H%M%Z`- PRECROWBAR ENDS <<<<<<<<<<<<<<<
