
###
# More Globals
### 
SSH_USER=crowbar

###
# Functions
### 

# creates the start.sh script
# returns: directory in which the Docker files should exist
create_startscript()
{
	local dockerdir=$(mktemp -d)
	cat >>"${dockerdir}/start.sh" <<-EOS
		#!/bin/bash
		###
		# Functions
		###

		create_users() {
			  if [ ! -d /home/${SSH_USER} ]; then
				    # create user ${SSH_USER} to ssh into
				    SSH_USERPASS=changeme
				    useradd -G sudo -d /home/${SSH_USER} -s /bin/bash -m ${SSH_USER}
				    echo ${SSH_USER}:\$SSH_USERPASS | chpasswd
				    echo ssh ${SSH_USER} password: \$SSH_USERPASS
				    if ! [ -f /mnt/crowbar ]; then
				      mkdir -p /mnt/crowbar
				      chown ${SSH_USER}:${SSH_USER} /mnt/crowbar
				    fi
				    ln -s /mnt/crowbar/.crowbar-build-cache /home/${SSH_USER}/.crowbar-build-cache
			  fi
		}

		# Adds a service to supervisord
		# Params:
		# \$1: the supervisord file
		# \$2: the service name
		# \$3: autorestart string -- true|false
		# \$*: the command line
		supervisord_service() {
			 local file="\${1}"
			 local program="\${2}"
			 local autorestart="\${3}"
			 shift 3

			 if ! [ -x "\${program}" ]; then
			  # if not found at the original spot, hope for a PATH
			  program=\$(basename \${program})
			 fi

			 echo "supervisord_service:" \${file} \${program} \${autorestart} \$*
			 cat >>\${file} <<-EOC

				[program:\${program}]
				command = \$*
				autorestart = \${autorestart}
				stdout_logfile = /var/log/supervisor/%(program_name)s.log
				stderr_logfile = /var/log/supervisor/%(program_name)s.log
			EOC
		}

		###
		# Main line code
		###
		# create any users and home directories
		create_users

		# add sshd to the services
		if ! [ -f /var/run/sshd ]; then
			 mkdir -p /var/run/sshd
			 supervisord_service /etc/supervisord.conf sshd true /usr/sbin/sshd -D
		fi
	EOS
	chmod +x "${dockerdir}/start.sh"

	echo "${dockerdir}"
}

# creates the Dockerfile
# args: $1 - the directory in which to create Dockerfile
create_dockerfile()
{
	cat >> ${1}/Dockerfile <<-EOF
		FROM tdhite/supervisor
		MAINTAINER Tom Hite <tom at nospam tomhite.us>
		RUN echo "deb http://archive.ubuntu.com/ubuntu precise universe" >>/etc/apt/sources.list
		RUN apt-get update
		RUN apt-get upgrade -y
		RUN DEBIAN_FRONTEND=noninteractive apt-get -y -q install openssh-server sudo
		RUN (echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${SSH_USER} && chmod 400 /etc/sudoers.d/${SSH_USER})
		RUN DEBIAN_FRONTEND=noninteractive apt-get -y -q install git rpm ruby rubygems1.8 curl build-essential debootstrap \
			mkisofs binutils markdown erlang debhelper python-pip \
			build-essential libopenssl-ruby1.8 libssl-dev zlib1g-dev \
			vim
		RUN gem install json net-http-digest_auth kwalify bundler rake rcov rspec --no-ri --no-rdoc
		RUN apt-get clean
		ADD ./start.sh /etc/supervisord/init.d/99crowbar
		CMD ["/bin/bash", "/start.sh"]
	EOF
}
