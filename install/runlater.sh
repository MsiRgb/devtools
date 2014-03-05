#!/bin/bash
# vi: autoindent:tabstop=2 shiftwidth=2 softtabstop=2 noexpandtab: nowrap
#
# runlater.sh
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
# Global Variables
###
SCRIPT=""
WAIT=""
DEBUG=0

###
# Functions
###


usage()
{
	cat <<-EOF
		Usage:
			${0} -d|--debug -h|--help -s|--script -w|--wait [ -- SCRIPT_ARGS ]

			  --debug: calls usage instead of operating (takes no parameter)
			  --script: the script to execute later
			  --wait: the number of minutes to wait prior to executing the script
			  -- ends standard parameters, the rest become SCRIPT_ARGS:
				    SCRIPT_ARGS is passed to the script (--script), e.g.:
            ./runlater.sh <options> -- --arg1 arg1_value --arg2 arg2_value
            (Note: any number of additional parameters can appear).

			  I have:
			    --script: ${SCRIPT}
			    --wait: ${WAIT}
			    -- SCRIPT_ARGS: ${SCRIPT_ARGS}

	EOF
}

#
# Function: generate_at_script
# Args:
#
generate_at_script()
{
	local atscript=$(mktemp --tmpdir atscript.XXXXXXXX)
	local script=$(mktemp --tmpdir script.XXXXXXXX)

	cp ${SCRIPT} "${script}"
	chmod +x "${script}"

	cat >${atscript} <<-EOS
		#!/bin/bash

		# run the desired script with all args
		${script} ${SCRIPT_ARGS}

		# delete this script -- it's just a temp proxy for the real script
		rm \$0
	EOS
	echo ${atscript}
}


###
# Main Line Code
###

# Parse args in a way not dependent on getopts (or getopt) so this
# script moves across os's relatively easily.
while test $# -gt 0; do
	case ${1} in

	# Normal option processing
		-d | --debug)
			DEBUG=1
			;;
		-h | --help)
			usage
			exit 0
			;;
		-s | --script)
			SCRIPT="${2}"
			shift
			;;
		-w | --wait)
			WAIT="${2}"
			shift
			;;

	# Special case args set (e.g., longoptions)
		--)
			shift
			break
			;;
		--*)
			echo "error unknown (long) option $1"
			exit 1
			;;
		-?)
			echo "error unknown (short) option $1"
			exit 1
			;;

		# Split out short options that arrive combined
		-*)
			split=$1
			shift
			set -- $(echo "$split" | cut -c 2- | sed 's/./-& /g') "$@"
			continue
			;;

		# Done with options
		*)
			break
			;;
	esac

	# always shift once to move the arg specifier out of the way
	shift
done

while test $# -gt 0; do
	SCRIPT_ARGS+=" ${1}"
	shift
done

if [ -z "${SCRIPT}" -o -z "${WAIT}" ]; then
	echo "One of the required options is missing.  Please check and retry."
	usage
else
	if [ ${DEBUG} -eq 0 ]; then
		atscript=$(generate_at_script)
		at -f ${atscript} "now + ${WAIT} minutes"
	else
		usage
		echo "The parameters all exist so it would have executed."
	fi
fi
