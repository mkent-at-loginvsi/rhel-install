#!/bin/bash
adm_user="ec2_user"

# Need 2CPU
# Need 4GB RAM
# Need 25 GB Free Space

if [[ $EUID -ne 0 ]]; then
   echo "### This script must be run as root ###"
   exit 1
fi

FREE=`df -k / --output=avail "$PWD" | tail -n1`   # df -k not df -h
if [[ $FREE -lt 27262976 ]]; then               # 26G = 26*1024*1024k
     # less than 26GBs free!
     echo "The installation requires 26GB Free on the root partition (/)"
     exit
fi

echo "### Set Admin Password ###"
passwd ec2_user
groupmod -n administrator ec2_user

sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd

#curl http://upload.loginvsi.com/Support/le449.clean.install.tar.gz -O /tmp/le449.clean.install.tar.gz
mkdir /tmp/le-inst
tar -zxvf /tmp/<>.tar.gz -C /tmp/le-inst
cp -R /tmp/le-appl-inst/4.4.9/loginvsi /
cp -R /tmp/le-appl-inst/4.4.9/usr /
cp -R /tmp/le-appl-inst/4.4.9/root /
cp -f /tmp/le-appl-inst/4.4.9/loginvsid.service /etc/systemd/system/
cp -f /loginvsi/bin/guard/pi_guard.service /etc/systemd/system/
systemctl enable pi_guard
systemctl enable loginvsid

mv /usr/bin/pdmenu.rhel /usr/bin/pdmenu
chmod -R +x /loginvsi/bin/*
chmod +x /usr/bin/loginvsid
chown root:root /usr/bin/loginvsid

echo "### Logging into docker... ###"
#base64 -d < /root/.play | docker login -u vsiplayaccount --password-stdin

echo "### Pulling LE4.4.9 images... ###"
source /loginvsi/.env
GATEWAY_PORT=443
cd /loginvsi/
docker-compose up -d

echo "### Stopping containers... ###"
docker-compose down

echo "### Performing factory reset - default admin credentials will be set ###"
#This will have to be a manual edit
sed -i 's/ec2_user:x:1000:1000:ec2_user:/home/ec2_user:/bin/bash/ec2_user:x:1000:1000:administrator,,,:/home/ec2_user:/usr/bin/startmenu' /etc/passwd
usermod -aG wheel ec2_user
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
