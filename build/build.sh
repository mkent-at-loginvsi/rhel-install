#!/bin/#!/usr/bin/env bash
# Disk space check
FREE=`df -k / --output=avail "$PWD" | tail -n1`   # df -k not df -h
if [[ $FREE -lt 39062500 ]]; then               # 40G = 26*1024*1024k (Kibibyte)
     # less than 26GBs free!
     echo "The installation requires 40GB Free on the root partition (/)"
     #exit
fi

# Create Build Directory
dir="build-$(date +%Y_%m_%d_%H_%M_%S)"
export BUILD_DIR="$PWD/$dir"
output="appliance"
sudo mkdir $dir
cd $dir

# Download VHD
applianceFile = "AZ-VA-LoginEnterprise-4.8.10.zip"
if ! [ -f /home/$outputfile ]; then
  sudo curl -O "https://loginvsidata.s3.eu-west-1.amazonaws.com/LoginEnterprise/VirtualAppliance/$applianceFile"
fi


# Unzip VHD
sudo yum install -y unzip
if ! [ -f /home/$outputfile ]; then
  sudo unzip $applianceFile
fi
sudo unzip AZ-VA-LoginEnterprise-4.8.10.zip

# Mount VHD
sudo yum install -y libguestfs-tools
sudo mkdir /mnt/vhd
mountpath="$PWD"
export LIBGUESTFS_BACKEND=direct
sudo guestmount --add $mountpath\AZ-VA-LoginEnterprise-4.8.10.vhd --ro /mnt/vhd/ -m /dev/sda1

# Copy Files and Directories to output dir
sudo mkdir $output

# Copy Login Enterprise Installation
sudo cp -r /mnt/vhd/loginvsi $output/

#Copy Login Enterprise Service
sudo mkdir -p $output/etc/systemd/system/
sudo cp -f /mnt/vhd/etc/systemd/system/loginvsid.service $output/etc/systemd/system/loginvsid.service

#Copy Login Enterprise Service Watcher
sudo cp -f /mnt/vhd/etc/systemd/system/pi_guard.service $output/mnt/vhd/etc/systemd/system/pi_guard.service

#Copy hidden files
sudo mkdir -p $output/root
#sudo cp -f /mnt/vhd/root/.play output/root/.play

#Copy firstrun, daemon and Menuing
sudo mkdir -p $output/usr/bin
sudo cp -f /mnt/vhd/usr/bin/loginvsid $output/usr/bin/loginvsid
sudo curl -O https://github.com/mkent-at-loginvsi/rhel-install/raw/main/pdmenu/pdmenu.rhel
sudo cp -f pdmenu $output/usr/bin/

#zip up appliance build
sudo tar -cfzv $output.tar.gz $output/*

#Unmount vhd
sudo guestunmount /mnt/vhd
unset BUILD_DIR
