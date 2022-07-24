#!/bin/bash
echo "----------------------------------------------------------------"
echo "The script you are running has basename $( basename -- "$0"; ), dirname $( dirname -- "$0"; )";
echo "The present working directory is $( pwd; )";
echo "----------------------------------------------------------------"
# Disk space check
FREE=`df -k / --output=avail "$PWD" | tail -n1`   # df -k not df -h
if [[ $FREE -lt 39062500 ]]; then               # 40G = 26*1024*1024k (Kibibyte)
     # less than 26GBs free!
     echo "----------------------------------------------------------------"
     echo "The installation requires 40GB Free on the root partition (/)"
     echo "----------------------------------------------------------------"
     #exit
fi

# Create Build Directory
echo "----------------------------------------------------------------"
echo "Creating Build Directory"
echo "----------------------------------------------------------------"
dir="build-$(date +%Y_%m_%d_%H_%M_%S)"
export BUILD_DIR="$PWD/$dir"
out_dir="appliance"
sudo mkdir $dir
echo "----------------------------------------------------------------"
echo "Relative Build Direcory: $dir"
echo "Full Path Build Directory: $BUILD_DIR"
echo "----------------------------------------------------------------"

# Download Appliance VHD zip
applianceFile="AZ-VA-LoginEnterprise-4.8.10.zip"
echo "----------------------------------------------------------------"
echo "Downloading Virtual Appliance to $BUILD_DIR/$applianceFile"
echo "----------------------------------------------------------------"

# Shortcut for testing...if the appliance zip is one level up, copy it
if [ -f ../$BUILD_DIR/$applianceFile ]; then
  echo "copying ../$BUILD_DIR/$applianceFile"
  sudo cp ../$BUILD_DIR/$applianceFile $BUILD_DIR
fi

if [ -f $applianceFile ]; then
  echo "copying $applianceFile"
  sudo cp $applianceFile $BUILD_DIR
fi

if ! [ -f $BUILD_DIR/$applianceFile ]; then
  sudo curl -o $BUILD_DIR/$applianceFile https://loginvsidata.s3.eu-west-1.amazonaws.com/LoginEnterprise/VirtualAppliance/$applianceFile
fi


# Unzip VHD

echo "----------------------------------------------------------------"
echo "Unzipping Virtual Appliance VHD $BUILD_DIR/$applianceFile"
echo "----------------------------------------------------------------"
sudo yum install -y unzip
if ! [ -f $BUILD_DIR/"${applianceFile/zip/vhd}" ]; then
  sudo unzip -d $BUILD_DIR $BUILD_DIR/$applianceFile
fi

# Mount VHD
echo "----------------------------------------------------------------"
echo "Mounting Virtual Hard Drive"
echo "----------------------------------------------------------------"
sudo yum install -y libguestfs-tools
sudo mkdir /mnt/vhd
sudo chmod 777 /mnt/vhd

mountpath="$BUILD_DIR"
LIBGUESTFS_BACKEND=direct
export LIBGUESTFS_BACKEND
echo $LIBGUESTFS_BACKEND
guestmount --add $mountpath/AZ-VA-LoginEnterprise-4.8.10.vhd --ro /mnt/vhd/ -m /dev/sda1

# Fail if VHD doesn't exist
echo "----------------------------------------------------------------"
echo "Checking if VHD Mounted"
echo "----------------------------------------------------------------"
if ! [ -d /mnt/vhd/loginvsi ]; then
  echo "Mount failed"
  exit 1
fi

# Copy Files and Directories to output dir
build_out=$BUILD_DIR/$out_dir
sudo mkdir $build_out

# Copy Login Enterprise Installation
sudo cp -r /mnt/vhd/loginvsi $build_out/

#Copy Login Enterprise Service
sudo mkdir -p $build_out/etc/systemd/system/
sudo cp -f /mnt/vhd/etc/systemd/system/loginvsid.service $build_out/etc/systemd/system/loginvsid.service

#Copy Login Enterprise Service Watcher
sudo cp -f /mnt/vhd/etc/systemd/system/pi_guard.service $build_out/mnt/vhd/etc/systemd/system/pi_guard.service

#Copy hidden files
sudo mkdir -p $build_out/root
#sudo cp -f /mnt/vhd/root/.play output/root/.play

#Copy firstrun, daemon and Menuing
sudo mkdir -p $build_out/usr/bin
sudo cp -f /mnt/vhd/usr/bin/loginvsid $build_out/usr/bin/loginvsid
sudo curl -O https://github.com/mkent-at-loginvsi/rhel-install/raw/main/pdmenu/pdmenu.rhel
sudo cp -f pdmenu $build_out/usr/bin/

#zip up appliance build
sudo tar -czvf $out_dir.tar.gz $build_out/*

#Unmount vhd
sudo guestunmount /mnt/vhd
unset BUILD_DIR
