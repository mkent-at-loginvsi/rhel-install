#!/bin/bash
temp_dir="/tmp/loginenterprise"

#TODO: Expect appliance zip in rhel install dir
tar_file="appliance.tar.gz"

# Need 2CPU
# Need 4GB RAM
# Need 25 GB Free Space
# Need RHEL subscription

echo "----------------------------------------------------------------"
echo "### Checking Pre-Reqs ###"
echo "----------------------------------------------------------------"

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
     #exit
fi

CPUS=`getconf _NPROCESSORS_ONLN`
if [ $CPUS != "2" ]; then
#    echo "----------------------------------------------------------------"
#    echo "### WARNING: 2CPUS Required! ###"
#    echo "----------------------------------------------------------------"
#    exit 1
fi

RAM=`sudo dmidecode -t 17 | grep "Size.*MB" | awk '{s+=$2} END {print s / 1024}'`
#if [[ $RAM != 4]]; then
#    echo "----------------------------------------------------------------"
#    echo "### WARNING: 4GB RAM Required! ###"
#    echo "----------------------------------------------------------------"
#    exit 1
#fi

SUB=`sudo subscription-manager status | grep "Overall Status:*" | awk -F': ' '{print $2}'`
#if [[ $SUB != "Current"]]; then
#    echo "----------------------------------------------------------------"
#    echo "### WARNING: Red-Hat Subscription Required! ###"
#    echo "----------------------------------------------------------------"
#    exit 1
#fi

echo "----------------------------------------------------------------"
echo "Build Swapfile"
echo "----------------------------------------------------------------"
sudo dd if=/dev/zero of=/swapfile count=4096 bs=1MB
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defailts 0 0'|sudo tee -a /etc/fstab

echo "----------------------------------------------------------------"
echo "### Create Admin Account ###"
echo "----------------------------------------------------------------"
#TODO: Create User admin, create group admin, assign admin user to groups: admin, sudo

echo "----------------------------------------------------------------"
echo "### Allow ssh Password Authentication ###"
echo "----------------------------------------------------------------"
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd

#curl http://upload.loginvsi.com/Support/le449.clean.install.tar.gz -O /tmp/le449.clean.install.tar.gz

echo "----------------------------------------------------------------"
echo "### Unzipping arhive and installing files ###"
echo "----------------------------------------------------------------"
mkdir $temp_dir
tar -zxvf $tar_file -C $temp_dir
cp -R $temp_dir/appliance/loginvsi /
cp -R $temp_dir/appliance/usr /
cp -R $temp_dir/appliance/root /
cp -f $temp_dir/appliance/etc/systemd/system/loginvsid.service /etc/systemd/system/
cp -f $temp_dir/appliance/etc/systemd/system/pi_guard.service /etc/systemd/system/
systemctl enable pi_guard
systemctl enable loginvsid

mv $temp_dir/appliance/usr/bin/pdmenu /usr/bin/pdmenu

chmod -R +x /loginvsi/bin/*
chmod +x /usr/bin/loginvsid
chown root:root /usr/bin/loginvsid

echo "----------------------------------------------------------------"
echo "### Installing docker ###"
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

#yum-config-manager \
#    --add-repo \
#    https://download.docker.com/linux/centos/docker-ce.repo

#sed -i s/7/8/g /etc/yum.repos.d/docker-ce.repo
subscription-manager repos --enable=rhel-7-server-extras-rpms
yum install -y docker-ce docker-ce-cli containerd.io

systemctl start docker
systemctl enable docker

echo "----------------------------------------------------------------"
echo "### Installing packages ###"
echo "----------------------------------------------------------------"
curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "----------------------------------------------------------------"
echo "### Initiating docker swarm... ###"
echo "----------------------------------------------------------------"
docker swarm init

#echo "### Logging into docker... ###"
#base64 -d < /root/.play | docker login -u vsiplayaccount --password-stdin

#echo "### Pulling LE4.4.9 images... ###"
#source /loginvsi/.env
#GATEWAY_PORT=443
#cd /loginvsi/
#docker-compose up -d

#echo "### Stopping containers... ###"
#docker-compose down



echo "----------------------------------------------------------------"
echo "### Performing factory reset - default admin credentials will be set ###"
echo "----------------------------------------------------------------"
#This will have to be a manual edit
#sed -i 's/ec2_user:x:1000:1000:ec2_user:/home/ec2_user:/bin/bash/ec2_user:x:1000:1000:administrator,,,:/home/ec2_user:/usr/bin/startmenu' /etc/passwd
#usermod -aG wheel ec2_user
#/loginvsi/bin/menu/factoryreset

function update_certs () {
  #Certificates - This section will have to be run after installation and configuration are complete
  #To manage and install certificates you'll need to install the ca-certificates package and enable the dynamic CA configuration feature by issuing the command: update-ca-trust force enable.
  yum install -y ca-certificates
  update-ca-trust force enable

  #To install your own root certificate in Red Hat or CentOS, copy or move the relevant root certificate into the following directory: /etc/pki/ca-trust/source/anchors/.
  cp /certificates/CA.crt /etc/pki/ca-trust/source/anchors/

  #After you have copied the certificate to the correct directory you will need to refresh the installed certificates and hashes. You can perform this with the following command: update-ca-trust extract.
  update-ca-trust extract

  #Once this has been performed, you will need to update the certificate store by running the following command: cert-sync /etc/pki/tls/certs/ca-bundle.crt.
  update-ca-trust
}
