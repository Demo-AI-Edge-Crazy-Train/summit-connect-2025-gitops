#!/bin/bash

set -Eeuo pipefail

NAME=edge-device
QCOW2_BACKING_IMAGE="/var/lib/libvirt/images/library/rhel-9.6-$(arch)-kvm.qcow2"
DOMAIN_VCPUS="2"
DOMAIN_RAM="4096"
DOMAIN_OS_VARIANT="rhel9-unknown"
DOMAIN_DISK_SIZE="100"

# Check that the backing image exists
if [ ! -f "${QCOW2_BACKING_IMAGE}" ]; then
  echo "${QCOW2_BACKING_IMAGE} cannot be found!"
  exit 1
fi

# Check that the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# Cleanup
echo "Cleaning up any previous VM named ${NAME}..."
virsh destroy "${NAME}" || true
virsh undefine "${NAME}" --nvram || true
rm -rf "/var/lib/libvirt/images/${NAME}"

# Create the required folders
mkdir -p "/var/lib/libvirt/images/${NAME}" /var/lib/libvirt/images/library

# Generates the cloud-init ISO image
# Requires "genisoimage" to be present on the host.
# Install it with "sudo dnf install -y genisoimage"
echo "Generating cloud-init ISO image..."
cat > meta-data << EOF
instance-id: "${NAME}"
local-hostname: "${NAME}"
EOF
genisoimage -output "/var/lib/libvirt/images/${NAME}/cloud-init.iso" -volid cidata -joliet -rock user-data meta-data

# Compute the virt-install options
declare -a VIRT_INSTALL_OPTS=()
VIRT_INSTALL_OPTS+=( --name ${NAME} )
VIRT_INSTALL_OPTS+=( --autostart )
VIRT_INSTALL_OPTS+=( --noautoconsole )
VIRT_INSTALL_OPTS+=( --cpu host-passthrough )
VIRT_INSTALL_OPTS+=( --vcpus "${DOMAIN_VCPUS}" )
VIRT_INSTALL_OPTS+=( --ram "${DOMAIN_RAM}" )
VIRT_INSTALL_OPTS+=( --os-variant "${DOMAIN_OS_VARIANT}" )
VIRT_INSTALL_OPTS+=( --disk "path=/var/lib/libvirt/images/${NAME}/root.qcow2,backing_store=${QCOW2_BACKING_IMAGE},size=${DOMAIN_DISK_SIZE}" )
VIRT_INSTALL_OPTS+=( --network network=default,mac=02:00:c0:a8:7a:17,model=virtio )
VIRT_INSTALL_OPTS+=( --console pty,target.type=virtio --serial pty )
VIRT_INSTALL_OPTS+=( --disk "path=/var/lib/libvirt/images/${NAME}/cloud-init.iso,readonly=on" )
VIRT_INSTALL_OPTS+=( --sysinfo system.serial=ds=nocloud )
VIRT_INSTALL_OPTS+=( --import )

# Run virt-install and attach to serial console
echo "Starting VM installation..."
virt-install "${VIRT_INSTALL_OPTS[@]}"
virsh console "${NAME}"
