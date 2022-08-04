#!/bin/bash
echo "----------------------------------------------------------------"
echo "The script you are running has basename $( basename -- "$0"; ), dirname $( dirname -- "$0"; )";
echo "The present working directory is $( pwd; )";
echo "----------------------------------------------------------------"
export WORK_DIR="$PWD"
export OUTPUT_DIR=$WORK_DIR/..

echo "----------------------------------------------------------------"
echo "Install Archive will be written to $OUTPUT_DIR"
echo "----------------------------------------------------------------"

# Disk space check
FREE=`df -k / --output=avail "$PWD" | tail -n1`   # df -k not df -h
if [[ $FREE -lt 38990768 ]]; then               # 40G = 26*1024*1024k (Kibibyte)
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
mkdir $dir
echo "----------------------------------------------------------------"
echo "Relative Build Direcory: $dir"
echo "Full Path Build Directory: $BUILD_DIR"
echo "----------------------------------------------------------------"

# Download Appliance VHD zip
applianceFile="AZ-VA-LoginEnterprise-4.8.10.zip"
echo "----------------------------------------------------------------"
echo "Downloading Virtual Appliance to $BUILD_DIR/$applianceFile"
echo "----------------------------------------------------------------"

if ! [ -f $BUILD_DIR/$applianceFile ]; then
  curl -o $BUILD_DIR/$applianceFile https://loginvsidata.s3.eu-west-1.amazonaws.com/LoginEnterprise/VirtualAppliance/$applianceFile
fi

# Unzip VHD
echo "----------------------------------------------------------------"
echo "Unzipping Virtual Appliance VHD $BUILD_DIR/$applianceFile"
echo "----------------------------------------------------------------"
sudo yum install -y unzip
if ! [ -f $BUILD_DIR/"${applianceFile/zip/vhd}" ]; then
  unzip -d $BUILD_DIR $BUILD_DIR/$applianceFile
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
echo "----------------------------------------------------------------"
echo "Copying Files to archive"
echo "----------------------------------------------------------------"
build_out=$BUILD_DIR/$out_dir
mkdir $build_out

# Copy Login Enterprise Installation
cp -r /mnt/vhd/loginvsi $build_out/

# Copy Login Enterprise Service
mkdir -p $build_out/etc/systemd/system/
cp -f /mnt/vhd/etc/systemd/system/loginvsid.service $build_out/etc/systemd/system/loginvsid.service


# Copy Docker Images
#mkdir -p $build_out/var/lib/docker/
cp -r /mnt/vhd/var/lib/docker/overlay2 $build_out/

#Copy Login Enterprise Service Watcher
cp -f /mnt/vhd/etc/systemd/system/pi_guard.service $build_out/etc/systemd/system/pi_guard.service

#Copy firstrun, daemon and Menuing
mkdir -p $build_out/usr/bin
cp -f /mnt/vhd/usr/bin/loginvsid $build_out/usr/bin/loginvsid
curl -o $build_out/usr/bin/pdmenu https://github.com/mkent-at-loginvsi/rhel-install/raw/main/pdmenu/pdmenu.rhel

# Fix firstrun

#zip up appliance build
echo "----------------------------------------------------------------"
echo "Packaging Archive"
echo "----------------------------------------------------------------"
cd $BUILD_DIR
tar -czvf $out_dir.tar.gz $out_dir
mv -v $out_dir.tar.gz $OUTPUT_DIR
cd $WORK_DIR

#Unmount vhd
echo "----------------------------------------------------------------"
echo "Cleaning up"
echo "----------------------------------------------------------------"
sudo guestunmount /mnt/vhd
sh clean.sh
unset BUILD_DIR
unset WORK_DIR
unset OUTPUT_DIR

echo "----------------------------------------------------------------"
echo "Build Complete"
echo "----------------------------------------------------------------"
