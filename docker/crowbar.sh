#!/bin/bash
# vi: autoindent:tabstop=2 shiftwidth=2 softtabstop=2 noexpandtab: nowrap
#
# crowbar.sh -- builds a crowbar development container.
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
# Main Line Code
###
CONTAINER_NAME="crowbar"
CONTAINER_USER='tdhite'
ETCD_CLUSTER_ARGS=""
KEY_ROOT="/${CONTAINER_USER}/${CONTAINER_NAME}"
DOCKERHOST="coreos1"
#SSH="ssh ${DOCKERHOST}"
SSH=""

###
# Functions
###
run_script() {
	chmod +x "${1}"

	if [ -n "${SSH}" ]; then
		${SSH} "$(cat "${1}")"
	else
		"${1}"
	fi

	rm -f "${1}"
}

run_command() {
	if [ -n "${SSH}" ]; then
		${SSH} "$@"
	else
		$@
	fi
}

generate_script_header() {
	cat >>${script} <<-EOF
		#!/bin/bash

		###
		# Global Variables
		###
		CONTAINER_NAME="${CONTAINER_NAME}"
		CONTAINER_USER='${CONTAINER_USER}'
		ETCD_CLUSTER_ARGS="${ETCD_CLUSTER_ARGS}"
		KEY_ROOT="${KEY_ROOT}"

	EOF
	cat ${CONTAINER_NAME}-functions.sh >>${script}
	cat >>${script} <<-EOF

		###
		# Main Line Code
		###
	EOF
}

case "$1" in
	build)
		echo "wiping prior image ..."
		run_command docker rmi ${CONTAINER_USE}/${CONTAINER_NAME}

		# create the docker image
		echo "creating docker image setup scripts ..."
		script="$(mktemp --tmpdir ${CONTAINER_NAME}.XXXXXXXX)"
		generate_script_header ${script}
		cat >>${script} <<-EOF
			# generate the container and set it up
			dockerdir=\$(create_startscript)
			create_dockerfile "\${dockerdir}"
			pushd "\${dockerdir}"
			docker build -t \${CONTAINER_USER}/\${CONTAINER_NAME} .
			popd
			if ! [ -z "\${dockerdir}" ]; then
				rm -rf \${dockerdir}
			fi
		EOF
		echo "creating docker image at host ..."
		run_script "${script}"
		rm -f "${script}"
		;;
	*)
		echo "usage: ${0} build"
		;;
esac
