#!/bin/sh
# vi: autoindent:tabstop=2 shiftwidth=2 softtabstop=2 noexpandtab: nowrap
#
# nestedkvm.sh
# Description: Reconfigures grub defaults to include nested KVM directive
# Usage: nestedkvm.sh grub_default_file
# Example: nestedkvm /etc/default/grub
#
# Copyright 2013, Momentum Software, Inc.
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

###
# Global variables
###
regex='^[^#]*GRUB_CMDLINE_LINUX[[:space:]]*=.*$'

grub_file=

###
# Functions
###
function usage() {
	echo
	echo "Usage: nestedkvm.sh grub_default_file"
	echo
}


###
# Main Line Code
###
grub_file="${1}"
if [ -z "${grub_file}" ]; then
	echo "ERROR: No grub_file provided."
	usage
	exit 1
fi

cmdline=$(grep "${regex}" ${grub_file})

# Generate the linux command line
if [ $? -ne 0 ]; then
	cmdline='kvm-intel.nested=1'
else
	eval ${cmdline}
	if [ -z "${GRUB_CMDLINE_LINUX}" ]; then
		cmdline='kvm-intel.nested=1'
	else
		cmdline=${GRUB_CMDLINE_LINUX}
		cmdline+=' kvm-intel.nested=1'
	fi
fi

# Reset grub configs so they don't get lost on upgrades
sed -i "s/${regex}/GRUB_CMDLINE_LINUX=\"${cmdline}\"/" ${grub_file}

# Rebuild the boot setup
update-grub

### end nestedkvm.sh
