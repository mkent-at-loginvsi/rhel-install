#!/bin/bash
adm_user="ec2_user"

#!/bin/bash
# Need 2CPU
# Need 4GB RAM
# Need 25 GB Free Space

# Need admin user/group at uid 1000

#selinux disabled
# sudo sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config
# sudo sestatus

if [[ $EUID -ne 0 ]]; then
   echo "### This script must be run as root ###"
   exit 1
fi
