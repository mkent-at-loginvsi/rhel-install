# rhel-install
RHEL 7 Install of Login Enterprise Appliance on AWS EC2 Instance.

This project contains a build script to repackage *some* Login Enterprise Components for deployment on a RHEL 7 AWS Image. This build script should be able to accommodate any version of the appliance. The output of the build is an appliance.tar.gz file.

This project also includes an install script that targets an appliance.tar.gz file, unpacks the appropriate artifacts to the correct location, and prepares an existing EC2 instance to act as a Login Enterprise appliance.

This installer also includes changes to the default firstrun script to account for differences on RHEL.

# Known Issues
## Support Statement
Support for this build and install process is best effort. While the appliance code will run on RHEL, it is not an officially (product and engineering backed) supported distribution. No support SLAs are available for Login Enterprise on RHEL.

## Admin Account
The fully supported appliance is configured with an admin account at UID 1000. This build does not. The installer creates an Admin Account for equivalency and for some parts of the install and ultimately as the preferred "user" of the platform, however this new admin account will not reside at UID 1000 and the firstrun script has been modified to account for this. This admin account is needed for the installation process. Should you choose not to use it for ongoing maintenance/management, you must leave it enabled until the install is complete.

## Console Menu
The Appliance ships with a menuing system that was designed for Debian. As such most of the menu is useless on a RHEL based distribution. For help with any of the functions that this menu provides, contact support as the menuing system will not work for RHEL at this time.

# Getting Started
Spin up a candidate AWS EC2 Instance. 2CPU/4GB RAM and a root volume of 30GB is required.
Attach a second volume of ~30-40 GB for the build process and artifacts.
SSH in to the instance. The build does not need to run as root and uses sudo where needed, however the install must be run as root.
Once inside the instance, mount the additional volume and create a file system.

# Building the artifacts
Either install/use git to clone this project to the newly mounted volume, or download the repo as a zip file and expand it to the newly added volume.
Change Directory into the rhel-install/build directory and run "sh build.sh". This process will take some time and requires internet access.
Remember the build can be run on any system and produces an artifact for the install. If you need to run the build outside of a secure environment, be sure to copy the appliance.tar.gz to the candidate system to run the install.

# Running the install
