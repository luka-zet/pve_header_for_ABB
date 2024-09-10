#!/bin/bash

# Set up variables
PVE_HEADER=$(uname -r)  # Get the current PVE kernel version
PVE_HEADER_PACKAGE="pve-headers-${PVE_HEADER}"  # Expected Proxmox header package name
EQUIVS_PACKAGE="linux-headers-${PVE_HEADER}"  # The alias package we will create

# Ensure you are running this script as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or use sudo"
  exit 1
fi

# Update the package list
echo "Updating package list..."
apt-get update -y

# Install equivs package if it's not already installed
if ! dpkg -s equivs >/dev/null 2>&1; then
  echo "Installing equivs package..."
  apt-get install -y equivs
else
  echo "equivs is already installed."
fi

# Check if the PVE headers are installed
if ! dpkg -s $PVE_HEADER_PACKAGE >/dev/null 2>&1; then
  echo "PVE headers package $PVE_HEADER_PACKAGE is not installed. Attempting to install..."
  apt-get install -y $PVE_HEADER_PACKAGE
  if [ $? -ne 0 ]; then
    echo "Error: Unable to install $PVE_HEADER_PACKAGE. Please check your package sources."
    exit 1
  fi
else
  echo "$PVE_HEADER_PACKAGE is already installed."
fi

# Create working directory
cd /root || exit

# Create the control file template using equivs-control
echo "Creating equivs control file for $EQUIVS_PACKAGE..."
equivs-control ${EQUIVS_PACKAGE}.ctl

# Modify the control file
echo "Modifying the control file..."
sed -i "s/Package:.*/Package: ${EQUIVS_PACKAGE}/" ${EQUIVS_PACKAGE}.ctl
sed -i "s/# Depends:.*/Depends: ${PVE_HEADER_PACKAGE}/" ${EQUIVS_PACKAGE}.ctl

# Build the package using equivs
echo "Building the equivs package..."
equivs-build ${EQUIVS_PACKAGE}.ctl

# Check if the package was successfully built
DEB_PACKAGE=$(ls ${EQUIVS_PACKAGE}_*.deb)
if [ ! -f "$DEB_PACKAGE" ]; then
  echo "Error: Failed to build the equivs package."
  exit 1
fi

# Install the generated package
echo "Installing the generated package..."
dpkg -i "$DEB_PACKAGE"

# Install dkms which is required by the Synology Active Backup for Business agent
echo "Installing DKMS..."
apt-get install -y dkms

echo "Synology Active Backup agent workaround has been completed."
