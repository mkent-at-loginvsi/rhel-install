#!/bin/bash
temp_dir="/install/rhel-install"
tar_file="appliance.tar.gz"

# Need 2CPU
# Need 4GB RAM
# Need 25 GB Free Space
# Need RHEL subscription
echo "----------------------------------------------------------------"
echo "### Running Installer as: $SUDO_USER ###"
echo "----------------------------------------------------------------"

echo "----------------------------------------------------------------"
echo "### Checking Pre-Reqs ###"
echo "----------------------------------------------------------------"

SELINUXSTATUS=$(getenforce)
if [ $SELINUXSTATUS != "Disabled" ]; then
     echo "----------------------------------------------------------------"
     echo "### WARNING: SELinux must be disabled! ###"
     echo "----------------------------------------------------------------"
     exit 1
fi

if [ $EUID -ne 0 ]; then
   echo "----------------------------------------------------------------"
   echo "### This script must be run as root ###"
   echo "----------------------------------------------------------------"
   exit 1
fi

FREE=`df -k / --output=avail "$PWD" | tail -n1`   # df -k not df -h
if [ $FREE -lt 27262976 ]; then               # 26G = 26*1024*1024k
     # less than 26GBs free!
     echo "----------------------------------------------------------------"
     echo "### The installation requires 26GB Free on the root partition (/) ###"
     echo "----------------------------------------------------------------"
     exit 1
fi

CPUS=`getconf _NPROCESSORS_ONLN`
if [ $CPUS -lt 2 ]; then
     echo "----------------------------------------------------------------"
     echo "### WARNING: 2CPUS Required! ###"
     echo "----------------------------------------------------------------"
     exit 1
fi

RAM=`dmidecode -t 17 | grep "Size.*MB" | awk '{s+=$2} END {print s / 1024}' | awk -F'.' '{print $1}'`
if [ $RAM -lt 4 ]; then
     echo "----------------------------------------------------------------"
     echo "### WARNING: 4GB RAM Required! ###"
     echo "----------------------------------------------------------------"
     exit 1
fi

SUB=`subscription-manager status | grep "Overall Status:*" | awk -F': ' '{print $2}'`
if [ $SUB != "Current" ]; then
     echo "----------------------------------------------------------------"
     echo "### WARNING: Red-Hat Subscription Required! ###"
     echo "----------------------------------------------------------------"
     exit 1
fi

echo "----------------------------------------------------------------"
echo "### Build Swapfile ###"
echo "----------------------------------------------------------------"
dd if=/dev/zero of=/swapfile count=4096 bs=1MB
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defailts 0 0'| tee -a /etc/fstab

admincheck=$(id -u admin)
if [ $admincheck ]; then
     echo "----------------------------------------------------------------"
     echo "### WARNING: Admin user already exists! ###"
     echo "----------------------------------------------------------------"
     usermod -aG wheel admin sudo
else
     echo "----------------------------------------------------------------"
     echo "### Create Admin Account ###"
     echo "----------------------------------------------------------------"
     adduser -m admin
     usermod -aG wheel admin sudo
     #usermod -aG sudo admin
fi

groupcheck=$(getent group loginenterprise | cut -d: -f1)
gidcheck=$(getent group 1002 | cut -d: -f1)

if [ $groupcheck ] && [ $gidcheck ]; then
     echo "----------------------------------------------------------------"
     echo "### WARNING: loginenterprise group already exists! ###"
     echo "----------------------------------------------------------------"
else
     echo "----------------------------------------------------------------"
     echo "### Create loginenterprise group ###"
     echo "----------------------------------------------------------------"
     groupadd -g 1002 loginenterprise
fi

if [ -f /etc/sysctl.conf ]; then
     echo "----------------------------------------------------------------"
     echo "### /etc/sysctl.conf already exists! ###"
     echo "----------------------------------------------------------------"
     exit 1
else
     echo "----------------------------------------------------------------"
     echo "### Create /etc/sysctl.conf ###"
     echo "----------------------------------------------------------------"
     touch /etc/sysctl.conf
fi

echo "----------------------------------------------------------------"
echo "### Add Entries to sysctl ###"
echo "----------------------------------------------------------------"
sysctlEntries=(
     "net.ipv4.conf.all.accept_redirects=0"
     "net.ipv4.conf.all.secure_redirects=0"
     "net.ipv4.conf.all.send_redirects=0"
     "net.ipv4.conf.default.accept_redirects=0"
     "net.ipv4.conf.default.secure_redirects=0"
     "net.ipv4.conf.default.send_redirects=0"
     "net.ipv6.conf.all.accept_redirects=0"
     "net.ipv6.conf.default.accept_redirects=0"
     "net.ipv4.ip_forward=1"
     )
echo "sysctl entries: ${sysctlEntries[@]}"

for str in ${sysctlEntries[@]}; do
     # sysctl -w $str=1
     grep -qF "$str" "/etc/sysctl.conf" || echo "$str" | tee -a "/etc/sysctl.conf"
done
echo "committing sysctl changes"
sysctl -p

echo "----------------------------------------------------------------"
echo "### Allow ssh Password Authentication ###"
echo "----------------------------------------------------------------"
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd

echo "----------------------------------------------------------------"
echo "### Unzipping arhive and installing files ###"
echo "----------------------------------------------------------------"
mkdir $temp_dir
tar -zxvf $tar_file -C $temp_dir
cp -R $temp_dir/appliance/loginvsi /
cp -R $temp_dir/appliance/usr /
cp -f $temp_dir/appliance/etc/systemd/system/loginvsid.service /etc/systemd/system/
cp -f $temp_dir/appliance/etc/systemd/system/pi_guard.service /etc/systemd/system/
systemctl enable pi_guard
systemctl enable loginvsid

mv $temp_dir/appliance/usr/bin/pdmenu /usr/bin/pdmenu

chmod -R +x /loginvsi/bin/*
chmod +x /usr/bin/loginvsid
chown root:root /usr/bin/loginvsid

echo "----------------------------------------------------------------"
echo "### Uninstalling Docker ###"
echo "----------------------------------------------------------------"
yum update -y

sh -c "$(curl -fsSL https://get.docker.com)"
yum module remove -y container-tools

yum remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

yum install -y yum-utils

#Install packages
rpm -ivh --nodeps $temp_dir/appliance/*.rpm

#subscription-manager repos --enable=rhel-7-server-extras-rpms
subscription-manager repos --enable=rhel-7-server-rpms \
  --enable=rhel-7-server-extras-rpms \
  --enable=rhel-7-server-optional-rpms
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm


yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

yum install -y docker-ce docker-ce-cli containerd.io

echo "----------------------------------------------------------------"
echo "### Starting Docker ###"
echo "----------------------------------------------------------------"
systemctl start docker
systemctl enable docker


echo "----------------------------------------------------------------"
echo "### Installing Docker Compose ###"
echo "----------------------------------------------------------------"
curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "----------------------------------------------------------------"
echo "### Initiating docker swarm... ###"
echo "----------------------------------------------------------------"
docker swarm init
docker load -i $temp_dir/appliance/images/*

echo "----------------------------------------------------------------"
echo "### Perform first run manually - default admin credentials will be set ###"
echo "as admin:"
echo "sh /loginvsi/bin/firstrun"
echo "after reboot, reconnect as admin and the installer will finish"
echo "----------------------------------------------------------------"
